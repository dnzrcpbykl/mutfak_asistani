// lib/features/recipes/recipe_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/recipe.dart';
import '../../core/models/pantry_item.dart';

class RecipeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Demirbaş Listesi (Evde kesin vardır varsayılanlar)
  static const Set<String> commonStaples = {
    'su', 'sıcak su', 'ılık su', 'soğuk su', 'buz',
    'tuz', 'deniz tuzu', 'kaya tuzu', 'karabiber', 
    'toz biber', 'pul biber', 'kekik', 'nane', 'kimyon',
    'sıvı yağ', 'ayçiçek yağı', 'zeytinyağı', 'şeker', 'toz şeker',
    'margarin', 'tereyağı', 'tereyağ', 
    'salça', 'domates salçası', 'biber salçası', 
    'un', 'beyaz un'
  };

  // Muadil Listesi (Eşleştirme şansını artırır)
  static const Map<String, List<String>> ingredientSubstitutes = {
    'tereyağı': ['margarin', 'sıvı yağ'],
    'süt': ['yoğurt', 'süt tozu', 'su', 'krema', 'laktozsuz süt'], 
    'yoğurt': ['süt', 'kefir', 'ayran', 'süzme yoğurt'],
    'limon': ['limon suyu', 'sirke'],
    'domates': ['domates sosu', 'domates salçası', 'konserve domates'],
    'sarımsak': ['sarımsak tozu'],
    'yumurta': ['bıldırcın yumurtası'],
    'galeta unu': ['bayat ekmek', 'un'],
    'krema': ['süt', 'yoğurt'],
    'kıyma': ['dana kıyma', 'kuzu kıyma', 'köftelik kıyma'],
    'dana kıyma': ['kıyma', 'kuzu kıyma'],
    'soğan': ['kuru soğan', 'beyaz soğan', 'gümüş soğan', 'mor soğan', 'arpacık soğan'],
    'patates': ['taze patates', 'kızartmalık patates'],
    'peynir': ['kaşar peyniri', 'beyaz peynir', 'tulum peyniri', 'lor peyniri'],
  };

  Future<List<Recipe>> getRecipes() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('suggestions')
        .get();
    return snapshot.docs.map((doc) => Recipe.fromFirestore(doc)).toList();
  }

  Future<void> saveRecipeToFavorites(Recipe recipe) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).collection('saved_recipes').add({
      'name': recipe.name,
      'description': recipe.description,
      'ingredients': recipe.ingredients,
      'instructions': recipe.instructions,
      'prepTime': recipe.prepTime,
      'difficulty': recipe.difficulty,
      'category': recipe.category,
      'calories': recipe.calories,
      'protein': recipe.protein,
      'carbs': recipe.carbs,
      'fat': recipe.fat,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- GÜÇLENDİRİLMİŞ EŞLEŞTİRME MOTORU ---
  List<Map<String, dynamic>> matchRecipes(List<PantryItem> pantryItems, List<Recipe> allRecipes) {
    
    // Kilerdeki ürünleri "Normalize" ederek listeye al
    final Set<String> myIngredients = {};
    for (var item in pantryItems) {
      // DÜZELTME: Sadece stoğu olan (0'dan büyük) ürünleri dikkate al!
      if (item.quantity <= 0.01) continue; 

      // Hem normal halini hem de temizlenmiş halini havuza at
      myIngredients.add(_cleanName(item.ingredientName));
      // Parçalayıp kelime kelime de ekle
      myIngredients.addAll(_cleanName(item.ingredientName).split(' '));
    }

    List<Map<String, dynamic>> results = [];

    for (var recipe in allRecipes) {
      List<String> missingIngredients = [];
      List<String> substitutionTips = [];
      
      int totalCoreIngredients = 0; 
      int matchedCoreIngredients = 0;

      for (var ingredient in recipe.ingredients) {
        String recipeItemClean = _cleanName(ingredient);
        final isStaple = commonStaples.any((s) => recipeItemClean.contains(s));

        // --- EŞLEŞME KONTROLÜ ---
        bool isDirectMatch = myIngredients.any((myIter) {
          // 1. Tam Eşleşme (Normalize edilmiş halleriyle)
          if (myIter == recipeItemClean) return true;
          
          // 2. Kapsama Kontrolü
          // Örn: Kilerde "sogan" var, Tarifte "taze sogan" var.
          if (myIter.contains(recipeItemClean) || recipeItemClean.contains(myIter)) {
             // Çok kısa kelimelerde (su, un, tuz) hatalı eşleşmeyi önle
             if (myIter.length < 3 || recipeItemClean.length < 3) return myIter == recipeItemClean;

             // Negatif Filtre: "Süt" ararken "Hindistan Cevizi Sütü" bulmasın
             const List<String> formChangingWords = ['suyu', 'bulyon', 'sos', 'toz', 'aroma', 'cips', 'kraker', 'meyveli', 'reçeli'];
             for (var word in formChangingWords) {
                // Eğer kilerdeki üründe "suyu" var ama tarifte yoksa, eşleşme sayma (Limon Suyu != Limon)
                if (myIter.contains(word) && !recipeItemClean.contains(word)) return false; 
                if (!myIter.contains(word) && recipeItemClean.contains(word)) return false;
             }
             return true;
          }
          return false;
        });

        if (isDirectMatch) {
          if (!isStaple) {
            totalCoreIngredients++;
            matchedCoreIngredients++;
          }
        } else {
          // Muadil Kontrolü
          bool substituted = false;
          
          List<String> searchKeys = [recipeItemClean];
          searchKeys.addAll(recipeItemClean.split(' ')); 

          for (var key in searchKeys) {
             if (ingredientSubstitutes.containsKey(key)) {
                for (var alt in ingredientSubstitutes[key]!) {
                  String cleanAlt = _normalize(alt); // Muadili de normalize et
                  if (myIngredients.any((my) => my.contains(cleanAlt))) {
                    substituted = true;
                    substitutionTips.add("${_capitalize(ingredient)} yerine elindeki **${_capitalize(alt)}** kullanılabilir.");
                    if (!isStaple) {
                      totalCoreIngredients++;
                      matchedCoreIngredients++;
                    }
                    break;
                  }
                }
             }
             if (substituted) break;
          }

          if (!substituted) {
            if (!isStaple) {
              missingIngredients.add(ingredient);
              totalCoreIngredients++;
            }
          }
        }
      }

      double matchPercentage = 0.0;
      if (totalCoreIngredients == 0) {
        matchPercentage = 1.0;
      } else {
        matchPercentage = matchedCoreIngredients / totalCoreIngredients;
      }

      results.add({
        'recipe': recipe,
        'missingIngredients': missingIngredients,
        'matchPercentage': matchPercentage,
        'substitutionTips': substitutionTips,
      });
    }

    results.sort((a, b) => (b['matchPercentage'] as double).compareTo(a['matchPercentage'] as double));

    return results;
  }

  // --- TEMİZLEME MOTORU (GÜNCELLENDİ) ---
  String _cleanName(String raw) {
    // 1. Önce Türkçe karakterleri düzelt (EN ÖNEMLİ KISIM)
    String processed = _normalize(raw);

    // 2. Parantez içlerini sil
    processed = processed.replaceAll(RegExp(r'\(.*?\)', caseSensitive: false), '');
    
    // 3. Yüzdeleri sil
    processed = processed.replaceAll(RegExp(r'%\d+'), '');
    
    // 4. Marka isimlerini sil
    const List<String> brandsToRemove = [
      'uzman kasap', 'pinar', 'sutas', 'torku', 'icim', 'migros', 'carrefour', 'banvit', 'senpilic', 'dost', 'icimino', 'tat'
    ];
    for (var brand in brandsToRemove) {
      processed = processed.replaceAll(brand, '');
    }

    // 5. Miktar ve Birimleri Sil (Regex Güçlendirildi)
    // "1 adet", "1.5 kg", "2 yemek kaşığı" gibi ifadeleri temizler
    processed = processed.replaceAll(RegExp(r'\d+[\.,]?\d*\s*(adet|tane|kg|kilogram|gr|gram|lt|litre|ml|mililitre|bardak|kasik|paket|kutu|demet|dilim)\s*', caseSensitive: false), '');
    
    // Sadece sayı kaldıysa onu da sil (Örn: "2 soğan" -> "2" kaldıysa sil)
    processed = processed.replaceAll(RegExp(r'^\d+\s+'), '');

    // 6. Sıfatları Sil (Normalize edilmiş halleriyle)
    const List<String> adjectivesToRemove = [
      'buyuk boy', 'orta boy', 'kucuk boy', 'buyuk', 'orta', 'kucuk',
      'baldo', 'osmancik', 'yasmin', 'basmati', 
      'suzme', 'tam yagli', 'yarim yagli', 'yagsiz', 'light', 'laktozsuz',
      'konserve', 'dondurulmus', 'kuru', 'taze', 'haslanmis', 'dogranmis', 'dilimlenmis', 'rendelenmis',
      'koy', 'gezen tavuk', 'organik', 'dogal', 'yerli', 'ithal',
      'boncuk', 'burgu', 'fiyonk', 'spaghetti', 'kelebek', 'arpa', 'tel', 'yildiz',
      'tane', 'butun', 'kiyilmis', 'dilimli', 'yaprak',
      'aromali', 'orman meyveli', 'kakaolu', 'cilekli', 'muzlu'
    ];
    for (var adj in adjectivesToRemove) {
      processed = processed.replaceAll(adj, '');
    }

    // Fazla boşlukları temizle
    return processed.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  // --- TÜRKÇE KARAKTER DÜZELTİCİ (YENİ) ---
  String _normalize(String text) {
    return text.toLowerCase()
      .replaceAll('İ', 'i').replaceAll('I', 'i').replaceAll('ı', 'i')
      .replaceAll('ğ', 'g').replaceAll('Ğ', 'g')
      .replaceAll('ü', 'u').replaceAll('Ü', 'u')
      .replaceAll('ş', 's').replaceAll('Ş', 's')
      .replaceAll('ö', 'o').replaceAll('Ö', 'o')
      .replaceAll('ç', 'c').replaceAll('Ç', 'c')
      // Noktalama işaretlerini de temizle
      .replaceAll(RegExp(r'[^\w\s]'), ''); 
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}