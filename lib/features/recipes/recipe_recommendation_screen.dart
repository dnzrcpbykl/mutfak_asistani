// lib/features/recipes/recipe_recommendation_screen.dart

import 'package:flutter/material.dart';
import '../../core/models/recipe.dart';
import '../../core/models/pantry_item.dart';
import '../../core/models/market_price.dart'; 
import '../pantry/pantry_service.dart';
import '../market/market_service.dart'; 
import 'recipe_service.dart';

class RecipeRecommendationScreen extends StatelessWidget {
  const RecipeRecommendationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pantryService = PantryService();
    final recipeService = RecipeService();
    final marketService = MarketService();

    return Scaffold(
      // --- DÜZELTİLEN KISIM (APP BAR) ---
      appBar: AppBar(
        title: const Text("Ne Pişirsem?"),
        centerTitle: true,                // Başlığı ortala
        automaticallyImplyLeading: false, // Geri butonunu gizle (Alt menü olduğu için)
        backgroundColor: Colors.orange,   // Turuncu tema
        foregroundColor: Colors.white,    // Beyaz yazı
      ),
      // ----------------------------------

      // GÖVDE: Kilerdeki ürünleri dinliyoruz
      body: StreamBuilder<List<PantryItem>>(
        stream: pantryService.getPantryItems(),
        builder: (context, pantrySnapshot) {
          if (!pantrySnapshot.hasData) return const Center(child: CircularProgressIndicator());

          final myPantry = pantrySnapshot.data!;

          // Hem Tarifleri Hem Fiyatları Getiriyoruz (Paralel İşlem - Adım 9.3)
          return FutureBuilder<List<dynamic>>(
            future: Future.wait([
              recipeService.getRecipes(),      // index 0
              marketService.getAllPrices(),    // index 1
            ]),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final allRecipes = snapshot.data![0] as List<Recipe>;
              final allPrices = snapshot.data![1] as List<MarketPrice>;
              
              // Algoritmayı çalıştır
              final recommendations = recipeService.matchRecipes(myPantry, allRecipes);

              if (recommendations.isEmpty) {
                return const Center(child: Text("Henüz hiç tarif bulunamadı."));
              }

              return ListView.builder(
                itemCount: recommendations.length,
                itemBuilder: (context, index) {
                  final item = recommendations[index];
                  final Recipe recipe = item['recipe'];
                  final double matchPercent = item['matchPercentage'];
                  final List<String> missing = item['missingIngredients'];

                  // Maliyet Hesabı
                  double missingCost = 0;
                  if (missing.isNotEmpty) {
                    missingCost = marketService.calculateMissingCost(missing, allPrices);
                  }

                  // Renklendirme
                  Color cardColor = matchPercent == 1.0 
                      ? Colors.green.shade100 
                      : (matchPercent > 0.5 ? Colors.orange.shade100 : Colors.red.shade50);

                  return Card(
                    color: cardColor,
                    margin: const EdgeInsets.all(8),
                    child: ExpansionTile(
                      title: Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            matchPercent == 1.0 
                              ? "Malzemelerin hepsi var! 🎉" 
                              : "${missing.length} malzeme eksik (%${(matchPercent * 100).toInt()} Eşleşme)"
                          ),
                          // Fiyat Göstergesi
                          if (missing.isNotEmpty && missingCost > 0)
                             Text(
                               "🛒 Eksikleri tamamlamak: ~${missingCost.toStringAsFixed(2)} TL",
                               style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                             ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (missing.isNotEmpty)
                                Text("Eksikler: ${missing.join(", ")}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              const Text("Yapılışı:", style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(recipe.instructions),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}