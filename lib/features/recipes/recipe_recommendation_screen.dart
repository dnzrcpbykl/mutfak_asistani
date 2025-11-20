import 'package:flutter/material.dart';
import '../../core/models/recipe.dart';
import '../../core/models/pantry_item.dart';
import '../../core/models/market_price.dart'; 
import '../pantry/pantry_service.dart';
import '../market/market_service.dart'; 
import 'recipe_service.dart';
import 'recipe_importer_service.dart'; 

// 1. DEĞİŞİKLİK: Burası artık StatefulWidget
class RecipeRecommendationScreen extends StatefulWidget {
  const RecipeRecommendationScreen({super.key});

  @override
  State<RecipeRecommendationScreen> createState() => _RecipeRecommendationScreenState();
}

class _RecipeRecommendationScreenState extends State<RecipeRecommendationScreen> {
  // Servisleri buraya tanımlıyoruz ki her yenilemede tekrar oluşmasınlar
  final PantryService _pantryService = PantryService();
  final RecipeService _recipeService = RecipeService();
  final MarketService _marketService = MarketService();
  final RecipeImporterService _importer = RecipeImporterService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ne Pişirsem?"),
        centerTitle: true,
        automaticallyImplyLeading: false, 
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      
      // --- YAPAY ZEKA ŞEF BUTONU ---
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.purple, 
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome),
        label: const Text("Şefe Sor (AI)"),
        onPressed: () async {
          // 1. Kilerdeki malzemeleri çek
          final pantrySnapshot = await _pantryService.pantryRef.get();
          final myIngredients = pantrySnapshot.docs.map((doc) => doc.data().ingredientName).toList();

          if (myIngredients.isEmpty) {
             if (!context.mounted) return;
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Önce kilerine malzeme eklemelisin!")),
             );
             return;
          }

          // 2. Yükleniyor penceresi aç
          if (!context.mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Dialog(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.purple),
                    SizedBox(height: 20),
                    Text("Şef dolabına bakıyor..."),
                    Text("Size özel tarifler hazırlanıyor."),
                  ],
                ),
              ),
            ),
          );

          try {
            // 3. AI Servisini Çağır
            await _importer.generateRecipesFromPantry(myIngredients);

            if (!context.mounted) return;
            Navigator.pop(context); // Yüklemeyi kapat

            ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Şefin önerileri hazır!"), backgroundColor: Colors.green),
            );
            
            // 2. DEĞİŞİKLİK: EKRANI YENİLEME KOMUTU
            // Veritabanı değişti, ekranı yeniden çiz ki yeni verileri çeksin.
            setState(() {}); 

          } catch (e) {
            if (!mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
            );
          }
        },
      ),

      // --- GÖVDE ---
      body: StreamBuilder<List<PantryItem>>(
        stream: _pantryService.getPantryItems(),
        builder: (context, pantrySnapshot) {
          if (!pantrySnapshot.hasData) return const Center(child: CircularProgressIndicator());

          final myPantry = pantrySnapshot.data!;

          return FutureBuilder<List<dynamic>>(
            // setState çağrılınca burası tekrar çalışacak ve yeni tarifleri çekecek
            future: Future.wait([
              _recipeService.getRecipes(),      
              _marketService.getAllPrices(),    
            ]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                 return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData) return const Center(child: Text("Veri yüklenemedi."));

              final allRecipes = snapshot.data![0] as List<Recipe>;
              final allPrices = snapshot.data![1] as List<MarketPrice>;
              
              final recommendations = _recipeService.matchRecipes(myPantry, allRecipes);

              if (recommendations.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      "Henüz uygun tarif bulunamadı.\nSağ alttaki butona basarak Şef'ten yardım iste!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                );
              }

              return ListView.builder(
                itemCount: recommendations.length,
                padding: const EdgeInsets.only(bottom: 80),
                itemBuilder: (context, index) {
                  final item = recommendations[index];
                  final Recipe recipe = item['recipe'];
                  final double matchPercent = item['matchPercentage'];
                  final List<String> missing = item['missingIngredients'];

                  double missingCost = 0;
                  if (missing.isNotEmpty) {
                    missingCost = _marketService.calculateMissingCost(missing, allPrices);
                  }

                  Color cardColor = matchPercent == 1.0 
                      ? Colors.green.shade50 
                      : (matchPercent > 0.5 ? Colors.orange.shade50 : Colors.red.shade50);

                  return Card(
                    color: cardColor,
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Text(
                          "%${(matchPercent * 100).toInt()}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: matchPercent > 0.5 ? Colors.green : Colors.red,
                            fontSize: 12
                          ),
                        ),
                      ),
                      title: Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          matchPercent == 1.0 
                              ? const Text("Malzemelerin hepsi var! 🎉", style: TextStyle(color: Colors.green))
                              : Text("${missing.length} malzeme eksik", style: TextStyle(color: Colors.red.shade700)),
                          
                          if (missing.isNotEmpty && missingCost > 0)
                             Padding(
                               padding: const EdgeInsets.only(top: 4.0),
                               child: Row(
                                 children: [
                                   const Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.blue),
                                   const SizedBox(width: 4),
                                   Text(
                                     "Tamamlama: ~${missingCost.toStringAsFixed(2)} TL",
                                     style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                                   ),
                                 ],
                               ),
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
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.shade100)
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Eksik Malzemeler:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                      Text(missing.join(", "), style: const TextStyle(color: Colors.black87)),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 10),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Chip(label: Text("${recipe.prepTime} Dk"), avatar: const Icon(Icons.timer, size: 18)),
                                  Chip(label: Text(recipe.difficulty), avatar: const Icon(Icons.bar_chart, size: 18)),
                                ],
                              ),
                              const SizedBox(height: 10),

                              const Text("Yapılışı:", style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(recipe.instructions),
                              
                              const SizedBox(height: 20),
                              
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text("Afiyet Olsun!"),
                                        content: const Text("Malzemeler stoktan düşülsün mü?"),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
                                          FilledButton(
                                            onPressed: () async {
                                              await _pantryService.consumeIngredients(recipe.ingredients);
                                              if (!context.mounted) return;
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text("Stoklar güncellendi!")),
                                              );
                                              // Stoklar değiştiği için ekranı yenilemeye gerek yok (StreamBuilder halleder)
                                            },
                                            child: const Text("Evet, Düş"),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.check),
                                  label: const Text("Bunu Pişirdim"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
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