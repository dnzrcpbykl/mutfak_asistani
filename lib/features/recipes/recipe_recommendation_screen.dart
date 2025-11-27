import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io'; 

// Modeller
import '../../core/models/recipe.dart';
import '../../core/models/market_price.dart';

// Servisler 
import '../pantry/pantry_service.dart';
import '../market/market_service.dart';
import '../shopping_list/shopping_service.dart';
import 'recipe_service.dart';
import 'recipe_importer_service.dart';

// Provider 
import 'recipe_provider.dart';

// Ekranlar
import 'cooking_mode_screen.dart';
import '../../core/widgets/recipe_loading_skeleton.dart';

class RecipeRecommendationScreen extends StatefulWidget {
  const RecipeRecommendationScreen({super.key});

  @override
  State<RecipeRecommendationScreen> createState() => _RecipeRecommendationScreenState();
}

class _RecipeRecommendationScreenState extends State<RecipeRecommendationScreen> {
  final PantryService _pantryService = PantryService();
  final RecipeService _recipeService = RecipeService();
  final MarketService _marketService = MarketService();
  final ShoppingService _shoppingService = ShoppingService();
  final RecipeImporterService _importer = RecipeImporterService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RecipeProvider>(context, listen: false).fetchAndCalculateRecommendations();
    });
  }

  String _cleanIngredientForShopping(String rawName) {
    String cleaned = rawName.replaceAll(RegExp(r'\s*\(.*?\)'), '');
    if (cleaned.contains(',')) {
      cleaned = cleaned.split(',').first;
    }
    cleaned = cleaned.replaceFirst(RegExp(r'^[\d\s\.,/-]+'), '');

    final List<String> unitsToRemove = [
      'su bardağı', 'çay bardağı', 'yemek kaşığı', 'çay kaşığı', 'tatlı kaşığı', 'kahve fincanı',
      'orta boy', 'büyük boy', 'küçük boy',
      'kilogram', 'gram', 'litre', 'mililitre',
      'paket', 'demet', 'tutam', 'dilim', 'diş', 'baş', 'kutu', 'kavanoz', 'avuç',
      'adet', 'tane', 
      'kg', 'gr', 'lt', 'ml'
    ];

    cleaned = cleaned.trim();
    for (var unit in unitsToRemove) {
      if (cleaned.toLowerCase().startsWith(unit.toLowerCase())) {
        cleaned = cleaned.substring(unit.length).trim();
      }
    }
    cleaned = cleaned.replaceFirst(RegExp(r'^[\d\s\.,/-]+'), '');
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }
    return cleaned.trim();
  }

  Widget _buildDifficultyVisual(String difficulty) {
    int level = 1;
    if (difficulty.toLowerCase() == 'orta') level = 2;
    if (difficulty.toLowerCase() == 'zor') level = 3;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Icon(
          Icons.local_fire_department,
          size: 18,
          color: index < level ? Colors.orange : Colors.grey.withOpacity(0.3),
        );
      }),
    );
  }

  // --- YENİ: TERCİH SEÇİM PENCERESİ ---
  void _showPreferenceDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardTheme.color,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Bugün canın ne çekiyor? 👨‍🍳", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Şef tarifleri senin moduna göre hazırlasın.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildPreferenceChip("🎲 Fark Etmez", "Genel, lezzetli öneriler sun."),
                  _buildPreferenceChip("⚡ Hızlı & Pratik", "30 dakikayı geçmeyen, pratik tarifler."),
                  _buildPreferenceChip("🥗 Sağlıklı & Diyet", "Düşük kalorili, sağlıklı sebze ağırlıklı tarifler."),
                  _buildPreferenceChip("🍲 Sulu Yemek", "Geleneksel Türk usulü tencere yemekleri."),
                  _buildPreferenceChip("🌶️ Acı & Baharatlı", "Bol baharatlı, iştah açıcı tarifler."),
                  _buildPreferenceChip("🍰 Tatlı Krizi", "Tatlı veya hamur işi tarifleri."),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreferenceChip(String label, String promptValue) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        Navigator.pop(context); // Pencereyi kapat
        _startAiGeneration(promptValue); // AI'yı başlat
      },
    );
  }

  // --- AI SÜRECİNİ BAŞLATAN FONKSİYON ---
  Future<void> _startAiGeneration(String userPreference) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw SocketException("İnternet yok");
      }
    } on SocketException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İnternet bağlantısı yok!"), backgroundColor: Colors.red));
      return; 
    }
    
    final pantrySnapshot = await _pantryService.pantryRef.get();
    final myIngredients = pantrySnapshot.docs.map((doc) => doc.data().ingredientName).toList();

    if (myIngredients.isEmpty) {
       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Önce kilerine malzeme eklemelisin!"), backgroundColor: Colors.red));
       return;
    }

    if (!mounted) return;
    
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
              Text("Tercihine uygun tarifler seçiliyor...", style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
            ],
          ),
        ),
      ),
    );

    try {
      // 1. AI Tarif Üretsin (Tercihle Birlikte)
      await _importer.generateRecipesFromPantry(myIngredients, userPreference: userPreference);
      
      if (!mounted) return;
      Navigator.pop(context); // Yükleniyor'u kapat

      // 2. Listeyi yenile
      Provider.of<RecipeProvider>(context, listen: false).fetchAndCalculateRecommendations();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şef yeni tarifleri hazırladı!"), backgroundColor: Colors.green));

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

  void _showPreparationSheet(BuildContext context, Recipe recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                ),
                const Text("Hazırlık Kontrolü 🔪", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("Şefim, başlamadan önce malzemeleri tezgaha hazırlayalım.", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: recipe.ingredients.length,
                    itemBuilder: (context, index) {
                      return CheckboxListTile(
                        value: true, 
                        activeColor: Theme.of(context).colorScheme.primary,
                        title: Text(recipe.ingredients[index], style: const TextStyle(fontWeight: FontWeight.w500)),
                        onChanged: (val) {}, 
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); 
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
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    icon: const Icon(Icons.soup_kitchen),
                    label: const Text("HER ŞEY HAZIR, PİŞİRMEYE BAŞLA!", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 20), 
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final recipeProvider = Provider.of<RecipeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ne Pişirsem?"),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
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
      
      // --- GÜNCELLENEN BUTON: Artık Dialog Açıyor ---
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        icon: const Icon(Icons.auto_awesome),
        label: const Text("Şefe Sor (AI)", style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showPreferenceDialog, // <--- Burayı değiştirdik
      ),

      body: recipeProvider.isLoading
          ? const RecipeLoadingSkeleton() 
          : recipeProvider.error != null
              ? Center(child: Text(recipeProvider.error!, style: TextStyle(color: colorScheme.error)))
              : _buildContent(context, recipeProvider),
    );
  }

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
                                String cleanItem = _cleanIngredientForShopping(item);
                                await _shoppingService.addItem(cleanItem);
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
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _buildInfoChip(context, Icons.timer_outlined, "${recipe.prepTime} dk"),
                        const SizedBox(width: 12),
                        
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colorScheme.onSurface.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              _buildDifficultyVisual(recipe.difficulty),
                              const SizedBox(width: 4),
                              Text(recipe.difficulty, style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.7))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        _buildInfoChip(context, Icons.restaurant, recipe.category),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPreparationSheet(context, recipe),
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
              await _pantryService.consumeIngredients(recipe.ingredients);
              if (!context.mounted) return;
              Navigator.pop(context); 
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