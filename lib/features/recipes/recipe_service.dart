import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/recipe.dart';
import '../../core/models/pantry_item.dart';

class RecipeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Demirbaş (Evde hep var sayılan veya puanı etkilememesi gerekenler)
  static const Set<String> commonStaples = {
    'su', 'sıcak su', 'ılık su', 'soğuk su', 'buz',
    'tuz', 'deniz tuzu', 'kaya tuzu', 'karabiber', 
    'toz biber', 'pul biber', 'kekik', 'nane', 'kimyon',
    'sıvı yağ', 'ayçiçek yağı', 'zeytinyağı'
  };

  // Alternatif Tablosu (Muadiller)
  static const Map<String, List<String>> ingredientSubstitutes = {
    'tereyağı': ['margarin', 'sıvı yağ'],
    'süt': ['yoğurt', 'süt tozu', 'su'], // Kek/börek için su bazen kurtarır
    'yoğurt': ['süt', 'kefir'],
    'limon': ['limon suyu', 'sirke'],
    'toz şeker': ['küp şeker', 'pudra şekeri', 'bal'],
    'domates': ['domates sosu', 'domates salçası'],
    'sarımsak': ['sarımsak tozu'],
    'yumurta': ['muz', 'yoğurt'], // Vegan/alerji alternatifleri (basit)
    'galeta unu': ['bayat ekmek', 'un'],
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

  // --- KRİTİK DÜZELTME: AKILLI EŞLEŞTİRME ALGORİTMASI ---
  List<Map<String, dynamic>> matchRecipes(List<PantryItem> pantryItems, List<Recipe> allRecipes) {
    
    // 1. Kilerdeki malzemeleri normalize et
    // "Garnitür Konserve (550G)" -> "garnitür konserve" ve "garnitür"
    // Hem tam adını hem de parantez öncesi kök adını listeye ekleyelim.
    final Set<String> myIngredients = {};
    
    for (var item in pantryItems) {
      String rawName = item.ingredientName.toLowerCase();
      myIngredients.add(rawName); // Tam hali
      
      // Parantezi silip kök halini de ekle: "Garnitür Konserve (550G)" -> "garnitür konserve"
      String rootName = rawName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
      myIngredients.add(rootName);
      
      // Sadece ilk kelimeyi de ekle (Riskli ama bazen işe yarar: "Domates Salçası" -> "Domates" gibi)
      // Ama garnitür için "Garnitür" yeterli olur.
    }

    List<Map<String, dynamic>> results = [];

    for (var recipe in allRecipes) {
      List<String> missingIngredients = [];
      List<String> substitutionTips = [];
      
      int totalCoreIngredients = 0; 
      int matchedCoreIngredients = 0; 

      for (var ingredient in recipe.ingredients) {
        // Tarifteki malzeme: "300 gr Garnitür Konserve (hafifçe yıkanmış...)"
        // Temizle: "garnitür konserve"
        String recipeItemClean = ingredient.toLowerCase();
        
        // 1. Miktarları sil (300 gr)
        recipeItemClean = recipeItemClean.replaceFirst(RegExp(r'^[\d\s\.,/-]+(gr|kg|lt|ml|adet|tane|kaşık|bardak)\s*'), '');
        // 2. Parantez içini sil (hafifçe yıkanmış...)
        recipeItemClean = recipeItemClean.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
        // 3. Kalan: "garnitür konserve"

        final isStaple = commonStaples.any((s) => recipeItemClean.contains(s));

        // EŞLEŞME KONTROLÜ (İki Yönlü)
        // Kilerdeki "garnitür konserve", Tarifteki "garnitür konserve" içinde geçiyor mu?
        bool isDirectMatch = myIngredients.any((myIter) {
          // "garnitür" == "garnitür"
          if (myIter == recipeItemClean) return true;
          // "domates salçası" tarifi, kilerdeki "domates" içinde var mı? (Tersi mantıksız olabilir)
          // Kilerdeki "garnitür", tarifteki "garnitür konserve" içinde geçiyor mu? -> EVET
          if (recipeItemClean.contains(myIter) && myIter.length > 3) return true; 
          // Tarifteki "garnitür", kilerdeki "garnitür konserve" içinde geçiyor mu? -> EVET
          if (myIter.contains(recipeItemClean) && recipeItemClean.length > 3) return true;
          
          return false;
        });
        
        if (isDirectMatch) {
          if (!isStaple) {
            totalCoreIngredients++;
            matchedCoreIngredients++;
          }
        } else {
          // Muadil Kontrolü... (Eski kodun aynısı)
          bool substituted = false;
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
              missingIngredients.add(ingredient); // Orijinal (detaylı) ismi ekle ki kullanıcı ne olduğunu bilsin
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

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}