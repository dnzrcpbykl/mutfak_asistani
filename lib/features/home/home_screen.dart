import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../pantry/add_pantry_item_screen.dart';
import '../pantry/pantry_service.dart';
import '../../core/models/pantry_item.dart';
import '../shopping_list/shopping_list_view.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/widgets/empty_state_widget.dart';
// --- REKLAM IMPORTLARI ---
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/utils/ad_service.dart';

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
  final AdService _adService = AdService(); // REKLAM SERVİSİ
  late Stream<List<PantryItem>> _pantryStream;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // --- GÜNCELLENEN KATEGORİ LİSTESİ (VERİTABANI İLE BİREBİR) ---
  final List<String> _categories = [
    "Tümü", 
    "Meyve ve Sebze", 
    "Et, Tavuk ve Balık", 
    "Süt Ürünleri ve Kahvaltılık",
    "Temel Gıda", 
    "İçecek", 
    "Atıştırmalık ve Tatlı", 
    "Temizlik ve Kişisel Bakım Ürünleri",
    "Diğer"
  ];

  // Reklamları tutacak liste (Cache)
  final Map<int, BannerAd> _inlineAds = {};

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
    // Reklamları temizle
    for (var ad in _inlineAds.values) {
      ad.dispose();
    }
    super.dispose();
  }

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

  // --- GÜNCELLENEN KATEGORİ EŞLEŞTİRİCİ (GENİŞLETİLMİŞ VERSİYON) ---
  String _normalizeCategory(String text) {
    final cat = text.toLowerCase();

    // 1. Et & Balık
    if (cat.contains("et") || cat.contains("tavuk") || cat.contains("balık") || 
        cat.contains("şarküteri") || cat.contains("salam") || cat.contains("sosis") || 
        cat.contains("sucuk") || cat.contains("kıyma") || cat.contains("köfte") ||
        cat.contains("kasap") || cat.contains("bonfile") || cat.contains("kuşbaşı")) {
      return "Et, Tavuk ve Balık";
    }

    // 2. Süt & Kahvaltılık (Bal, Reçel, Zeytin eklendi)
    if (cat.contains("süt") || cat.contains("peynir") || cat.contains("yoğurt") || 
        cat.contains("kahvaltı") || cat.contains("yumurta") || cat.contains("tereyağ") ||
        cat.contains("margarin") || cat.contains("kaymak") || cat.contains("zeytin") ||
        cat.contains("bal") || cat.contains("reçel") || cat.contains("helva") ||
        cat.contains("tahin") || cat.contains("pekmez") || cat.contains("labne")) {
      return "Süt Ürünleri ve Kahvaltılık";
    }

    // 3. Meyve & Sebze
    if (cat.contains("meyve") || cat.contains("sebze") || cat.contains("yeşillik") || 
        cat.contains("patates") || cat.contains("soğan") || cat.contains("sarımsak") ||
        cat.contains("limon") || cat.contains("domates") || cat.contains("biber")) {
      return "Meyve ve Sebze";
    }

    // 4. Temel Gıda (Mantı, Ekmek, Hamur, Konserve eklendi)
    if (cat.contains("bakliyat") || cat.contains("makarna") || cat.contains("un") || 
        cat.contains("yağ") || cat.contains("baharat") || cat.contains("sos") || 
        cat.contains("temel") || cat.contains("pirinç") || cat.contains("bulgur") ||
        cat.contains("salça") || cat.contains("şeker") || cat.contains("tuz") ||
        // YENİ EKLENENLER:
        cat.contains("ekmek") || cat.contains("mantı") || cat.contains("yufka") ||
        cat.contains("hamur") || cat.contains("maya") || cat.contains("galeta") ||
        cat.contains("sirke") || cat.contains("konserve") || cat.contains("turşu") ||
        cat.contains("bulyon") || cat.contains("irmik")) {
      return "Temel Gıda";
    }

    // 5. İçecek
    if (cat.contains("içecek") || cat.contains("su") || cat.contains("kahve") || 
        cat.contains("çay") || cat.contains("kola") || cat.contains("gazoz") || 
        cat.contains("meyve suyu") || cat.contains("soda") || cat.contains("ayran") ||
        cat.contains("kefir") || cat.contains("şalgam")) {
      return "İçecek";
    }

    // 6. Atıştırmalık (Pizza, Hamburger, Dondurma eklendi)
    if (cat.contains("atıştırmalık") || cat.contains("çikolata") || cat.contains("bisküvi") || 
        cat.contains("cips") || cat.contains("tatlı") || cat.contains("kek") || 
        cat.contains("gofret") || cat.contains("kuruyemiş") || 
        // YENİ EKLENENLER:
        cat.contains("pizza") || cat.contains("hamburger") || cat.contains("dondurma") ||
        cat.contains("nugget") || cat.contains("şnitzel") || cat.contains("tost") ||
        cat.contains("gevrek") || cat.contains("kraker") || cat.contains("bar")) {
      return "Atıştırmalık ve Tatlı";
    }

    // 7. Temizlik
    if (cat.contains("temizlik") || cat.contains("bakım") || cat.contains("deterjan") || 
        cat.contains("kağıt") || cat.contains("kozmetik") || cat.contains("şampuan") || 
        cat.contains("sabun") || cat.contains("diş") || cat.contains("bezi") ||
        cat.contains("jel") || cat.contains("süngeri")) {
      return "Temizlik ve Kişisel Bakım Ürünleri";
    }

    // Listede varsa olduğu gibi döndür (Veritabanı kategori ismi ise)
    if (_categories.contains(text)) return text;
    
    return "Diğer";
  }
  
  // --- İKON EŞLEŞTİRME (YENİ İSİMLERE GÖRE) ---
  String _getCategoryImagePath(String category) {
    switch (category) {
      case "Meyve ve Sebze": return 'assets/categories/meyve_sebze.png';
      case "Et, Tavuk ve Balık": return 'assets/categories/et_balik.png';
      case "Süt Ürünleri ve Kahvaltılık": return 'assets/categories/sut_kahvalti.png';
      case "Temel Gıda": return 'assets/categories/temel_gida.png';
      case "İçecek": return 'assets/categories/icecek.png';
      case "Atıştırmalık ve Tatlı": return 'assets/categories/atistirmalik.png';
      case "Temizlik ve Kişisel Bakım Ürünleri": return 'assets/categories/temizlik.png';
      default: return 'assets/categories/diger.png';
    }
  }

  String _formatQuantity(double quantity) {
    if (quantity % 1 == 0) return quantity.toInt().toString();
    return quantity.toStringAsFixed(2);
  }

  // --- REKLAM WIDGET ÜRETİCİ ---
  Widget _getAdWidget(int adIndex) {
    // Eğer bu index için daha önce reklam yüklenmediyse yükle
    if (!_inlineAds.containsKey(adIndex)) {
      final ad = _adService.createInlineAd(
        onAdLoaded: () {
          if (mounted) setState(() {}); // Reklam gelince ekranı yenile
        }
      );
      ad.load();
      _inlineAds[adIndex] = ad;
    }

    final ad = _inlineAds[adIndex]!;
    
    // Reklam kartı tasarımı
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      height: 270, // Medium Rectangle + Padding boyutu
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))]
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text("Sponsorlu Öneri", style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1)),
          ),
          SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        ],
      ),
    );
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
                      if (isIncrement) {
                        newPieceCount++;
                      } else {
                        newPieceCount--;
                      }
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
    final pieceCountController = TextEditingController(text: item.pieceCount.toString());
    
    // 1. Standart Birim Listesi
    final List<String> unitList = [
      'adet', 'kg', 'gr', 'lt', 'ml', 'paket', 'kutu', 'kavanoz', 'bardak', 'demet', 'dilim'
    ];

    // 2. Seçili Birim Mantığı
    // Eğer kullanıcının mevcut birimi listede yoksa (eski kayıtlar), listeye geçici olarak ekle ki hata vermesin.
    String selectedUnit = item.unit;
    if (!unitList.contains(selectedUnit)) {
      unitList.add(selectedUnit); 
    }

    DateTime? tempDate = item.expirationDate;
    
    // Normalize edilmiş kategori ile başlat
    String selectedCategory = _normalizeCategory(item.category);
    if (!_categories.contains(selectedCategory)) selectedCategory = "Diğer";

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
                  
                  // --- MİKTAR ve BİRİM SATIRI (GÜNCELLENDİ) ---
                  Row(
                    children: [
                      Expanded(
                        flex: 2, // Miktar alanı biraz daha geniş olsun
                        child: TextField(
                          controller: quantityController, 
                          keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                          decoration: const InputDecoration(
                            labelText: "TOPLAM Miktar", 
                            hintText: "Örn: 1.5",
                          )
                        )
                      ),
                      const SizedBox(width: 10),
                      
                      // BİRİM SEÇİMİ (DROPDOWN)
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedUnit,
                          decoration: const InputDecoration(
                            labelText: "Birim", // Parantez içini sildik
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                            border: OutlineInputBorder(),
                          ),
                          items: unitList.map((String unit) {
                            return DropdownMenuItem(
                              value: unit, 
                              child: Text(unit, style: const TextStyle(fontSize: 14))
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedUnit = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  // ---------------------------------------------

                  const SizedBox(height: 10),
                  
                  TextField(
                    controller: pieceCountController, 
                    keyboardType: TextInputType.number, 
                    decoration: const InputDecoration(
                      labelText: "Paket Sayısı (Opsiyonel)",
                      helperText: "Bu ürün kaç parça/paket?",
                      hintText: "1"
                    )
                  ),
                  const SizedBox(height: 10),
                  
                  // KATEGORİ SEÇİMİ
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(labelText: "Kategori"),
                    items: _categories.where((c) => c != "Tümü").map((String category) {
                      return DropdownMenuItem(value: category, child: Text(category, style: const TextStyle(fontSize: 14)));
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedCategory = val ?? "Diğer"),
                    isExpanded: true, 
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
                  final newPiece = int.tryParse(pieceCountController.text) ?? 1; 

                  if (newName.isNotEmpty && newQty > 0) {
                    await _pantryService.updatePantryItemDetails(
                      itemId: item.id,
                      name: newName,
                      quantity: newQty,
                      unit: selectedUnit, // TextController yerine değişkenden alıyoruz
                      expirationDate: tempDate,
                      category: selectedCategory, 
                      pieceCount: newPiece, 
                    );
                    if (mounted) {
                      // ignore: use_build_context_synchronously
                      Navigator.pop(context);
                    }
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
    super.build(context); // KeepAlive
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
                  hintText: "Kilerde ara...",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); FocusScope.of(context).unfocus(); }) 
                    : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withAlpha((0.05 * 255).round()) : Colors.grey.shade200,
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
      // DÜZELTME: Miktarı 0 olanları listede gösterme
      if (item.quantity <= 0.001) return false;

      // Eğer kategori 'Diğer' ise veya bilinmiyorsa, ürün ismini kontrol et!
      String itemCategory = item.category;
      if (itemCategory == 'Diğer' || itemCategory == 'Genel' || itemCategory.isEmpty) {
        itemCategory = item.ingredientName; 
      }
      
      final normalizedCat = _normalizeCategory(itemCategory);
      final matchesCategory = category == "Tümü" ? true : normalizedCat == category;
      final matchesSearch = _searchQuery.isEmpty ? true : item.ingredientName.toLowerCase().replaceAll('ı', 'i').contains(_searchQuery.replaceAll('ı', 'i'));
      
      return matchesCategory && matchesSearch;
    }).toList();

    if (filteredItems.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return const EmptyStateWidget(icon: Icons.search_off, message: "Sonuç Bulunamadı", subMessage: "Farklı bir kelime deneyebilirsin.");
      }
      return EmptyStateWidget(icon: Icons.kitchen, message: "$category Rafı Boş", subMessage: "Sağ alttaki (+) butonuyla ürün ekleyebilirsin.");
    }

    // --- REKLAMLI LİSTE YAPISI (GÜNCELLENMİŞ) ---
    // Toplam eleman sayısını hesapla: Ürünler + Reklamlar
    int totalCount = filteredItems.length;
    if (filteredItems.length > 4) totalCount++; // 1. Reklam için yer aç
    if (filteredItems.length > 12) totalCount++; // 2. Reklam için yer aç

    return ListView.builder(
      itemCount: totalCount,
      padding: EdgeInsets.only(bottom: 80 + MediaQuery.of(context).padding.bottom, top: 10),
      itemBuilder: (context, index) {
        
        // --- 1. REKLAM YERLEŞİMİ (4. üründen sonra, yani index 4) ---
        if (index == 4 && filteredItems.length > 4) {
           return _getAdWidget(0); // Reklam ID 0
        }

        // --- 2. REKLAM YERLEŞİMİ (1. reklamdan yaklaşık 8 ürün sonra, yani index 13) ---
        // (4 ürün + 1 reklam + 8 ürün = 13. index)
        if (index == 13 && filteredItems.length > 12) {
           return _getAdWidget(1); // Reklam ID 1
        }

        // --- GERÇEK ÜRÜN İNDEKSİNİ HESAPLA ---
        // Araya giren reklamları indeksten çıkararak doğru ürünü buluyoruz.
        int itemIndex = index;
        if (index > 4) itemIndex--; // 1. reklamı atla
        if (index > 13) itemIndex--; // 2. reklamı atla

        // Güvenlik: Liste sınırını aşarsa boş dön
        if (itemIndex >= filteredItems.length) return const SizedBox.shrink();

        final item = filteredItems[itemIndex];
        return _buildPantryItemTile(item, Theme.of(context).colorScheme)
            .animate(delay: (itemIndex * 50).ms).slideY(begin: 0.2, end: 0).fadeIn();
      },
    );
  }

  Widget _buildPantryItemTile(PantryItem item, ColorScheme colorScheme) {
    final expirationColor = _getExpirationColor(item.expirationDate);
    String quantityText = "";
    if (item.pieceCount > 1) {
      quantityText = "${item.pieceCount} Paket (Top: ${_formatQuantity(item.quantity)} ${item.unit})";
    } else {
      quantityText = "${_formatQuantity(item.quantity)} ${item.unit}";
    }

    // Kategori resim yolunu al
    final categoryImagePath = _getCategoryImagePath(_normalizeCategory(
      (item.category == 'Diğer' || item.category == 'Genel') 
          ? item.ingredientName 
          : item.category
    ));

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
                border: Border.all(color: expirationColor.withAlpha((0.5 * 255).round())),
                color: expirationColor.withAlpha((0.1 * 255).round()),
              ),
              // Icon yerine Image.asset kullanıyoruz
              child: Image.asset(
                categoryImagePath,
                width: 24, // Icon'un size parametresiyle aynı
                height: 24,
                fit: BoxFit.contain,
                // Eğer resim yüklenemezse (dosya yoksa) hata vermesin diye bir fallback (yedek) ikon koyabiliriz
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.category, color: expirationColor, size: 24);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.ingredientName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: colorScheme.onSurface)),
                  if (item.brand != null && 
                      item.brand!.isNotEmpty && 
                      !['diger', 'diğer', 'bilinmiyor', 'markasız'].contains(item.brand!.toLowerCase()))
                    Text(item.brand!, style: TextStyle(color: colorScheme.onSurface.withAlpha((0.6 * 255).round()), fontSize: 12)),
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
                    decoration: BoxDecoration(color: expirationColor.withAlpha((0.1 * 255).round()), borderRadius: BorderRadius.circular(6), border: Border.all(color: expirationColor.withAlpha((0.3 * 255).round()))),
                    child: Text(DateFormat('dd/MM').format(item.expirationDate!), style: TextStyle(color: expirationColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(onTap: () => _showEditDialog(item), borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.blue.withAlpha((0.1 * 255).round()), shape: BoxShape.circle), child: const Icon(Icons.edit, size: 18, color: Colors.blue))),
                    const SizedBox(width: 8),
                    InkWell(onTap: () => _showQuantityDialog(item, false), borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.orange.withAlpha((0.1 * 255).round()), shape: BoxShape.circle), child: const Icon(Icons.remove, size: 18, color: Colors.orange))),
                    const SizedBox(width: 8),
                    InkWell(onTap: () => _showQuantityDialog(item, true), borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.green.withAlpha((0.1 * 255).round()), shape: BoxShape.circle), child: const Icon(Icons.add, size: 18, color: Colors.green))),
                    const SizedBox(width: 8),
                    InkWell(onTap: () => _pantryService.deletePantryItem(item.id), borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.red.withAlpha((0.1 * 255).round()), shape: BoxShape.circle), child: const Icon(Icons.delete_outline, size: 18, color: Colors.red))),
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