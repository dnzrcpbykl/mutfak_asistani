import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Provider paketi eklendi

// Modeller
import '../../core/models/recipe.dart';
import '../../core/models/market_price.dart';

// Servisler (Aksiyonlar için)
import '../pantry/pantry_service.dart';
import '../market/market_service.dart';
import '../shopping_list/shopping_service.dart';
import 'recipe_service.dart';
import 'recipe_importer_service.dart';

// Provider (Veri Yönetimi için)
import 'recipe_provider.dart';

// Ekranlar
import 'cooking_mode_screen.dart';
import '../../core/widgets/recipe_loading_skeleton.dart';
import 'dart:io';

class RecipeRecommendationScreen extends StatefulWidget {
  const RecipeRecommendationScreen({super.key});

  @override
  State<RecipeRecommendationScreen> createState() => _RecipeRecommendationScreenState();
}

class _RecipeRecommendationScreenState extends State<RecipeRecommendationScreen> {
  // Veri çekme dışındaki EYLEMLER için servisleri burada tutuyoruz
  final PantryService _pantryService = PantryService();
  final RecipeService _recipeService = RecipeService();
  final MarketService _marketService = MarketService();
  final ShoppingService _shoppingService = ShoppingService();
  final RecipeImporterService _importer = RecipeImporterService();

  @override
  void initState() {
    super.initState();
    // Ekran açılır açılmaz Provider'a "Verileri Getir" emrini veriyoruz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RecipeProvider>(context, listen: false).fetchAndCalculateRecommendations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Provider'ı dinliyoruz (Veri değişince burası tetiklenir)
    final recipeProvider = Provider.of<RecipeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ne Pişirsem?"),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          // Manuel Yenileme Butonu
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Listeyi Yenile",
            onPressed: () {
              recipeProvider.fetchAndCalculateRecommendations();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Liste güncelleniyor...")),
              );
            },
          ),
        ],
      ),
      
      // --- ŞEFE SOR (AI) BUTONU ---
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        icon: const Icon(Icons.auto_awesome),
        label: const Text("Şefe Sor (AI)", style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          try {
    // 1. Önce basit bir internet kontrolü (Google'a ping at)
    // Bu, harici paket kullanmadan internet var mı diye bakmanın en basit yoludur.
            final result = await InternetAddress.lookup('google.com');
            if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
              // İnternet var, devam et...
            }
          } on SocketException catch (_) {
            // İnternet yoksa hemen dur ve uyar
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white),
                    SizedBox(width: 10),
                    Text("İnternet bağlantısı yok! Şef çalışamıyor."),
                  ],
                ),
                backgroundColor: Colors.red,
              )
            );
            return; // Fonksiyondan çık
          }
          // Kileri anlık kontrol et (AI için)
          final pantrySnapshot = await _pantryService.pantryRef.get();
          final myIngredients = pantrySnapshot.docs.map((doc) => doc.data().ingredientName).toList();

          if (myIngredients.isEmpty) {
             if (!context.mounted) return;
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Önce kilerine malzeme eklemelisin!"), backgroundColor: colorScheme.error));
             return;
          }

          if (!context.mounted) return;
          // Yükleniyor Dialogu
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => Dialog(
              backgroundColor: theme.cardTheme.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: colorScheme.primary, width: 1)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: colorScheme.primary),
                    const SizedBox(height: 20),
                    Text("Cyber Chef Menüyü Hazırlıyor...", style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Önce ana yemekler ve çorbalar...", style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6))),
                  ],
                ),
              ),
            ),
          );

          try {
            // 1. AI Tarif Üretsin ve Veritabanına Yazsın
            await _importer.generateRecipesFromPantry(myIngredients);
            
            if (!context.mounted) return;
            Navigator.pop(context); // Dialogu kapat

            // 2. ÖNEMLİ: Provider'ı tetikle ki yeni gelen tarifler ekranda görünsün
            recipeProvider.fetchAndCalculateRecommendations();

            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şef yeni tarifleri hazırladı!"), backgroundColor: Colors.green));

          } catch (e) {
            if (!mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: colorScheme.error));
          }
        },
      ),

      // --- GÖVDE (Provider Durumuna Göre) ---
      body: recipeProvider.isLoading
          ? const RecipeLoadingSkeleton() // ARTIK SHIMMER KULLANIYORUZ
          : recipeProvider.error != null
              ? Center(child: Text(recipeProvider.error!, style: TextStyle(color: colorScheme.error)))
              : _buildContent(context, recipeProvider),
    );
  }

  // İçeriği Oluşturan Metot
  Widget _buildContent(BuildContext context, RecipeProvider provider) {
    final recommendations = provider.recommendations;
    final allPrices = provider.allPrices;
    final colorScheme = Theme.of(context).colorScheme;

    if (recommendations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 80, color: colorScheme.onSurface.withOpacity(0.2)),
            const SizedBox(height: 20),
            Text(
              "Henüz uygun tarif yok.\nŞefe sorarak menü oluştur!", 
              textAlign: TextAlign.center, 
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 16)
            ),
          ],
        ),
      );
    }

    // --- KATEGORİLERE GÖRE GRUPLAMA ---
    Map<String, List<dynamic>> groupedRecipes = {};
    final List<String> categoryOrder = ["Çorba", "Ana Yemek", "Aperatif", "Tatlı", "Genel"];
    
    for (var item in recommendations) {
      String cat = item['recipe'].category;
      if (!categoryOrder.contains(cat)) cat = "Genel";
      if (!groupedRecipes.containsKey(cat)) groupedRecipes[cat] = [];
      groupedRecipes[cat]!.add(item);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        for (String cat in categoryOrder)
          if (groupedRecipes.containsKey(cat) && groupedRecipes[cat]!.isNotEmpty)
            _buildCategorySection(context, cat, groupedRecipes[cat]!, allPrices),
      ],
    );
  }

  // Kategori Başlığı ve Altındaki Tarifler
  Widget _buildCategorySection(BuildContext context, String category, List<dynamic> recipes, List<MarketPrice> prices) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(_getCategoryIcon(category), color: colorScheme.secondary),
              const SizedBox(width: 8),
              Text(category, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.primary, letterSpacing: 1)),
            ],
          ),
        ),
        ...recipes.map((item) => _buildRecipeCard(context, item, prices)),
      ],
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case "Çorba": return Icons.soup_kitchen;
      case "Ana Yemek": return Icons.dinner_dining;
      case "Aperatif": return Icons.tapas;
      case "Tatlı": return Icons.icecream;
      default: return Icons.fastfood;
    }
  }

  Widget _buildRecipeCard(BuildContext context, dynamic item, List<MarketPrice> allPrices) {
    final Recipe recipe = item['recipe'];
    final double matchPercent = item['matchPercentage'];
    final List<String> missing = item['missingIngredients'];
    final List<String> subTips = item['substitutionTips'] ?? [];
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    double missingCost = 0;
    if (missing.isNotEmpty) {
      missingCost = _marketService.calculateMissingCost(missing, allPrices);
    }

    Color statusColor = matchPercent == 1.0 
        ? const Color(0xFF00E676) 
        : (matchPercent > 0.5 ? const Color(0xFFFFAB40) : const Color(0xFFFF5252));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        iconColor: colorScheme.onSurface.withOpacity(0.7),
        collapsedIconColor: colorScheme.onSurface.withOpacity(0.7),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: statusColor, width: 2),
            color: theme.cardTheme.color,
            boxShadow: isDark ? [BoxShadow(color: statusColor.withOpacity(0.2), blurRadius: 10)] : [],
          ),
          child: Center(
            child: Text(
              "%${(matchPercent * 100).toInt()}",
              style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 13),
            ),
          ),
        ),
        title: Text(recipe.name, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
        trailing: IconButton(
          icon: Icon(Icons.favorite_border, color: colorScheme.secondary),
          onPressed: () async {
            await _recipeService.saveRecipeToFavorites(recipe);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tarif favorilere kaydedildi ❤️")));
          },
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            matchPercent == 1.0 
                ? Text("Hazırsın! Başla 🎉", style: TextStyle(color: statusColor))
                : Text(
                    (missing.isEmpty && subTips.isNotEmpty) 
                        ? "Alternatiflerle Hazır ✨" 
                        : "${missing.length} eksik malzeme", 
                    style: TextStyle(color: statusColor)
                  ),
            if (missing.isNotEmpty && missingCost > 0)
               Padding(
                 padding: const EdgeInsets.only(top: 4.0),
                 child: Row(
                   children: [
                     Icon(Icons.shopping_bag_outlined, size: 14, color: colorScheme.primary),
                     const SizedBox(width: 4),
                     Text("~${missingCost.toStringAsFixed(2)} TL", style: TextStyle(color: colorScheme.primary, fontSize: 13, fontWeight: FontWeight.bold)),
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
                
                // --- ALTERNATİF MALZEME KUTUSU ---
                if (subTips.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lightbulb, color: Colors.amber, size: 18),
                            SizedBox(width: 8),
                            Text("Şefin Tavsiyesi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...subTips.map((tip) => Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text("• ${tip.replaceAll('**', '')}", style: TextStyle(color: colorScheme.onSurface.withOpacity(0.9), fontSize: 13)),
                        )),
                      ],
                    ),
                  ),

                // --- EKSİK MALZEMELER KUTUSU ---
                if (missing.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(isDark ? 0.1 : 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Eksik Malzemeler", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        const SizedBox(height: 8),
                        Text(missing.join(", "), style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8))),
                        Divider(color: colorScheme.onSurface.withOpacity(0.1), height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.add_shopping_cart, size: 18),
                            label: const Text("Listeye Ekle"),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                            onPressed: () async {
                              for (var item in missing) {
                                await _shoppingService.addItem(item);
                              }
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Eklendi!"), backgroundColor: Colors.green));
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                
                // --- BİLGİ ETİKETLERİ ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildInfoChip(context, Icons.timer, "${recipe.prepTime} dk"),
                    _buildInfoChip(context, Icons.bar_chart, recipe.difficulty),
                    _buildInfoChip(context, Icons.category, recipe.category),
                  ],
                ),
                const SizedBox(height: 24),
                
                // --- PİŞİRME BUTONU ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CookingModeScreen(
                            recipe: recipe,
                            onComplete: () => _showConsumeDialog(context, recipe),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.restaurant),
                    label: const Text("ADIM ADIM PİŞİR"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showConsumeDialog(BuildContext context, Recipe recipe) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text("Ellerine Sağlık! 👨‍🍳", style: TextStyle(color: colorScheme.onSurface)),
        content: Text("Yemeği tamamladın. Malzemeler stoktan düşülsün mü?", style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
            onPressed: () async {
              // 1. Stokları düş
              await _pantryService.consumeIngredients(recipe.ingredients);
              
              if (!context.mounted) return;
              Navigator.pop(context); // Dialogu kapat

              // 2. ÖNEMLİ: Kiler değiştiği için listeyi YENİLEMEMİZ lazım
              Provider.of<RecipeProvider>(context, listen: false).fetchAndCalculateRecommendations();

              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stoklar güncellendi!")));
            },
            child: const Text("Evet, Düş"),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.secondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }
}