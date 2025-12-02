import 'package:flutter/material.dart';
import 'dart:async';
import 'shopping_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../market/market_service.dart';
import '../../core/utils/market_utils.dart';
import '../../core/utils/pdf_export_service.dart';

// --- YENİ EKLENEN IMPORTLAR (Kiler Entegrasyonu İçin) ---
import '../pantry/pantry_service.dart';
import '../../core/models/pantry_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 
// --------------------------------------------------------

class ShoppingListView extends StatefulWidget {
  const ShoppingListView({super.key});
  @override
  State<ShoppingListView> createState() => _ShoppingListViewState();
}

class _ShoppingListViewState extends State<ShoppingListView> with AutomaticKeepAliveClientMixin {
  final ShoppingService _service = ShoppingService();
  final MarketService _marketService = MarketService();
  
  // --- YENİ SERVİS ---
  final PantryService _pantryService = PantryService(); 

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

  // --- YARDIMCI: İSİM TEMİZLEME MOTORU ---
  String _cleanProductNameForPantry(String fullName) {
    String name = fullName;
    
    // 1. Gramaj ve detayları parantez içine almadan temizle
    // Örn: "Yumurta Organik 10lu M 53-62 Gr" -> "Yumurta Organik 10lu"
    
    // Sona gelen "Gr", "KG", "ML" gibi birimleri sil
    name = name.replaceAll(RegExp(r'\s*\d+(\.\d+)?\s*(gr|gram|kg|kilogram|lt|ml|litre)\s*$', caseSensitive: false), '');
    
    // "53-62 Gr" gibi aralıkları sil
    name = name.replaceAll(RegExp(r'\s*\d+-\d+\s*(gr|gram)\s*', caseSensitive: false), '');

    // "M boy", "L boy" gibi ifadeleri sil
    name = name.replaceAll(RegExp(r'\s+[SMLX]+\s+Boy\s*', caseSensitive: false), ' ');

    return name.trim();
  }

  // --- GÜNCELLENEN FONKSİYON: ÜRÜNÜ KİLERE TAŞI ---
  Future<void> _moveItemToPantry(Map<String, dynamic> item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. İSMİ TEMİZLE
    String originalName = item['name'];
    String cleanName = _cleanProductNameForPantry(originalName);
    
    String imageUrl = item['imageUrl'] ?? '';
    List markets = item['markets'] ?? [];
    
    double bestPrice = 0.0;
    String bestMarket = "Bilinmiyor";
    
    if (markets.isNotEmpty) {
      List<dynamic> sortedMarkets = List.from(markets);
      sortedMarkets.sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
      bestPrice = (sortedMarkets.first['price'] as num).toDouble();
      bestMarket = sortedMarkets.first['marketName'] ?? "Bilinmiyor";
    }

    // 2. KATEGORİ TAHMİNİ (Kilerde doğru sekmeye gitmesi için)
    // Basit bir tahmin yapıp PantryService'e göndereceğiz, o da normalize edecek.
    String estimatedCategory = "Diğer";
    String lowerName = cleanName.toLowerCase();
    if (lowerName.contains("yumurta") || lowerName.contains("peynir")) {
      estimatedCategory = "Süt Ürünleri ve Kahvaltılık";
    } else if (lowerName.contains("kıyma") || lowerName.contains("salam")) estimatedCategory = "Et, Tavuk ve Balık";
    else if (lowerName.contains("domates") || lowerName.contains("biber")) estimatedCategory = "Meyve ve Sebze";

    // 3. Kullanıcıya SKT, Miktar ve BİRİM sormak için Diyalog
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7)); 
    TextEditingController quantityController = TextEditingController(text: "1");
    
    // Varsayılan Birim (Otomatik Algıla)
    String selectedUnit = "adet";
    if (lowerName.contains("kıyma") || lowerName.contains("tavuk") || lowerName.contains("et")) {
      selectedUnit = "kg"; // Et ürünleri genelde kg olur
      quantityController.text = "0.5"; // Yarım kilo varsayılan
    } else if (lowerName.contains("süt") || lowerName.contains("su")) {
      selectedUnit = "lt";
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder( // Dropdown değişimi için StatefulBuilder şart
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("Kilere Ekle: $cleanName"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: "Miktar"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: selectedUnit,
                      items: ["adet", "kg", "gr", "lt", "ml", "paket"]
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedUnit = val);
                      },
                    )
                  ],
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Son Kullanma Tarihi"),
                  subtitle: Text(DateFormat('dd.MM.yyyy').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx); 
                  
                  final newItem = PantryItem(
                    id: '', 
                    userId: user.uid,
                    ingredientId: 'shop_${DateTime.now().millisecondsSinceEpoch}',
                    ingredientName: cleanName, // Temiz isim
                    quantity: double.tryParse(quantityController.text.replaceAll(',', '.')) ?? 1.0,
                    unit: selectedUnit, // Seçilen birim
                    expirationDate: selectedDate,
                    createdAt: Timestamp.now(),
                    brand: '', 
                    marketName: bestMarket,
                    price: bestPrice, 
                    category: estimatedCategory, // Tahmini kategori
                    pieceCount: 1,
                  );

                  await _pantryService.addPantryItem(newItem);
                  await _service.deleteItem(item['id']);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("$cleanName kilere taşındı!"), backgroundColor: Colors.green),
                    );
                  }
                },
                child: const Text("Kaydet ve Taşı"),
              )
            ],
          );
        }
      ),
    );
  }

  // --- YENİ FONKSİYON: TOPLU SİLME ONAYI ---
  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Listeyi Temizle?"),
        content: const Text("Alışveriş listesindeki TÜM ürünler silinecek. Bu işlem geri alınamaz."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.deleteAllItems();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Liste temizlendi.")),
                );
              }
            },
            child: const Text("Evet, Hepsini Sil"),
          )
        ],
      ),
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
            padding: EdgeInsets.only(bottom: 80.0 + MediaQuery.of(context).padding.bottom),
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
                    Row(
                      children: [
                        // TAMAMLANANLARI SİL (Eski Buton)
                        if (hasCompletedItems)
                          IconButton(
                            icon: const Icon(Icons.playlist_remove, color: Colors.orange),
                            tooltip: "Tamamlananları Sil",
                            onPressed: () async {
                              await _service.clearCompleted();
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tamamlananlar silindi.")));
                            },
                          ),
                        
                        // TÜMÜNÜ SİL (YENİ BUTON)
                        if (items.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.delete_forever, color: Colors.red),
                            tooltip: "Listeyi Komple Temizle",
                            onPressed: _confirmDeleteAll,
                          ),
                      ],
                    )
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
                        padding: EdgeInsets.only(bottom: 100 + MediaQuery.of(context).padding.bottom),
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
                                    // 1. SATIR
                                    Row(
                                      children: [
                                        Transform.scale(
                                          scale: 1.2,
                                          child: Checkbox(
                                            value: isCompleted,
                                            activeColor: colorScheme.primary,
                                            shape: const CircleBorder(),
                                            onChanged: (val) => _service.toggleStatus(id, isCompleted),
                                          ),
                                        ),
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
                                        
                                        // --- KİLERE EKLEME BUTONU (YENİ) ---
                                        IconButton(
                                          icon: const Icon(Icons.kitchen, color: Colors.green),
                                          tooltip: "Kilere Taşı",
                                          onPressed: () => _moveItemToPantry(item),
                                        ),
                                      ],
                                    ),
                                    
                                    // 2. SATIR: MARKETLER
                                    if (!isCompleted && markets.isNotEmpty) ...[
                                      const Divider(height: 16),
                                      SizedBox(
                                        height: 36,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: markets.length,
                                          itemBuilder: (context, mIndex) {
                                            final m = markets[mIndex];
                                            final String mName = m['marketName'] ?? '';
                                            final double price = (m['price'] as num?)?.toDouble() ?? 0.0;
                                            final String logoPath = MarketUtils.getLogoPath(mName);
                                            final bool isCheapest = mIndex == 0; 

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
                                                    if (logoPath.isNotEmpty)
                                                      Image.asset(logoPath, height: 16, width: 40, fit: BoxFit.contain)
                                                    else
                                                      const Icon(Icons.store, size: 16, color: Colors.grey),
                                                    const SizedBox(width: 4),
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

// ... ProductSearchSheet Sınıfı Değişmedi (Aynı Kalabilir) ...
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
  final List<Map<String, dynamic>> _pendingItems = [];
  bool _isSearching = false;
  Timer? _debounce;

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

    try {
      final allPrices = await _marketService.getAllPrices(); 
      final searchKey = _normalizeForSmartSearch(query);

      final filtered = allPrices.where((marketItem) {
        final normalizedItemTitle = _normalizeForSmartSearch(marketItem.title); 
        return normalizedItemTitle.contains(searchKey);
      }).toList();

      final uniqueResults = <String, Map<String, dynamic>>{};
      
      for (var product in filtered) {
        final title = product.title;
        if (!uniqueResults.containsKey(title)) {
          final marketList = product.markets.map((m) => {
            'marketName': m.marketName,
            'price': m.price,
            'unitPriceText': m.unitPriceText
          }).toList();

          double minPrice = 0;
          if (marketList.isNotEmpty) {
             final prices = marketList.map((m) => (m['price'] as num).toDouble()).toList();
             prices.sort();
             minPrice = prices.first;
          }

          uniqueResults[title] = {
            'title': title,
            'imageUrl': product.imageUrl,
            'markets': marketList, 
            'price': minPrice,
          };
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = uniqueResults.values.toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint("Arama Hatası: $e");
      if(mounted) setState(() => _isSearching = false);
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

  void _commitItems() async {
    int count = 0;
    for (var item in _pendingItems) {
      bool added = await _shoppingService.addItem(
        name: item['title'], 
        imageUrl: item['imageUrl'],
        markets: item['markets']
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
              // autofocus: false yapalım, bazen klavye açılırken sorun çıkarabiliyor
              autofocus: false, 
              
              // Standart metin girişi
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
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
                      double minPrice = item['price'] ?? 0.0;

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