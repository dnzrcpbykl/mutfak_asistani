// lib/features/recipes/recipe_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/recipe.dart';
import '../../core/models/pantry_item.dart';

class RecipeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Tüm tarifleri getirir
  Future<List<Recipe>> getRecipes() async {
    final snapshot = await _firestore.collection('recipes').get();
    return snapshot.docs.map((doc) => Recipe.fromFirestore(doc)).toList();
  }

  // --- AKILLI ALGORİTMA BURADA (GÜNCELLENDİ) ---
  // Kilerdeki malzemelere göre tarifleri süzer ve sıralar
  List<Map<String, dynamic>> matchRecipes(List<PantryItem> pantryItems, List<Recipe> allRecipes) {
    
    // 1. Kilerdeki malzeme isimlerini temizle:
    // - trim(): Baştaki ve sondaki boşlukları siler (" Domates " -> "Domates")
    // - toLowerCase(): Küçük harfe çevirir ("Domates" -> "domates")
    final myIngredients = pantryItems
        .map((item) => item.ingredientName.trim().toLowerCase())
        .toSet();

    List<Map<String, dynamic>> results = [];

    for (var recipe in allRecipes) {
      int matchCount = 0;
      List<String> missingIngredients = [];

      for (var ingredient in recipe.ingredients) {
        // Tarifteki malzemenin de boşluklarını alıp küçültüyoruz
        // Böylece veritabanında "  Yumurta" yazsa bile eşleşir.
        final cleanIngredientName = ingredient.trim().toLowerCase();

        if (myIngredients.contains(cleanIngredientName)) {
          matchCount++;
        } else {
          missingIngredients.add(ingredient); // Ekranda düzgün görünsün diye orijinalini sakla
        }
      }

      // Eşleşme oranını hesapla (Sıfıra bölünme hatası olmasın diye kontrol)
      double matchPercentage = recipe.ingredients.isEmpty 
          ? 0 
          : matchCount / recipe.ingredients.length;

      results.add({
        'recipe': recipe,
        'matchCount': matchCount,
        'missingIngredients': missingIngredients,
        'matchPercentage': matchPercentage,
      });
    }

    // 2. En çok malzemesi olan tarif en üstte çıksın (Sıralama)
    results.sort((a, b) => (b['matchPercentage'] as double).compareTo(a['matchPercentage'] as double));

    return results;
  }
}