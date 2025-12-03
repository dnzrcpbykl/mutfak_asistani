// lib/features/recipes/recipe_recommendation_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:ui'; // Blur efekti için gerekli

// Modeller
import '../../core/models/recipe.dart';
import '../../core/models/market_price.dart';

// Servisler
import '../pantry/pantry_service.dart';
import '../market/market_service.dart';
import '../shopping_list/shopping_service.dart';
import 'recipe_service.dart';
import 'recipe_importer_service.dart';
import '../../core/utils/ad_service.dart'; 
import '../profile/profile_service.dart'; 

// Provider
import 'recipe_provider.dart';
import '../profile/premium_screen.dart'; 
import '../../core/utils/pdf_export_service.dart';

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
  final AdService _adService = AdService(); 
  final ProfileService _profileService = ProfileService(); 
  final TextEditingController _customPromptController = TextEditingController(); 
  final PdfExportService _pdfService = PdfExportService();

  // Kullanıcının premium durumu
  bool _isUserPremium = false;

  @override
  void initState() {
    super.initState();
    _adService.loadRewardedAd(); 
    
    // Premium durumunu kontrol et
    _profileService.checkUsageRights().then((val) {
       if(mounted) setState(() => _isUserPremium = val['isPremium']);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Sayfa her açıldığında gereksiz yükleme yapmasın (forceRefresh: false)
      Provider.of<RecipeProvider>(context, listen: false).fetchAndCalculateRecommendations();
    });
  }

  // --- İŞLEMİ BAŞLATAN MERKEZ ---
  void _processRequest(String? presetPrompt, {String? customText}) async {
    await _profileService.incrementUsage();
    _startAiGeneration(presetPrompt ?? "Fark etmez", customInstruction: customText);
  }

  // --- PREMİUM & REKLAM KONTROLÜ ---
  void _showPreferenceDialog() async {
    final status = await _profileService.checkUsageRights();
    final bool isPremium = status['isPremium'];
    final bool needsAd = status['needsAd'];

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, 
            left: 20, right: 20, top: 20
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Şef Menüyü Hazırlasın 👨‍🍳", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (isPremium) 
                    const Chip(label: Text("PREMIUM", style: TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: Colors.amber)
                  else
                    Chip(label: Text(needsAd ? "REKLAMLI" : "ÜCRETSİZ", style: const TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: needsAd ? Colors.purple : Colors.green),
                ],
              ),
              const SizedBox(height: 10),
              
              if (!isPremium && needsAd)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.purple.withAlpha((0.1 * 255).round()), borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [Icon(Icons.ondemand_video, size: 16, color: Colors.purple), SizedBox(width: 8), Expanded(child: Text("Günlük ücretsiz hakkın doldu. Yeni tarif için kısa bir reklam izlemelisin.", style: TextStyle(fontSize: 12)))]),
                ),

              const SizedBox(height: 15),

              if (isPremium) ...[
                const Text("Sana Özel İstek:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                TextField(
                  controller: _customPromptController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: "Örn: Elimdeki tavukla, bol baharatlı ama içinde sarımsak olmayan bir fırın yemeği istiyorum...",
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 10),
                const Center(child: Text("- VEYA HAZIRLARDAN SEÇ -", style: TextStyle(color: Colors.grey, fontSize: 10))),
                const SizedBox(height: 10),
              ],

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPreferenceChip("🎲 Fark Etmez", "Genel, lezzetli öneriler sun.", isPremium, needsAd),
                  _buildPreferenceChip("⚡ Hızlı & Pratik", "30 dakikayı geçmeyen, pratik tarifler.", isPremium, needsAd),
                  _buildPreferenceChip("🥗 Sağlıklı", "Düşük kalorili, sağlıklı tarifler.", isPremium, needsAd),
                  _buildPreferenceChip("🌶️ Acı Sever", "Bol baharatlı tarifler.", isPremium, needsAd),
                  _buildPreferenceChip("🍲 Sulu Yemek", "Geleneksel Türk usulü tencere yemekleri.", isPremium, needsAd),
                  _buildPreferenceChip("🍰 Tatlı Krizi", "Tatlı veya hamur işi tarifleri.", isPremium, needsAd),
                ],
              ),
              
              if (isPremium)
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_customPromptController.text.isNotEmpty) {
                          Navigator.pop(context);
                          _processRequest(null, customText: _customPromptController.text);
                        }
                      },
                      icon: const Icon(Icons.send),
                      label: const Text("Özel İsteği Gönder"),
                    ),
                  ),
                ),

              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreferenceChip(String label, String promptValue, bool isPremium, bool needsAd) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        Navigator.pop(context);
        if (isPremium) {
          _processRequest(promptValue);
        } else {
          if (needsAd) {
            _adService.showRewardedAd(
              onRewardEarned: () => _processRequest(promptValue)
            );
          } else {
            _processRequest(promptValue);
          }
        }
      },
    );
  }

  // --- AI SÜRECİ ---
  Future<void> _startAiGeneration(String userPreference, {String? customInstruction}) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw const SocketException("İnternet yok");
      }
    } on SocketException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İnternet bağlantısı yok!"), backgroundColor: Colors.red));
      return; 
    }
    
    final pantryRef = await _pantryService.getPantryCollection();
    final pantrySnapshot = await pantryRef.get();
    
    final myIngredients = pantrySnapshot.docs.map((doc) => doc.data().ingredientName).toList();

    if (myIngredients.isEmpty) {
       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Önce kilerine malzeme eklemelisin! (Hane kilerin boş olabilir)"), backgroundColor: Colors.red));
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
              Text("Tercihine uygun tarifler seçiliyor...", style: TextStyle(color: colorScheme.onSurface.withAlpha((0.6 * 255).round()), fontSize: 12)),
            ],
          ),
        ),
      ),
    );

    try {
      await _importer.generateRecipesFromPantry(myIngredients, userPreference: userPreference, customInstruction: customInstruction);
      
      if (!mounted) return;
      Navigator.pop(context); 

      // Yeni tarifler üretildi, bu yüzden listeyi ZORLA YENİLE
      Provider.of<RecipeProvider>(context, listen: false).fetchAndCalculateRecommendations(forceRefresh: true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şef yeni tarifleri hazırladı!"), backgroundColor: Colors.green));

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
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
          color: index < level ? Colors.orange : Colors.grey.withAlpha((0.3 * 255).round()),
        );
      }),
    );
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
                  decoration: BoxDecoration(color: Colors.grey.withAlpha((0.3 * 255).round()), borderRadius: BorderRadius.circular(2)),
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
    final colorScheme = Theme.of(context).colorScheme;
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
              Provider.of<RecipeProvider>(context, listen: false)
                  .fetchAndCalculateRecommendations(forceRefresh: true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Fiyatlar ve tarifler güncelleniyor...")),
              );
            },
          ),
        ],
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        icon: const Icon(Icons.auto_awesome),
        label: const Text("Şefe Sor (AI)", style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showPreferenceDialog, 
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
    final allPrices = provider.allPrices; // List<MarketPrice>
    final colorScheme = Theme.of(context).colorScheme;

    if (recommendations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 80, color: colorScheme.onSurface.withAlpha((0.2 * 255).round())),
            const SizedBox(height: 20),
            Text(
              "Henüz uygun tarif yok.\nŞefe sorarak menü oluştur!", 
              textAlign: TextAlign.center, 
              style: TextStyle(color: colorScheme.onSurface.withAlpha((0.6 * 255).round()), fontSize: 16)
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
    // --- YENİ EKLENEN: TAMAMLANDI KONTROLÜ ---
    final isCompleted = Provider.of<RecipeProvider>(context).isRecipeCompleted(recipe.name);
    // ------------------------------------------
    
    final double matchPercent = item['matchPercentage'];
    final List<String> missing = item['missingIngredients'];
    final List<String> subTips = item['substitutionTips'] ?? [];
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // --- FİYAT HESAPLAMA ---
    double missingCost = 0;
    if (missing.isNotEmpty) {
      missingCost = _marketService.calculateMissingCost(missing, allPrices);
    }
    // -----------------------

    Color statusColor = matchPercent == 1.0 
        ? const Color(0xFF00E676) 
        : (matchPercent > 0.5 ? const Color(0xFFFFAB40) : const Color(0xFFFF5252));

    return Card(
      // TAMAMLANDIYSA YEŞİLİMTRAK YAP
      color: isCompleted ? Colors.green.withAlpha((0.1 * 255).round()) : null,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        iconColor: colorScheme.onSurface.withAlpha((0.7 * 255).round()),
        collapsedIconColor: colorScheme.onSurface.withAlpha((0.7 * 255).round()),
        leading: isCompleted 
            // TAMAMLANDI İKONU
            ? const Icon(Icons.check_circle, color: Colors.green, size: 40)
            // YÜZDE YUVARLAĞI (ESKİ)
            : Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor, width: 2),
                  color: theme.cardTheme.color,
                  boxShadow: isDark ? [BoxShadow(color: statusColor.withAlpha((0.2 * 255).round()), blurRadius: 10)] : [],
                ),
                child: Center(
                  child: Text(
                    "%${(matchPercent * 100).toInt()}",
                    style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 13),
                  ),
                ),
              ),
        title: Text(
          recipe.name, 
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            color: colorScheme.onSurface,
            // TAMAMLANDIYSA ÇİZ
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          )
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.share, color: Colors.blueGrey),
              onPressed: () async {
                if (!_isUserPremium) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumScreen()));
                } else {
                  await _pdfService.shareRecipe(recipe);
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.favorite_border, color: colorScheme.secondary),
              onPressed: () async {
                await _recipeService.saveRecipeToFavorites(recipe);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tarif favorilere kaydedildi ❤️")));
              },
            ),
          ],
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
            
            // --- FİYAT GÖSTERİMİ ---
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
            // -----------------------
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // BESİN DEĞERLERİ
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isUserPremium ? Colors.green.withAlpha((0.1 * 255).round()) : Colors.grey.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isUserPremium ? Colors.green.withAlpha((0.3 * 255).round()) : Colors.grey.withAlpha((0.3 * 255).round())),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Besin Değerleri (1 Porsiyon)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          if (!_isUserPremium) 
                            const Icon(Icons.lock, size: 14, color: Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      _isUserPremium 
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMacroItem("Kalori", recipe.calories, Colors.orange),
                              _buildMacroItem("Protein", recipe.protein, Colors.blue),
                              _buildMacroItem("Karb.", recipe.carbs, Colors.brown),
                              _buildMacroItem("Yağ", recipe.fat, Colors.red),
                            ],
                          )
                        : GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumScreen())),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ImageFiltered(
                                  imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildMacroItem("Kalori", "450 kcal", Colors.grey),
                                      _buildMacroItem("Protein", "20g", Colors.grey),
                                      _buildMacroItem("Karb.", "45g", Colors.grey),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha((0.6 * 255).round()),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    "Premium'a Özel",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                )
                              ],
                            ),
                          ),
                    ],
                  ),
                ),

                if (subTips.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(((isDark ? 0.15 : 0.1) * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withAlpha((0.5 * 255).round())),
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
                          child: Text("• ${tip.replaceAll('**', '')}", style: TextStyle(color: colorScheme.onSurface.withAlpha((0.9 * 255).round()), fontSize: 13)),
                        )),
                      ],
                    ),
                  ),

                if (missing.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(((isDark ? 0.1 : 0.05) * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withAlpha((0.3 * 255).round())),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Eksik Malzemeler", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        const SizedBox(height: 8),
                        Text(missing.join(", "), style: TextStyle(color: colorScheme.onSurface.withAlpha((0.8 * 255).round()))),
                        Divider(color: colorScheme.onSurface.withAlpha((0.1 * 255).round()), height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.add_shopping_cart, size: 18),
                            label: const Text("Listeye Ekle"),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                            
                            // --- AKILLI LİSTE EKLEME ---
                            onPressed: () async {
                              // 1. Ürünleri Bul (Resimli, Fiyatlı)
                              List<MarketPrice> productsToAdd = _marketService.findMatchingProducts(missing, allPrices);

                              int addedCount = 0;
                              for (var product in productsToAdd) {
                                // 2. Market bilgisini formatla
                                List<Map<String, dynamic>> marketList = product.markets.map((m) => {
                                  'marketName': m.marketName,
                                  'price': m.price,
                                  'unitPriceText': m.unitPriceText
                                }).toList();

                                // 3. Zengin veriyi listeye ekle
                                bool result = await _shoppingService.addItem(
                                  name: product.title, 
                                  imageUrl: product.imageUrl,
                                  markets: marketList
                                );
                                
                                if (result) addedCount++;
                              }

                              if (!context.mounted) return;
                              
                              if (addedCount > 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("$addedCount ürün akıllı eşleşme ile eklendi!"), backgroundColor: Colors.green)
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Bu ürünler zaten listede var."), backgroundColor: Colors.orange)
                                );
                              }
                            },
                            // ------------------------------------------------
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
                            border: Border.all(color: colorScheme.onSurface.withAlpha((0.1 * 255).round())),
                          ),
                          child: Row(
                            children: [
                              _buildDifficultyVisual(recipe.difficulty),
                              const SizedBox(width: 4),
                              Text(recipe.difficulty, style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withAlpha((0.7 * 255).round()))),
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

  void _showConsumeDialog(BuildContext parentContext, Recipe recipe) {
    final colorScheme = Theme.of(parentContext).colorScheme;

    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).cardTheme.color,
        title: Text("Ellerine Sağlık! 👨‍🍳", style: TextStyle(color: colorScheme.onSurface)),
        content: Text(
          "Yemeği tamamladın. Tarifteki miktarlar (${recipe.ingredients.length} kalem) kiler stoğundan düşülsün mü?",
          style: TextStyle(color: colorScheme.onSurface.withAlpha((0.7 * 255).round())),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("İptal")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
            onPressed: () async {
              // Akıllı düşüm işlemini başlat (dialog'ı açık bırakıyoruz, sonuç sonrası kapatacağız)
              final logs = await _pantryService.consumeIngredientsSmart(recipe.ingredients);

              // await'dan hemen sonra mounted kontrolü yap ve UI işlemlerini gerçekleştirelim
              if (!mounted) return;

              // İlk diyaloğu kapat (kök context'i kullanıyoruz)
              Navigator.pop(parentContext);

              // Yükleniyor/snackbar göster
              ScaffoldMessenger.of(parentContext).showSnackBar(const SnackBar(content: Text("Stoklar güncellendi.")));

              // YENİ: Tarif tamamlandı olarak işaretle ve listeyi yenile (provider'ı burada alıyoruz)
              final recipeProvider = Provider.of<RecipeProvider>(parentContext, listen: false);
              recipeProvider.markRecipeAsCompleted(recipe.name);
              recipeProvider.fetchAndCalculateRecommendations(forceRefresh: true);

              // Sonuç raporunu göster
              if (!mounted) return;
              showDialog(
                context: parentContext,
                builder: (ctx) => AlertDialog(
                  title: const Text("Stok Raporu 📋"),
                  content: SizedBox(
                    height: 200,
                    width: double.maxFinite,
                    child: ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (c, i) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.check, size: 16, color: Colors.green),
                        title: Text(logs[i], style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Tamam"))
                  ],
                ),
              );
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
        border: Border.all(color: colorScheme.onSurface.withAlpha((0.1 * 255).round())),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.secondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: colorScheme.onSurface.withAlpha((0.7 * 255).round()), fontSize: 12)),
        ],
      ),
    );
  }
  
  Widget _buildMacroItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}