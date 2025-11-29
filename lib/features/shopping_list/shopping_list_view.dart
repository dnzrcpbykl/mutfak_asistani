import 'package:flutter/material.dart';
import 'dart:async';
import 'shopping_service.dart'; // Güncellediğimiz servis
import '../../core/models/market_price.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../market/market_service.dart';
import '../../core/utils/market_utils.dart';
import '../../core/utils/pdf_export_service.dart'; // Eğer bu yoksa importu silin
// import '../../core/models/shopping_item.dart'; // Artık Map kullanıyoruz, buna gerek kalmayabilir

class ShoppingListView extends StatefulWidget {
  const ShoppingListView({super.key});
  @override
  State<ShoppingListView> createState() => _ShoppingListViewState();
}

class _ShoppingListViewState extends State<ShoppingListView> with AutomaticKeepAliveClientMixin {
  final ShoppingService _service = ShoppingService();
  final MarketService _marketService = MarketService();
  
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.getShoppingListStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];
        final bool hasCompletedItems = items.any((item) => item['isCompleted'] == true);

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
              // --- ÜST BAR ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${items.length} Ürün",
                      style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold),
                    ),
                    if (hasCompletedItems)
                      TextButton.icon(
                        onPressed: () async {
                          await _service.clearCompleted();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Temizlendi.")));
                        },
                        icon: const Icon(Icons.delete_sweep, size: 20),
                        label: const Text("Tamamlananları Sil"),
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
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
                        subMessage: "Haydi, alacaklarını eklemeye başla.",
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        padding: const EdgeInsets.only(bottom: 100),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final String id = item['id'];
                          final String name = item['name'];
                          final bool isCompleted = item['isCompleted'] ?? false;
                          final String imageUrl = item['imageUrl'] ?? '';
                          final List markets = item['markets'] ?? [];

                          return Dismissible(
                            key: Key(id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) => _service.deleteItem(id),
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  children: [
                                    // --- 1. SATIR: Checkbox, Resim, İsim ---
                                    Row(
                                      children: [
                                        // CHECKBOX
                                        Transform.scale(
                                          scale: 1.2,
                                          child: Checkbox(
                                            value: isCompleted,
                                            activeColor: colorScheme.primary,
                                            shape: const CircleBorder(),
                                            onChanged: (val) => _service.toggleStatus(id, isCompleted),
                                          ),
                                        ),
                                        
                                        // RESİM (Varsa Göster)
                                        if (imageUrl.isNotEmpty)
                                          Container(
                                            width: 50, height: 50,
                                            margin: const EdgeInsets.only(right: 12),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey.shade200),
                                              image: DecorationImage(
                                                image: NetworkImage(imageUrl),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),

                                        // İSİM
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                                              color: isCompleted ? Colors.grey : colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // --- 2. SATIR: MARKETLER (Varsa Göster) ---
                                    if (!isCompleted && markets.isNotEmpty) ...[
                                      const Divider(height: 16),
                                      SizedBox(
                                        height: 36,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: markets.length,
                                          itemBuilder: (context, mIndex) {
                                            final m = markets[mIndex];
                                            // Veritabanı yapısından verileri al
                                            final String mName = m['marketName'] ?? '';
                                            final double price = (m['price'] as num?)?.toDouble() ?? 0.0;
                                            final String logoPath = MarketUtils.getLogoPath(mName);
                                            final bool isCheapest = mIndex == 0; // İlk sıradaki en ucuz varsayımı

                                            return GestureDetector(
                                              onTap: () => MarketUtils.launchMarketLink(mName),
                                              child: Container(
                                                margin: const EdgeInsets.only(right: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isCheapest ? Colors.green.withOpacity(0.1) : theme.cardColor,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: isCheapest ? Colors.green : Colors.grey.shade300),
                                                ),
                                                child: Row(
                                                  children: [
                                                    // Logo
                                                    if (logoPath.isNotEmpty)
                                                      Image.asset(logoPath, height: 16, width: 40, fit: BoxFit.contain)
                                                    else
                                                      const Icon(Icons.store, size: 16, color: Colors.grey),
                                                    
                                                    const SizedBox(width: 4),
                                                    // Fiyat
                                                    Text(
                                                      "${price.toStringAsFixed(2)} ₺",
                                                      style: TextStyle(
                                                        fontSize: 12, 
                                                        fontWeight: FontWeight.bold,
                                                        color: isCheapest ? Colors.green[800] : colorScheme.onSurface
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                            ).animate().fadeIn().slideX(begin: 0.1, end: 0),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- ARAMA VE EKLEME PANELİ ---
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
  // Seçilenleri artık obje olarak tutuyoruz (isim, resim, marketler vb.)
  final List<Map<String, dynamic>> _pendingItems = []; 
  bool _isSearching = false;
  Timer? _debounce;

  // Akıllı Arama Normalizasyonu
  String _normalizeForSmartSearch(String text) {
    return text.toLowerCase()
        .replaceAll('İ', 'i').replaceAll('I', 'ı').replaceAll('ı', 'i')
        .replaceAll('ğ', 'g').replaceAll('ü', 'u').replaceAll('ş', 's')
        .replaceAll('ö', 'o').replaceAll('ç', 'c')
        .replaceAll(' ', '').replaceAll('-', '').trim();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (query.trim().length >= 2) _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    
    final allPrices = await _marketService.getAllPrices(); 
    final searchKey = _normalizeForSmartSearch(query);

    final filtered = allPrices.where((marketItem) {
      final normalizedItemTitle = _normalizeForSmartSearch(marketItem.ingredientName);
      return normalizedItemTitle.contains(searchKey);
    }).toList();

    // Sonuçları Grupla ve Formatla
    // Artık tam ürün objesini oluşturuyoruz
    final uniqueResults = <String, Map<String, dynamic>>{};
    
    // NOT: getAllPrices fonksiyonu artık "MarketPrice" dönüyor olabilir ama
    // bizim burada "searchProducts" gibi zengin veri dönen bir metoda ihtiyacımız var.
    // MarketService'de yazdığımız "searchProducts" metodunu kullanacağız.
    final richResults = await _marketService.searchProducts(query);

    // Gelen sonuçları tekilleştir
    for (var item in richResults) {
      final title = item['title'];
      if (!uniqueResults.containsKey(title)) {
        uniqueResults[title] = item;
      }
    }

    if (mounted) {
      setState(() {
        _searchResults = uniqueResults.values.toList();
        _isSearching = false;
      });
    }
  }

  void _toggleSelection(Map<String, dynamic> item) {
    setState(() {
      final isSelected = _pendingItems.any((i) => i['title'] == item['title']);
      if (isSelected) {
        _pendingItems.removeWhere((i) => i['title'] == item['title']);
      } else {
        _pendingItems.add(item);
      }
    });
  }

  // --- KRİTİK: EKLEME İŞLEMİ ---
  void _commitItems() async {
    int count = 0;
    for (var item in _pendingItems) {
      // Servise sadece isim değil, RESİM ve MARKETLERİ de gönderiyoruz
      bool added = await _shoppingService.addItem(
        name: item['title'], 
        imageUrl: item['imageUrl'],
        markets: item['markets'] // Market listesi (fiyatlar, logolar burada)
      );
      if (added) count++;
    }
    
    if (mounted) {
      Navigator.pop(context);
      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$count ürün eklendi!"), backgroundColor: Colors.green)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(5))),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: "Ürün ara (Örn: Süt, Yağ)",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _searchController.clear(); _searchResults.clear(); })) : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: theme.cardTheme.color,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _searchResults.length,
                    separatorBuilder: (_,__) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _searchResults[index];
                      final title = item['title'];
                      final imageUrl = item['imageUrl'];
                      final markets = item['markets'] as List;
                      final isSelected = _pendingItems.any((i) => i['title'] == title);

                      // En uygun fiyatı bul
                      double minPrice = 0;
                      if (markets.isNotEmpty) {
                        final prices = markets.map((m) => (m['price'] as num).toDouble()).toList();
                        prices.sort();
                        minPrice = prices.first;
                      }

                      return ListTile(
                        onTap: () => _toggleSelection(item),
                        leading: Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                            border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300, width: isSelected ? 2 : 1),
                          ),
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(imageUrl, fit: BoxFit.cover))
                              : const Icon(Icons.shopping_bag, color: Colors.orange),
                        ),
                        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Row(
                          children: [
                            if (markets.isNotEmpty) ...[
                              Icon(Icons.store, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text("${markets.length} market"),
                              const Spacer(),
                              Text("En uygun: ${minPrice.toStringAsFixed(2)} ₺", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ] else 
                              const Text("Fiyat bilgisi yok"),
                          ],
                        ),
                        trailing: isSelected 
                            ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
                            : const Icon(Icons.add_circle_outline, color: Colors.blue, size: 28),
                      );
                    },
                  ),
          ),
          if (_pendingItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.cardTheme.color,
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _commitItems,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                    icon: const Icon(Icons.shopping_basket),
                    label: Text("Seçilenleri Ekle (${_pendingItems.length})"),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}