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
    'sıvı yağ', 'ayçiçek yağı', 'zeytinyağı', 'şeker', 'toz şeker'
    'margarin', 'tereyağı', 'tereyağ', // <-- EKLENDİ
    'salça', 'domates salçası', 'biber salçası', // <-- EKLENDİ
    'un', 'beyaz un' // <-- EKLENDİ (Evde hep var sayılırsa)
  };

  // Muadil Listesi
  static const Map<String, List<String>> ingredientSubstitutes = {
    'tereyağı': ['margarin', 'sıvı yağ'],
    'süt': ['yoğurt', 'süt tozu', 'su'], 
    'yoğurt': ['süt', 'kefir', 'ayran'],
    'limon': ['limon suyu', 'sirke'],
    'domates': ['domates sosu', 'domates salçası', 'konserve domates'],
    'sarımsak': ['sarımsak tozu'],
    'yumurta': ['muz'],
    'galeta unu': ['bayat ekmek', 'un'],
    'krema': ['süt', 'yoğurt'],
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
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- GELİŞTİRİLMİŞ TEMİZLEME VE EŞLEŞTİRME ---
  List<Map<String, dynamic>> matchRecipes(List<PantryItem> pantryItems, List<Recipe> allRecipes) {
    
    final Set<String> myIngredients = {};
    
    // Kiler ürünlerini temizleyip listeye ekle
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
        // Tarifteki malzemeyi temizle: "1 bardak Baldo Pirinç" -> "pirinç"
        String recipeItemClean = _cleanName(ingredient);
        
        final isStaple = commonStaples.any((s) => recipeItemClean.contains(s));

        // EŞLEŞME KONTROLÜ
        bool isDirectMatch = myIngredients.any((myIter) {
          // 1. Tam Eşleşme: "pirinç" == "pirinç"
          if (myIter == recipeItemClean) return true;
          
          // 2. Kapsama: "tavuk göğsü" içinde "tavuk" var mı?
          if (myIter.contains(recipeItemClean) || recipeItemClean.contains(myIter)) {
             if (myIter.length < 3 || recipeItemClean.length < 3) return false;

             // Negatif Filtre (Suyu, Bulyon vb. engelle)
             const List<String> formChangingWords = ['suyu', 'bulyon', 'sos', 'toz', 'aroma', 'cips', 'kraker'];
             for (var word in formChangingWords) {
                if (myIter.contains(word) && !recipeItemClean.contains(word)) {
                   return false; 
                }
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
          // Temiz isim üzerinden muadil ara
          if (ingredientSubstitutes.containsKey(recipeItemClean)) {
            for (var alt in ingredientSubstitutes[recipeItemClean]!) {
              if (myIngredients.any((my) => my.contains(alt))) {
                substituted = true;
                substitutionTips.add("${_capitalize(recipeItemClean)} yerine **${_capitalize(alt)}** kullanabilirsin.");
                if (!isStaple) {
                  totalCoreIngredients++;
                  matchedCoreIngredients++;
                }
                break;
              }
            }
          }

          if (!substituted) {
            if (!isStaple) {
              totalCoreIngredients++;
              missingIngredients.add(ingredient); 
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

  // --- YENİ VE GÜÇLÜ TEMİZLEME FONKSİYONU ---
  String _cleanName(String raw) {
    String processed = raw.toLowerCase();

    // 1. Parantez içlerini sil (Marka, gramaj vb.)
    processed = processed.replaceAll(RegExp(r'\s*\(.*?\)'), '');

    // 2. Miktar ve Birimleri Sil (Genişletilmiş Regex)
    processed = processed.replaceFirst(
      RegExp(r'^[\d\s\.,/-]+(gr|gram|kg|kilogram|lt|litre|ml|mililitre|adet|tane|kaşık|yemek kaşığı|çay kaşığı|tatlı kaşığı|bardak|su bardağı|çay bardağı|paket|kutu|kavanoz|demet|tutam|dilim|diş|baş|fincan|kahve fincanı)\s*', caseSensitive: false), 
      ''
    );

    // 3. SIFATLARI SİL (User'ın İstediği Özellik: "Un", "Pirinç" diye arat)
    // Bu kelimeleri cümleden tamamen uçuruyoruz.
    const List<String> adjectivesToRemove = [
      'baldo', 'osmancık', 'yasmin', 'basmati', 
      'süzme', 'tam yağlı', 'yarım yağlı', 'yağsız', 'light', 'laktozsuz',
      'konserve', 'dondurulmuş', 'kuru', 'taze', 'haşlanmış', // haşlanmış eklendi
      'köy', 'gezen tavuk', 'organik', 'doğal',
      'dost', 'sütaş', 'pınar', 'torku', 'içim', 'migros', 
      'boncuk', 'burgu', 'fiyonk', 'spaghetti', 'kelebek', 'arpa', 'tel', 'yıldız',
      'tane', 'bütün', 'kıyılmış', 'rendelenmiş' // <-- BUNLARI EKLEYİN
    ];

    for (var adj in adjectivesToRemove) {
      processed = processed.replaceAll(adj, '');
    }

    // 4. Fazla boşlukları temizle
    return processed.trim();
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}