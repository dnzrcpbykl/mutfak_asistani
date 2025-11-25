// lib/features/recipes/recipe_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/recipe.dart';
import '../../core/models/pantry_item.dart';

class RecipeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- YENİ: MUADİL (ALTERNATİF) TABLOSU ---
  // Sol taraf: Tarifteki İstek -> Sağ taraf: Kilerde olabilecek alternatifler
  static const Map<String, List<String>> ingredientSubstitutes = {
    // Yağlar
    'tereyağı': ['margarin', 'sıvı yağ', 'zeytinyağı', 'ayçiçek yağı'],
    'margarin': ['tereyağı', 'sıvı yağ', 'zeytinyağı'],
    'zeytinyağı': ['ayçiçek yağı', 'mısır özü yağı', 'sıvı yağ'],
    'ayçiçek yağı': ['mısır özü yağı', 'zeytinyağı', 'kanola yağı'],
    
    // Süt Ürünleri
    'süt': ['yoğurt', 'krema', 'süt tozu', 'laktozsuz süt'],
    'yoğurt': ['süzme yoğurt', 'süt', 'kefir'],
    'krema': ['süt', 'kaymak', 'labne'],
    'kaşar peyniri': ['dil peyniri', 'kolot peyniri', 'mozarella', 'beyaz peynir'],
    'beyaz peynir': ['lor peyniri', 'ezine peyniri'],
    
    // Tatlandırıcılar
    'toz şeker': ['küp şeker', 'pudra şekeri', 'esmer şeker', 'bal', 'pekmez'],
    'pudra şekeri': ['toz şeker'],
    'bal': ['pekmez', 'akçaağaç şurubu', 'toz şeker'],
    
    // Asitler
    'limon': ['limon suyu', 'sirke', 'limon tuzu'],
    'limon suyu': ['limon', 'sirke'],
    'sirke': ['limon suyu', 'elma sirkesi', 'üzüm sirkesi'],
    
    // Sebzeler & Bakliyat
    'domates': ['domates sosu', 'domates püresi', 'domates salçası', 'çeri domates'],
    'domates salçası': ['biber salçası', 'domates püresi', 'domates'],
    'kuru soğan': ['taze soğan', 'mor soğan', 'arpacık soğan'],
    'sarımsak': ['sarımsak tozu', 'sarımsak püresi'],
    'maydanoz': ['dereotu', 'nane'], // Bazen birbirinin yerine geçer
    
    // Unlu Mamuller
    'un': ['tam buğday unu', 'galeta unu', 'mısır nişastası'], // Bağlayıcı olarak
    'nişasta': ['un', 'mısır nişastası', 'buğday nişastası'],
    'kabartma tozu': ['karbonat'],
    'karbonat': ['kabartma tozu'],
    'ekmek': ['tost ekmeği', 'bazlama', 'lavaş', 'galeta'],
  };

  Future<List<Recipe>> getRecipes() async {
    final user = _auth.currentUser;
    if (user == null) return []; // Kullanıcı yoksa boş liste dön

    // Artık 'recipes' yerine 'users/{uid}/suggestions' yoluna bakıyoruz
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

  List<Map<String, dynamic>> matchRecipes(List<PantryItem> pantryItems, List<Recipe> allRecipes) {
    
    // 1. Kilerdeki malzemeleri temizle
    final myIngredients = pantryItems
        .map((item) => item.ingredientName.trim().toLowerCase())
        .toSet();

    // 2. Temel Malzemeler (Evde hep var sayılanlar)
    final Set<String> commonStaples = {
      'su', 'sıcak su', 'ılık su', 'soğuk su',
      'tuz', 'deniz tuzu', 'kaya tuzu',
      'karabiber', 'toz biber', 'pul biber', 'kekik', 'nane', 'kimyon',
      'sıvı yağ', 'ayçiçek yağı' // Yağ yoksa bile temel sayabiliriz ama muadilde de kontrol ediyoruz
    };

    List<Map<String, dynamic>> results = [];

    for (var recipe in allRecipes) {
      int matchCount = 0;
      List<String> missingIngredients = [];
      // Hangi malzemenin yerine ne kullanacağını tutan liste
      List<String> substitutionTips = []; 

      for (var ingredient in recipe.ingredients) {
        final cleanIngredientName = ingredient.trim().toLowerCase();

        // A) Direkt Eşleşme Kontrolü
        bool isDirectMatch = myIngredients.any((myIter) => myIter.contains(cleanIngredientName) || cleanIngredientName.contains(myIter));
        
        // B) Temel Malzeme Kontrolü
        bool isCommonStaple = commonStaples.any((staple) => cleanIngredientName.contains(staple));

        if (isDirectMatch || isCommonStaple) {
          matchCount++;
        } else {
          // C) MUADİL KONTROLÜ (YENİ ÖZELLİK)
          bool substituted = false;
          
          // Bu malzeme için tanımlı bir alternatif listesi var mı?
          if (ingredientSubstitutes.containsKey(cleanIngredientName)) {
            final alternatives = ingredientSubstitutes[cleanIngredientName]!;
            
            // Alternatiflerden herhangi biri kilerde var mı?
            for (var alt in alternatives) {
              if (myIngredients.any((myItems) => myItems.contains(alt))) {
                // BINGO! Alternatif bulundu.
                matchCount++; // Puanı artır (Var sayıyoruz)
                substituted = true;
                
                // Kullanıcıya ipucu hazırla: "Tereyağı yok ama Margarin kullanabilirsin"
                // Orijinal isim (Büyük harfle başlat) yerine Alternatif
                substitutionTips.add("${_capitalize(cleanIngredientName)} yerine elindeki **${_capitalize(alt)}** kullanılabilir.");
                break; // Bir tane bulmak yeterli
              }
            }
          }

          if (!substituted) {
            missingIngredients.add(ingredient); // Gerçekten eksik
          }
        }
      }

      double matchPercentage = recipe.ingredients.isEmpty 
          ? 0 
          : matchCount / recipe.ingredients.length;

      results.add({
        'recipe': recipe,
        'matchCount': matchCount,
        'missingIngredients': missingIngredients,
        'matchPercentage': matchPercentage,
        'substitutionTips': substitutionTips, // Yeni veriyi gönderiyoruz
      });
    }

    results.sort((a, b) => (b['matchPercentage'] as double).compareTo(a['matchPercentage'] as double));

    return results;
  }

  // Baş harfi büyütmek için yardımcı
  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}