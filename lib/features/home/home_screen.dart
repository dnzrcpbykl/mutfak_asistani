import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../pantry/add_pantry_item_screen.dart';
import '../pantry/pantry_service.dart';
import '../../core/models/pantry_item.dart';
import '../shopping_list/shopping_list_view.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/widgets/empty_state_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  // Dashboard'dan erişim için
  static final ValueNotifier<int> tabChangeNotifier = ValueNotifier<int>(0);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _mainTabController;

  @override
  void initState() {
    super.initState();
    int initialIndex = HomeScreen.tabChangeNotifier.value;
    if (initialIndex > 1) initialIndex = 0;

    _mainTabController = TabController(length: 2, vsync: this, initialIndex: initialIndex);
    
    // Senkronizasyon dinleyicileri
    _mainTabController.addListener(_syncTabNotifier);
    HomeScreen.tabChangeNotifier.addListener(_onExternalTabChange);
  }

  void _syncTabNotifier() {
    if (_mainTabController.indexIsChanging) {
      HomeScreen.tabChangeNotifier.value = _mainTabController.index;
    }
  }

  void _onExternalTabChange() {
    if (!mounted) return;
    final targetIndex = HomeScreen.tabChangeNotifier.value;
    if (_mainTabController.index != targetIndex) {
      _mainTabController.animateTo(targetIndex);
    }
  }

  @override
  void dispose() {
    HomeScreen.tabChangeNotifier.removeListener(_onExternalTabChange);
    _mainTabController.removeListener(_syncTabNotifier);
    _mainTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.kitchen, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text("Mutfak Asistanı"),
          ],
        ),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _mainTabController,
          indicatorColor: colorScheme.primary, 
          labelColor: colorScheme.primary, 
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "Kilerim"),
            Tab(text: "Alışveriş"),
          ],
        ),
      ),
      
      body: TabBarView(
        controller: _mainTabController,
        children: const [
          PantryTab(), // YENİ: Kiler görünümü artık kendi sınıfında
          ShoppingListView(), // Alışveriş listesi
        ],
      ),

      floatingActionButton: ValueListenableBuilder<int>(
        valueListenable: HomeScreen.tabChangeNotifier,
        builder: (context, value, child) {
          return value == 0
            ? FloatingActionButton(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary, 
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AddPantryItemScreen()),
                  );
                },
                child: const Icon(Icons.add),
              )
            : const SizedBox.shrink(); // Alışveriş listesindeyken gizle (kendi butonu var)
        },
      )
    );
  }
}

// --- YENİ SINIF: PantryTab (Kiler Sekmesi) ---
// Bu sınıf sayesinde sekme değişse bile veriler silinmez (KeepAlive)
class PantryTab extends StatefulWidget {
  const PantryTab({super.key});

  @override
  State<PantryTab> createState() => _PantryTabState();
}

class _PantryTabState extends State<PantryTab> with AutomaticKeepAliveClientMixin {
  final PantryService _pantryService = PantryService();
  late Stream<List<PantryItem>> _pantryStream;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final List<String> _categories = [
    "Tümü", "Meyve & Sebze", "Et & Tavuk & Balık", "Süt & Kahvaltılık",
    "Temel Gıda & Bakliyat", "Atıştırmalık", "İçecekler", "Diğer"
  ];

  // BU SATIR ÇOK ÖNEMLİ: Sayfayı canlı tutar
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pantryStream = _pantryService.getPantryItems();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ... (Yardımcı fonksiyonlar buraya taşındı) ...
  Color _getExpirationColor(DateTime? expirationDate) {
    if (expirationDate == null) return AppTheme.neonCyan;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expirationDate.year, expirationDate.month, expirationDate.day);
    
    final difference = exp.difference(today).inDays;
    if (difference < 0) return const Color(0xFFFF5252);
    if (difference <= 2) return const Color(0xFFFFAB40);
    return const Color(0xFF69F0AE);
  }

  String _normalizeCategory(String aiCategory) {
    if (aiCategory.contains("Sebze") || aiCategory.contains("Meyve")) return "Meyve & Sebze";
    if (aiCategory.contains("Et") || aiCategory.contains("Tavuk") || aiCategory.contains("Balık")) return "Et & Tavuk & Balık";
    if (aiCategory.contains("Süt") || aiCategory.contains("Peynir") || aiCategory.contains("Yoğurt") || aiCategory.contains("Kahvaltılık")) return "Süt & Kahvaltılık";
    if (aiCategory.contains("Bakliyat") || aiCategory.contains("Yağ") || aiCategory.contains("Makarna") || aiCategory.contains("Temel")) return "Temel Gıda & Bakliyat";
    if (aiCategory.contains("İçecek")) return "İçecekler";
    if (aiCategory.contains("Atıştırmalık") || aiCategory.contains("Çikolata")) return "Atıştırmalık";
    if (_categories.contains(aiCategory)) return aiCategory;
    return "Diğer";
  }
  
  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains("meyve") || cat.contains("sebze")) return Icons.eco;
    if (cat.contains("et") || cat.contains("tavuk") || cat.contains("balık")) return Icons.kebab_dining;
    if (cat.contains("süt") || cat.contains("kahvaltı") || cat.contains("peynir")) return Icons.egg_alt;
    if (cat.contains("bakliyat") || cat.contains("makarna") || cat.contains("un")) return Icons.grain;
    if (cat.contains("atıştırmalık") || cat.contains("çikolata")) return Icons.cookie;
    if (cat.contains("içecek") || cat.contains("su")) return Icons.local_drink;
    return Icons.category;
  }

  String _formatQuantity(double quantity) {
    if (quantity % 1 == 0) return quantity.toInt().toString();
    return quantity.toStringAsFixed(2);
  }

  void _showQuantityDialog(PantryItem item, bool isIncrement) {
    final controller = TextEditingController();
    double defaultAmount = 1.0;
    if (item.pieceCount > 1 && item.quantity > 0) {
      defaultAmount = item.quantity / item.pieceCount;
    } else {
      if (item.unit.toLowerCase() == 'gr' || item.unit.toLowerCase() == 'g') defaultAmount = 100;
      if (item.unit.toLowerCase() == 'ml') defaultAmount = 200;
    }
    controller.text = _formatQuantity(defaultAmount);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text(isIncrement ? "Stok Ekle" : "Stok Düş"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${item.ingredientName} (${item.unit})"),
            if (item.pieceCount > 1) 
              Text("Şu an: ${item.pieceCount} Paket", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: isIncrement ? "Eklenecek Miktar" : "Kullanılan Miktar",
                suffixText: item.unit,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text.replaceAll(',', '.'));
              if (val != null && val > 0) {
                double newQuantity = isIncrement ? item.quantity + val : item.quantity - val;
                int newPieceCount = item.pieceCount;
                if (item.pieceCount > 0) {
                  double singlePackageSize = item.quantity / item.pieceCount;
                  if ((val - singlePackageSize).abs() < 0.1) {
                     if (isIncrement) newPieceCount++; else newPieceCount--;
                  }
                }
                if (newQuantity <= 0) {
                   await _pantryService.deletePantryItem(item.id);
                } else {
                   await _pantryService.updatePantryItemQuantity(item.id, newQuantity, newPieceCount: newPieceCount > 0 ? newPieceCount : 1);
                }
                if (context.mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isIncrement ? Colors.green : Colors.orange,
              foregroundColor: Colors.white
            ),
            child: Text(isIncrement ? "Ekle" : "Düş"),
          )
        ],
      ),
    );
  }

  void _showEditDialog(PantryItem item) {
    final nameController = TextEditingController(text: item.ingredientName);
    final quantityController = TextEditingController(text: _formatQuantity(item.quantity));
    final unitController = TextEditingController(text: item.unit);
    final pieceCountController = TextEditingController(text: item.pieceCount.toString());
    DateTime? tempDate = item.expirationDate;
    String selectedCategory = item.category;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).cardTheme.color,
            title: const Text("Ürünü Düzenle"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: "Ürün Adı")),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: quantityController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Toplam Miktar"))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: unitController, decoration: const InputDecoration(labelText: "Birim"))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: pieceCountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Kaç Paket? (Opsiyonel)")),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _categories.contains(selectedCategory) ? selectedCategory : "Diğer",
                    decoration: const InputDecoration(labelText: "Kategori"),
                    items: _categories.where((c) => c != "Tümü").map((String category) {
                      return DropdownMenuItem(value: category, child: Text(category));
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedCategory = val ?? "Diğer"),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tempDate == null ? "Son Kullanma Tarihi Ekle" : "SKT: ${DateFormat('dd/MM/yyyy').format(tempDate!)}"),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: tempDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setDialogState(() => tempDate = picked);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
              ElevatedButton(
                onPressed: () async {
                  final newName = nameController.text.trim();
                  final newQty = double.tryParse(quantityController.text.replaceAll(',', '.')) ?? item.quantity;
                  final newUnit = unitController.text.trim();
                  final newPiece = int.tryParse(pieceCountController.text) ?? 1; 

                  if (newName.isNotEmpty && newQty > 0) {
                    await _pantryService.updatePantryItemDetails(
                      itemId: item.id,
                      name: newName,
                      quantity: newQty,
                      unit: newUnit,
                      expirationDate: tempDate,
                      category: selectedCategory,
                      pieceCount: newPiece, 
                    );
                    if (mounted) Navigator.pop(context);
                  }
                },
                child: const Text("Kaydet"),
              )
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // KEEP ALIVE İÇİN ZORUNLU
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<PantryItem>>(
      stream: _pantryStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allItems = snapshot.data ?? [];
        final bool isSearching = _searchQuery.isNotEmpty;

        return Column(
          children: [
            // ARAMA ÇUBUĞU
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Kilerde ara (Örn: Süt, Makarna)",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); FocusScope.of(context).unfocus(); }) 
                    : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                ),
              ),
            ),

            // İÇERİK ALANI
            Expanded(
              child: isSearching
                  ? _buildCategoryList("Tümü", allItems)
                  : DefaultTabController(
                      length: _categories.length,
                      child: Column(
                        children: [
                          Container(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: TabBar(
                              isScrollable: true, 
                              tabAlignment: TabAlignment.start,
                              indicatorColor: colorScheme.primary,
                              labelColor: colorScheme.primary,
                              unselectedLabelColor: Colors.grey,
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              tabs: _categories.map((category) => Tab(text: category)).toList(),
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: _categories.map((category) {
                                return _buildCategoryList(category, allItems);
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryList(String category, List<PantryItem> allItems) {
    final filteredItems = allItems.where((item) {
      final matchesCategory = category == "Tümü" ? true : _normalizeCategory(item.category) == category;
      final matchesSearch = _searchQuery.isEmpty ? true : item.ingredientName.toLowerCase().replaceAll('ı', 'i').contains(_searchQuery.replaceAll('ı', 'i'));
      return matchesCategory && matchesSearch;
    }).toList();

    if (filteredItems.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return const EmptyStateWidget(icon: Icons.search_off, message: "Sonuç Bulunamadı", subMessage: "Farklı bir kelime deneyebilirsin.");
      }
      return EmptyStateWidget(icon: Icons.kitchen, message: "$category Rafı Boş", subMessage: "Sağ alttaki (+) butonuyla ürün ekleyebilirsin.");
    }

    return ListView.builder(
      itemCount: filteredItems.length,
      padding: EdgeInsets.only(bottom: 80 + MediaQuery.of(context).padding.bottom, top: 10),
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return _buildPantryItemTile(item, Theme.of(context).colorScheme)
            .animate(delay: (index * 50).ms).slideY(begin: 0.2, end: 0).fadeIn();
      },
    );
  }

  Widget _buildPantryItemTile(PantryItem item, ColorScheme colorScheme) {
    final expirationColor = _getExpirationColor(item.expirationDate);
    String quantityText = "";
    if (item.pieceCount > 1) {
      double singleSize = item.quantity / item.pieceCount;
      quantityText = "${item.pieceCount} x ${_formatQuantity(singleSize)} ${item.unit}";
    } else {
      quantityText = "${_formatQuantity(item.quantity)} ${item.unit}";
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: expirationColor.withOpacity(0.5)),
                color: expirationColor.withOpacity(0.1),
              ),
              child: Icon(_getCategoryIcon(item.category), color: expirationColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.ingredientName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: colorScheme.onSurface)),
                  if (item.brand != null && item.brand!.isNotEmpty)
                    Text(item.brand!, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
                  Text(quantityText, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (item.expirationDate != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: expirationColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: expirationColor.withOpacity(0.3))),
                    child: Text(DateFormat('dd/MM').format(item.expirationDate!), style: TextStyle(color: expirationColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(onTap: () => _showEditDialog(item), borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.edit, size: 18, color: Colors.blue))),
                    const SizedBox(width: 8),
                    InkWell(onTap: () => _showQuantityDialog(item, false), borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.remove, size: 18, color: Colors.orange))),
                    const SizedBox(width: 8),
                    InkWell(onTap: () => _showQuantityDialog(item, true), borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.add, size: 18, color: Colors.green))),
                    const SizedBox(width: 8),
                    InkWell(onTap: () => _pantryService.deletePantryItem(item.id), borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.delete_outline, size: 18, color: Colors.red))),
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}