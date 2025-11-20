// lib/features/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Tarih formatı için

import '../pantry/add_pantry_item_screen.dart';
import '../pantry/pantry_service.dart';
import '../../core/models/pantry_item.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Tarihe göre renk belirleme (Bozulmaya yakınsa kırmızı)
  Color _getExpirationColor(DateTime? expirationDate) {
    if (expirationDate == null) return Colors.green;
    
    final difference = expirationDate.difference(DateTime.now()).inDays;
    
    if (difference < 0) return Colors.red; // Tarihi geçmiş
    if (difference <= 2) return Colors.orange; // 2 gün kalmış
    return Colors.green; // Sorun yok
  }

  @override
  Widget build(BuildContext context) {
    final pantryService = PantryService();

    return Scaffold(
      // Artık Çıkış Yap veya Şef butonu yok, çünkü onlar Alt Menü'de.
      appBar: AppBar(
        title: const Text("Sanal Kilerim"),
        centerTitle: true, // Başlığı ortala
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Geri butonunu gizle (Gerekirse)
      ),
      // GÖVDE: Veritabanından Gelen Verileri Dinliyoruz
      body: StreamBuilder<List<PantryItem>>(
        stream: pantryService.getPantryItems(),
        builder: (context, snapshot) {
          // 1. Hata varsa göster
          if (snapshot.hasError) {
            return Center(child: Text("Hata oluştu: ${snapshot.error}"));
          }

          // 2. Veri yükleniyorsa dönen çember göster
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? [];

          // 3. Liste boşsa uyarı göster
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.kitchen, size: 100, color: Colors.grey),
                  const SizedBox(height: 20),
                  Text(
                    "Sanal Kilerin Boş",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Text("Sağ alttaki butona basarak ürün ekle."),
                ],
              ),
            );
          }

          // 4. Doluysa listeyi göster
          return ListView.builder(
            itemCount: items.length,
            padding: const EdgeInsets.only(bottom: 80), // Butonun altında kalmasın diye boşluk
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
                  title: Text(
                    item.ingredientName, 
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Miktar: ${item.quantity} ${item.unit}"),
                      if (item.expirationDate != null)
                        Text(
                          "SKT: ${DateFormat('dd/MM/yyyy').format(item.expirationDate!)}",
                          style: TextStyle(
                            color: expirationColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12
                          ),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      // Silme işlemi
                      pantryService.deletePantryItem(item.id);
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
      ),
      // Sağ Alttaki Yuvarlak Ekleme Butonu (Bu burada kalmalı)
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        onPressed: () {
          // Ürün ekleme sayfasına git
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddPantryItemScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}