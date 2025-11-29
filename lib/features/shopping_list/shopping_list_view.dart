import 'package:flutter/material.dart';
import 'dart:async';
import 'shopping_service.dart';
import '../../core/models/shopping_item.dart';
import '../../core/models/market_price.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../market/market_service.dart';
import '../../core/utils/market_utils.dart';
import '../../core/utils/pdf_export_service.dart';
import '../profile/profile_service.dart';
import '../profile/premium_screen.dart';

class ShoppingListView extends StatefulWidget {
  const ShoppingListView({super.key});
  @override
  State<ShoppingListView> createState() => _ShoppingListViewState();
}

class _ShoppingListViewState extends State<ShoppingListView> with AutomaticKeepAliveClientMixin {
  final ShoppingService _service = ShoppingService();
  final MarketService _marketService = MarketService();
  final PdfExportService _pdfService = PdfExportService();
  final ProfileService _profileService = ProfileService();

  @override
  bool get wantKeepAlive => true;

  void _showAddProductSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ProductSearchSheet(),
    );
  }

  void _shareList(List<ShoppingItem> items) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Liste boş.")));
      return;
    }
    final status = await _profileService.checkUsageRights();
    if (!status['isPremium']) {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumScreen()));
      return;
    }
    await _pdfService.shareShoppingList(items);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<List<MarketPrice>>(
      future: _marketService.getAllPrices(),
      builder: (context, priceSnapshot) {
        // Fiyatlar henüz yüklenmediyse boş liste ile devam et, UI kilitlenmesin
        final allPrices = priceSnapshot.data ?? [];

        return StreamBuilder<List<ShoppingItem>>(
          stream: _service.getShoppingList(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final items = snapshot.data ?? [];
            final bool hasCompletedItems = items.any((item) => item.isCompleted);

            return Scaffold(
              floatingActionButton: Padding(
                padding: const EdgeInsets.only(bottom: 80.0),
                child: FloatingActionButton.extended(
                  onPressed: _showAddProductSheet,
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text("Ürün Ekle"),
                ),
              ),
              
              body: Column(
                children: [
                  // --- HEADER ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${items.length} Ürün",
                          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.share, color: Colors.blue),
                              tooltip: "Paylaş",
                              onPressed: () => _shareList(items),
                            ),
                            TextButton.icon(
                              onPressed: hasCompletedItems
                                  ? () async {
                                      await _service.clearCompleted();
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Temizlendi.")));
                                    }
                                  : null,
                              icon: const Icon(Icons.delete_sweep),
                              label: const Text("Temizle"),
                              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // --- LİSTE ---
                  Expanded(
                    child: items.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.shopping_cart_outlined,
                            message: "Sepetin Bomboş!",
                            subMessage: "Sağ alttaki butona basarak ürün ve fiyatları görerek ekle.",
                          )
                        : ListView.builder(
                            itemCount: items.length,
                            padding: const EdgeInsets.only(bottom: 100),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              
                              // -- FİYAT HESAPLAMA --
                              List<Map<String, dynamic>> allPricesForItem = [];
                              // Sadece tamamlanmamış (çizilmemiş) ürünler için fiyat ara
                              if (!item.isCompleted) {
                                allPricesForItem = _marketService.findAllPricesFor(item.name, allPrices);
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Checkbox(
                                    value: item.isCompleted,
                                    activeColor: colorScheme.primary,
                                    onChanged: (val) => _service.toggleStatus(item.id, item.isCompleted),
                                  ),
                                  title: Text(
                                    item.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                                      color: item.isCompleted ? Colors.grey : colorScheme.onSurface,
                                    ),
                                  ),
                                  
                                  // --- MARKET FİYATLARI ALANI ---
                                  subtitle: (allPricesForItem.isNotEmpty && !item.isCompleted)
                                      ? Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: SizedBox(
                                            height: 32, // Yükseklik sabitleme
                                            child: ListView.builder(
                                              scrollDirection: Axis.horizontal,
                                              itemCount: allPricesForItem.length,
                                              itemBuilder: (context, pIndex) {
                                                final priceInfo = allPricesForItem[pIndex];
                                                final marketName = priceInfo['market'];
                                                final price = priceInfo['price'];
                                                final isCheapest = pIndex == 0;

                                                return Container(
                                                  margin: const EdgeInsets.only(right: 8),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isCheapest ? Colors.green.withOpacity(0.1) : theme.cardColor,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: isCheapest ? Colors.green : Colors.grey.shade300),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      // Logo Kontrolü
                                                      MarketUtils.getLogoPath(marketName).isNotEmpty
                                                          ? Image.asset(MarketUtils.getLogoPath(marketName), width: 16, height: 16)
                                                          : const Icon(Icons.store, size: 14, color: Colors.grey),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        "$price ₺",
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                          color: isCheapest ? Colors.green[700] : colorScheme.onSurface,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        )
                                      : null, // Fiyat yoksa veya ürün çizildiyse gösterme
                                  
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => _service.deleteItem(item.id),
                                  ),
                                ),
                              ).animate().fadeIn().slideX();
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// --- ÜRÜN ARAMA VE TOPLU EKLEME PANELİ ---
class ProductSearchSheet extends StatefulWidget {
  const ProductSearchSheet({super.key});

  @override
  State<ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<ProductSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  final MarketService _marketService = MarketService();
  final ShoppingService _shoppingService = ShoppingService();
  
  List<Map<String, dynamic>> _searchResults = [];
  final Set<String> _pendingItems = {}; // Toplu eklenecekler
  bool _isSearching = false;
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    // Yeni sıralama mantığıyla sonuçları getir
    final results = await _marketService.searchProducts(query);
    
    // Aynı isimli ürünleri teke düşür (Set kullanarak)
    final uniqueNames = <String>{};
    final filteredResults = results.where((item) {
      final title = item['title'].toString();
      return uniqueNames.add(title);
    }).toList();

    if (mounted) {
      setState(() {
        _searchResults = filteredResults;
        _isSearching = false;
      });
    }
  }

  void _toggleSelection(String name) {
    setState(() {
      if (_pendingItems.contains(name)) {
        _pendingItems.remove(name);
      } else {
        _pendingItems.add(name);
      }
    });
  }

  void _commitItems() async {
    for (var item in _pendingItems) {
      await _shoppingService.addItem(item);
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${_pendingItems.length} ürün listeye eklendi!"), backgroundColor: Colors.green)
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85, 
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Tutamaç
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              width: 40, height: 5,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(5)),
            ),
          ),
          
          // Arama Kutusu
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true, 
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: "Ürün ara... (Örn: Süt, Yağ)",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _searchController.clear(); _searchResults = []; }))
                  : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: theme.cardTheme.color,
              ),
              onChanged: _onSearchChanged,
              onSubmitted: (val) {
                FocusScope.of(context).unfocus(); // Klavyeyi kapat, ekleme yapma
              },
            ),
          ),

          // Sonuç Listesi
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? _searchController.text.length > 1
                        // Veritabanında yoksa manuel ekleme
                        ? ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.edit, color: Colors.blue),
                            ),
                            title: Text('"${_searchController.text}" olarak ekle'),
                            subtitle: const Text("Veritabanında yoksa bu isimle ekleyebilirsin."),
                            trailing: _pendingItems.contains(_searchController.text) 
                                ? const Icon(Icons.check_circle, color: Colors.green, size: 30)
                                : const Icon(Icons.add_circle_outline, color: Colors.grey, size: 30),
                            onTap: () => _toggleSelection(_searchController.text),
                          )
                        : Center(child: Text("Aramak için yazmaya başla...", style: TextStyle(color: Colors.grey.shade600)))
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          final String title = item['title'];
                          final String imageUrl = item['imageUrl'] ?? '';
                          final List markets = item['markets'] ?? [];
                          final bool isSelected = _pendingItems.contains(title);
                          
                          double minPrice = 0;
                          if (markets.isNotEmpty) {
                            final prices = markets.map((m) => (m['price'] as num).toDouble()).toList();
                            prices.sort();
                            minPrice = prices.first;
                          } else if (item['price'] != null) {
                             minPrice = (item['price'] as num).toDouble();
                          }

                          return ListTile(
                            leading: Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                                border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300, width: isSelected ? 2 : 1),
                              ),
                              child: imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8), 
                                      child: Image.network(
                                        imageUrl, 
                                        fit: BoxFit.cover,
                                        errorBuilder: (_,__,___) => const Icon(Icons.shopping_bag, color: Colors.orange),
                                      )
                                    )
                                  : const Icon(Icons.shopping_bag, color: Colors.orange),
                            ),
                            title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.green : null)),
                            subtitle: Row(
                              children: [
                                Icon(Icons.store, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(markets.isNotEmpty ? "${markets.length} market" : "Fiyat Var"),
                                const Spacer(),
                                if (minPrice > 0)
                                  Text("En uygun: $minPrice ₺", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            trailing: isSelected 
                                ? const Icon(Icons.check_circle, color: Colors.green, size: 30)
                                : const Icon(Icons.add_circle_outline, color: Colors.blue, size: 30),
                            onTap: () => _toggleSelection(title),
                          );
                        },
                      ),
          ),

          // --- ALT BAR (ONAY BUTONU) ---
          if (_pendingItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _commitItems,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    icon: const Icon(Icons.done_all),
                    label: Text("Seçilenleri Ekle (${_pendingItems.length})"),
                  ),
                ),
              ),
            ).animate().slideY(begin: 1, end: 0, duration: 300.ms),
        ],
      ),
    );
  }
}