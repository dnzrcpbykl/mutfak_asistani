// lib/features/recipes/recipe_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/recipe.dart';
import '../../core/models/pantry_item.dart';

class RecipeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Demirbaş Listesi
  static const Set<String> commonStaples = {
    'su', 'sıcak su', 'ılık su', 'soğuk su', 'buz',
    'tuz', 'deniz tuzu', 'kaya tuzu', 'karabiber', 
    'toz biber', 'pul biber', 'kekik', 'nane', 'kimyon',
    'sıvı yağ', 'ayçiçek yağı', 'zeytinyağı', 'şeker', 'toz şeker',
    'margarin', 'tereyağı', 'tereyağ', 
    'salça', 'domates salçası', 'biber salçası', 
    'un', 'beyaz un'
  };

  // Muadil Listesi
  static const Map<String, List<String>> ingredientSubstitutes = {
    'tereyağı': ['margarin', 'sıvı yağ'],
    'süt': ['yoğurt', 'süt tozu', 'su', 'krema'], 
    'yoğurt': ['süt', 'kefir', 'ayran', 'süzme yoğurt'],
    'limon': ['limon suyu', 'sirke'],
    'domates': ['domates sosu', 'domates salçası', 'konserve domates'],
    'sarımsak': ['sarımsak tozu'],
    'yumurta': ['bıldırcın yumurtası'],
    'galeta unu': ['bayat ekmek', 'un'],
    'krema': ['süt', 'yoğurt'],
    'kıyma': ['dana kıyma', 'kuzu kıyma', 'köftelik kıyma'],
    'dana kıyma': ['kıyma', 'kuzu kıyma'],
    'soğan': ['kuru soğan', 'beyaz soğan', 'gümüş soğan', 'mor soğan'], // Soğan türleri eklendi
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

  // --- AKILLI EŞLEŞTİRME MOTORU (GÜNCELLENDİ) ---
  List<Map<String, dynamic>> matchRecipes(List<PantryItem> pantryItems, List<Recipe> allRecipes) {
    
    // Kilerdeki ürünleri temizle ve listeye al
    final Set<String> myIngredients = {};
    for (var item in pantryItems) {
      myIngredients.add(_cleanName(item.ingredientName));
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
          // 1. Tam Eşleşme
          if (myIter == recipeItemClean) return true;
          
          // 2. Kapsama
          if (myIter.contains(recipeItemClean) || recipeItemClean.contains(myIter)) {
             if (myIter.length < 3 || recipeItemClean.length < 3) return myIter == recipeItemClean;

             // Negatif Filtre
             const List<String> formChangingWords = ['suyu', 'bulyon', 'sos', 'toz', 'aroma', 'cips', 'kraker', 'meyveli'];
             for (var word in formChangingWords) {
                if (myIter.contains(word) && !recipeItemClean.contains(word)) return false; 
                if (!myIter.contains(word) && recipeItemClean.contains(word)) return false;
             }
             return true;
          }

          // 3. [YENİ] Kelime Bazlı Çapraz Kontrol ("Gümüş Soğan" == "Soğan Gümüş")
          // Tarifteki kelimeleri ayır
          List<String> recipeWords = recipeItemClean.split(' ').where((w) => w.length > 2).toList();
          if (recipeWords.isNotEmpty) {
            // Kilerdeki ürünün ismi, tarifteki TÜM kelimeleri içeriyor mu?
            bool allWordsPresent = recipeWords.every((word) => myIter.contains(word));
            if (allWordsPresent) return true;
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
          // Anahtar kelime ile muadil ara
          // Önce temiz isme bak, sonra kelime kelime bak (Örn: "kuru soğan" için "soğan" muadillerine bak)
          
          List<String> searchKeys = [recipeItemClean];
          searchKeys.addAll(recipeItemClean.split(' ')); 

          for (var key in searchKeys) {
             if (ingredientSubstitutes.containsKey(key)) {
                for (var alt in ingredientSubstitutes[key]!) {
                  if (myIngredients.any((my) => my.contains(alt))) {
                    substituted = true;
                    substitutionTips.add("${_capitalize(recipeItemClean)} yerine elindeki **${_capitalize(alt)}** kullanılabilir.");
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

  // --- TEMİZLEME MOTORU ---
  String _cleanName(String raw) {
    String processed = raw.toLowerCase();

    // 1. Parantez içlerini sil
    processed = processed.replaceAll(RegExp(r'\(.*?\)', caseSensitive: false), '');

    // 2. Yüzdeleri sil
    processed = processed.replaceAll(RegExp(r'%\d+'), '');

    // 3. Marka isimlerini sil
    const List<String> brandsToRemove = [
      'uzman kasap', 'pınar', 'sütaş', 'torku', 'içim', 'migros', 'carrefour', 'banvit', 'şenpiliç', 'dost', 'içimino'
    ];
    for (var brand in brandsToRemove) {
      processed = processed.replaceAll(brand, '');
    }

    // 4. [YENİ] Kesirli Sayıları Sil (1/2, 3/4 vb.)
    processed = processed.replaceAll(RegExp(r'\d+/\d+'), '');

    // 5. Miktar ve Birimleri Sil
    processed = processed.replaceFirst(
      RegExp(r'^[\d\s\.,/-]+(gr|gram|kg|kilogram|lt|litre|ml|mililitre|adet|tane|kaşık|yemek kaşığı|çay kaşığı|tatlı kaşığı|bardak|su bardağı|çay bardağı|paket|kutu|kavanoz|demet|tutam|dilim|diş|baş|fincan|kahve fincanı)\s*', caseSensitive: false), 
      ''
    );

    // 6. Sıfatları Sil
    const List<String> adjectivesToRemove = [
      'baldo', 'osmancık', 'yasmin', 'basmati', 
      'süzme', 'tam yağlı', 'yarım yağlı', 'yağsız', 'light', 'laktozsuz',
      'konserve', 'dondurulmuş', 'kuru', 'taze', 'haşlanmış', 
      'köy', 'gezen tavuk', 'organik', 'doğal',
      'boncuk', 'burgu', 'fiyonk', 'spaghetti', 'kelebek', 'arpa', 'tel', 'yıldız',
      'tane', 'bütün', 'kıyılmış', 'rendelenmiş', 'dilimli', 'yaprak',
      'aromalı', 'orman meyveli', 'kakaolu', 'çilekli', 'muzlu' // Meyveli sütleri temizlemek/ayırt etmek için
    ];
    for (var adj in adjectivesToRemove) {
      processed = processed.replaceAll(adj, '');
    }

    return processed.trim();
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}