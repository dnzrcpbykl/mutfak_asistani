import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../pantry/add_pantry_item_screen.dart';
import '../pantry/pantry_service.dart';
import '../../core/models/pantry_item.dart';
import '../shopping_list/shopping_list_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _mainTabController; // Ana (Alt) Tab: Kiler / Alışveriş
  final PantryService _pantryService = PantryService();

  // Kategorilerin Sabit Sıralaması
  final List<String> _categories = [
    "Tümü", 
    "Meyve & Sebze",
    "Et & Tavuk & Balık",
    "Süt & Kahvaltılık",
    "Temel Gıda & Bakliyat",
    "Atıştırmalık",
    "İçecekler",
    // "Temizlik & Bakım", <--- SİLİNDİ
    "Diğer"
  ];

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    // Ekrani yenilemek için listener
    _mainTabController.addListener(() { setState(() {}); });
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    super.dispose();
  }

  Color _getExpirationColor(DateTime? expirationDate) {
    if (expirationDate == null) return AppTheme.neonCyan; 
    
    // Saatleri sıfırlayarak sadece günleri karşılaştır (Safe Comparison)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expirationDate.year, expirationDate.month, expirationDate.day);
    
    final difference = exp.difference(today).inDays;

    if (difference < 0) return const Color(0xFFFF5252); // Tarihi Geçmiş (Kırmızı)
    if (difference <= 2) return const Color(0xFFFFAB40); // 0, 1, 2 gün kalmış (Turuncu)
    
    return const Color(0xFF69F0AE); // Güvenli (Yeşil)
  }

  // AI'dan gelen kategoriyi bizim listeye uydurma
 String _normalizeCategory(String aiCategory) {
    // Temizlik kontrolünü kaldırıyoruz, gelse bile 'Diğer'e düşsün (ki gelmemeli)
    if (aiCategory.contains("Sebze") || aiCategory.contains("Meyve")) return "Meyve & Sebze";
    if (aiCategory.contains("Et") || aiCategory.contains("Tavuk") || aiCategory.contains("Balık")) return "Et & Tavuk & Balık";
    if (aiCategory.contains("Süt") || aiCategory.contains("Peynir") || aiCategory.contains("Yoğurt") || aiCategory.contains("Kahvaltılık")) return "Süt & Kahvaltılık";
    if (aiCategory.contains("Bakliyat") || aiCategory.contains("Yağ") || aiCategory.contains("Makarna") || aiCategory.contains("Temel")) return "Temel Gıda & Bakliyat";
    if (aiCategory.contains("İçecek")) return "İçecekler";
    if (aiCategory.contains("Atıştırmalık") || aiCategory.contains("Çikolata")) return "Atıştırmalık";
    
    if (_categories.contains(aiCategory)) return aiCategory;
    return "Diğer";
  }
  
  // İkon Bulucuyu da temizleyelim
  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains("meyve") || cat.contains("sebze")) return Icons.eco;
    if (cat.contains("et") || cat.contains("tavuk") || cat.contains("balık")) return Icons.kebab_dining;
    if (cat.contains("süt") || cat.contains("kahvaltı") || cat.contains("peynir")) return Icons.egg_alt;
    if (cat.contains("bakliyat") || cat.contains("makarna") || cat.contains("un")) return Icons.grain;
    if (cat.contains("atıştırmalık") || cat.contains("çikolata")) return Icons.cookie;
    if (cat.contains("içecek") || cat.contains("su")) return Icons.local_drink;
    // Temizlik ikonu kaldırıldı
    return Icons.category; 
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
        children: [
          // 1. KİLER GÖRÜNÜMÜ (Artık İçinde Kategori Tabları Var)
          _buildNestedPantryView(),
          
          // 2. ALIŞVERİŞ LİSTESİ
          const ShoppingListView(),
        ],
      ),

      floatingActionButton: _mainTabController.index == 0
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
          : null, 
    );
  }

  Widget _buildNestedPantryView() {
    final colorScheme = Theme.of(context).colorScheme;

    // StreamBuilder en dışta duruyor, veriyi bir kere çekip alt sekmelere dağıtacağız
    return StreamBuilder<List<PantryItem>>(
      stream: _pantryService.getPantryItems(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allItems = snapshot.data ?? [];

        // İç İçe Tab Yapısı (Kategoriler İçin)
        return DefaultTabController(
          length: _categories.length,
          child: Column(
            children: [
              // --- KATEGORİ SEKMELERİ (YATAY KAYDIRILABİLİR) ---
              Container(
                color: Theme.of(context).scaffoldBackgroundColor, // Arka plan rengi
                child: TabBar(
                  isScrollable: true, // Sağa sola kaydırma özelliği
                  tabAlignment: TabAlignment.start, // Sola yasla
                  indicatorColor: colorScheme.primary,
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tabs: _categories.map((category) => Tab(text: category)).toList(),
                ),
              ),
              
              // --- İÇERİK ALANI ---
              Expanded(
                child: TabBarView(
                  children: _categories.map((category) {
                    // Her sekme için listeyi filtrele
                    return _buildCategoryList(category, allItems);
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Filtrelenmiş Liste Oluşturucu
  Widget _buildCategoryList(String category, List<PantryItem> allItems) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Filtreleme Mantığı
    final filteredItems = category == "Tümü" 
        ? allItems 
        : allItems.where((item) => _normalizeCategory(item.category) == category).toList();

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.layers_clear, size: 60, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 10),
            Text(
              "$category kategorisi boş.", 
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredItems.length,
      padding: const EdgeInsets.only(bottom: 80, top: 10),
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return _buildPantryItemTile(item, colorScheme);
      },
    );
  }

  // Tekil Ürün Kartı Tasarımı
  Widget _buildPantryItemTile(PantryItem item, ColorScheme colorScheme) {
    final expirationColor = _getExpirationColor(item.expirationDate);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: expirationColor.withOpacity(0.5)),
            color: expirationColor.withOpacity(0.1),
          ),
          child: Icon(_getCategoryIcon(item.category), color: expirationColor, size: 20),
        ),
        title: Text(
          item.ingredientName, 
          style: TextStyle(fontWeight: FontWeight.w500, color: colorScheme.onSurface)
        ),
        subtitle: Row(
          children: [
            if (item.brand != null)
              Text("${item.brand} • ", style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
            Text(
              "${item.quantity} ${item.unit}", 
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.expirationDate != null)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: expirationColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: expirationColor.withOpacity(0.3))
                ),
                child: Text(
                  DateFormat('dd/MM').format(item.expirationDate!),
                  style: TextStyle(color: expirationColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              onPressed: () {
                _pantryService.deletePantryItem(item.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}