import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../pantry/add_pantry_item_screen.dart';
import '../pantry/pantry_service.dart';
import '../../core/models/pantry_item.dart';
import '../shopping_list/shopping_list_view.dart'; // Yeni listemiz

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PantryService _pantryService = PantryService();

  @override
  void initState() {
    super.initState();
    // 2 sekmeli bir kontrolcü oluşturuyoruz
    _tabController = TabController(length: 2, vsync: this);
    // Sekme değişince ekranı yenile (Butonu gizlemek/göstermek için)
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Tarihe göre renk belirleme
  Color _getExpirationColor(DateTime? expirationDate) {
    if (expirationDate == null) return Colors.green;
    final difference = expirationDate.difference(DateTime.now()).inDays;
    if (difference < 0) return Colors.red; 
    if (difference <= 2) return Colors.orange; 
    return Colors.green; 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mutfak Asistanı"),
        centerTitle: true,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        // --- TAB BAR (SEKMELER) ---
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.kitchen), text: "Kilerim"),
            Tab(icon: Icon(Icons.shopping_cart), text: "Alışveriş"),
          ],
        ),
      ),
      
      // --- GÖVDE (SAYFALAR) ---
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. SEKME: KİLER LİSTESİ (Eski kodumuz buraya taşındı)
          _buildPantryView(),
          
          // 2. SEKME: ALIŞVERİŞ LİSTESİ (Yeni widget)
          const ShoppingListView(),
        ],
      ),

      // --- EYLEM BUTONU (Sadece Kiler sekmesinde görünsün) ---
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              backgroundColor: Colors.orange,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AddPantryItemScreen()),
                );
              },
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null, // Alışveriş listesindeyken buton yok
    );
  }

  // Kiler Görünümünü buraya ayırdık (Kod temizliği için)
  Widget _buildPantryView() {
    return StreamBuilder<List<PantryItem>>(
      stream: _pantryService.getPantryItems(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.kitchen, size: 100, color: Colors.grey),
                const SizedBox(height: 20),
                Text("Sanal Kilerin Boş", style: Theme.of(context).textTheme.headlineSmall),
                const Text("Sağ alttaki butona basarak ürün ekle."),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: items.length,
          padding: const EdgeInsets.only(bottom: 80),
          itemBuilder: (context, index) {
            final item = items[index];
            final expirationColor = _getExpirationColor(item.expirationDate);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: expirationColor.withValues(alpha: 0.2),
                  child: Icon(Icons.fastfood, color: expirationColor),
                ),
                title: Text(item.ingredientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Miktar: ${item.quantity} ${item.unit}"),
                    if (item.expirationDate != null)
                      Text(
                        "SKT: ${DateFormat('dd/MM/yyyy').format(item.expirationDate!)}",
                        style: TextStyle(color: expirationColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    _pantryService.deletePantryItem(item.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Ürün silindi")),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}