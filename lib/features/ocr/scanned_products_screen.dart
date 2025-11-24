import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/pantry_item.dart';
import '../pantry/pantry_service.dart';
import '../market/market_service.dart'; // <--- Market servisini ekle

class ScannedProductsScreen extends StatefulWidget {
  final Map<String, dynamic> scannedData; 

  const ScannedProductsScreen({super.key, required this.scannedData});

  @override
  State<ScannedProductsScreen> createState() => _ScannedProductsScreenState();
}

class _ScannedProductsScreenState extends State<ScannedProductsScreen> {
  final PantryService _pantryService = PantryService();
  final MarketService _marketService = MarketService(); // <--- Servisi başlat
  
  late List<Map<String, dynamic>> _items;
  late String _marketName;
  late List<bool> _selectedItems;
  late List<DateTime> _expirationDates;

  @override
  void initState() {
    super.initState();
    
    List<dynamic> rawItems = widget.scannedData['items'] ?? [];
    _marketName = widget.scannedData['market_name'] ?? 'Bilinmiyor';

    _items = _mergeItems(rawItems);

    _selectedItems = List.generate(_items.length, (index) => true);
    
    _expirationDates = _items.map((item) {
      int days = item['days_to_expire'] ?? 7;
      return DateTime.now().add(Duration(days: days));
    }).toList();
  }

  List<Map<String, dynamic>> _mergeItems(List<dynamic> rawList) {
    List<Map<String, dynamic>> mergedList = [];

    for (var item in rawList) {
      String name = item['product_name'] ?? '';
      // Birleştirirken markaya bakmaya devam edelim ki farklı markalar karışmasın
      String brand = item['brand'] ?? ''; 
      
      int existingIndex = mergedList.indexWhere((element) => 
          element['product_name'] == name && 
          (element['brand'] ?? '') == brand
      );

      if (existingIndex != -1) {
        double currentAmount = (mergedList[existingIndex]['amount'] as num).toDouble();
        double newAmount = (item['amount'] as num).toDouble();
        
        // Fiyatı güncelle (Son okunan fiyatı veya ortalamayı alabiliriz, burada sonuncuyu üzerine ekliyoruz)
        double currentPrice = (mergedList[existingIndex]['price'] as num?)?.toDouble() ?? 0.0;
        double newPrice = (item['price'] as num?)?.toDouble() ?? 0.0;

        mergedList[existingIndex]['amount'] = currentAmount + newAmount;
        mergedList[existingIndex]['price'] = currentPrice + newPrice; 
      } else {
        mergedList.add(Map<String, dynamic>.from(item));
      }
    }
    return mergedList;
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectedItems = List.generate(_items.length, (index) => value ?? false);
    });
  }

  Future<void> _saveSelectedToPantry() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    int count = 0;
    
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator())
    );

    for (int i = 0; i < _items.length; i++) {
      if (_selectedItems[i]) {
        final itemData = _items[i];
        
        // --- DÜZELTME 1: İSMİ YALIN TUTUYORUZ ---
        // Artık markayı ismin başına eklemiyoruz.
        // "Dr. Oetker Kabartma Tozu" -> "Kabartma Tozu" olarak kalıyor.
        String ingredientName = itemData['product_name']; 
        String? brand = itemData['brand'];
        double price = (itemData['price'] as num?)?.toDouble() ?? 0.0;

        // 1. KİLERE KAYDET (Kullanıcının stoğu)
        final newItem = PantryItem(
          id: '',
          userId: user.uid,
          ingredientId: 'auto_ocr_${DateTime.now().millisecondsSinceEpoch}_$i',
          ingredientName: ingredientName, // Yalın isim
          quantity: (itemData['amount'] as num).toDouble(),
          unit: itemData['unit'] ?? 'adet',
          expirationDate: _expirationDates[i],
          createdAt: Timestamp.now(),
          brand: brand, // Marka burada ayrı duruyor
          marketName: _marketName,
          price: price,
          category: itemData['category'] ?? 'Diğer',
        );

        await _pantryService.addPantryItem(newItem);

        // 2. FİYAT VERİTABANINA KAYDET (Hesaplama için)
        // "Kabartma Tozu", "MIGROS", 35.00 TL gibi
        if (price > 0) {
          await _marketService.addPriceInfo(ingredientName, _marketName, price);
        }

        count++;
      }
    }

    if (!mounted) return;
    Navigator.pop(context); 
    Navigator.pop(context); 

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$count ürün ($_marketName) kaydedildi!"), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    // UI Kodu (Build metodu) aynı kalabilir, değişiklik yok.
    // Sadece yukarıdaki _saveSelectedToPantry ve _mergeItems önemliydi.
    // ... (Önceki kodun build kısmı aynen buraya gelecek) ...
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Toplam tutarı hesapla
    double totalCost = 0;
    for (int i = 0; i < _items.length; i++) {
      if (_selectedItems[i]) {
        totalCost += (_items[i]['price'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Fiş Sonuçları"),
        actions: [
          Checkbox(
            value: _selectedItems.every((element) => element),
            activeColor: colorScheme.primary,
            onChanged: _toggleSelectAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // MARKET & FİYAT KARTI
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.store, color: colorScheme.primary),
                        const SizedBox(width: 10),
                        Text(
                          _marketName,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colorScheme.onSurface),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.primary),
                      ),
                      child: Text(
                        "${totalCost.toStringAsFixed(2)} TL",
                        style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // LİSTE
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
                
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  color: _selectedItems[index] ? theme.cardTheme.color : theme.cardTheme.color?.withOpacity(0.5),
                  child: ListTile(
                    leading: Checkbox(
                      value: _selectedItems[index],
                      activeColor: colorScheme.primary,
                      onChanged: (val) => setState(() => _selectedItems[index] = val ?? false),
                    ),
                    
                    title: Text(
                      item['product_name'], // YALIN İSİM GÖRÜNECEK
                      style: TextStyle(fontWeight: FontWeight.bold, color: _selectedItems[index] ? colorScheme.onSurface : Colors.grey)
                    ),
                    
                    subtitle: Text(
                      // Markayı burada bilgi olarak gösteriyoruz
                      "${item['brand'] ?? 'Markasız'} • ${item['amount']} ${item['unit']}",
                      style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                    ),
                    
                    trailing: SizedBox(
                      width: 100, 
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "$price TL",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _selectedItems[index] ? colorScheme.secondary : Colors.grey
                            ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: _selectedItems[index] ? () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _expirationDates[index],
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) setState(() => _expirationDates[index] = picked);
                            } : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                DateFormat('dd/MM/yy').format(_expirationDates[index]),
                                style: TextStyle(fontSize: 11, color: _selectedItems[index] ? colorScheme.onSurface : Colors.grey),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedItems.contains(true) ? _saveSelectedToPantry : null,
                icon: const Icon(Icons.save_alt),
                label: Text("Seçilenleri Kilere Ekle (${_selectedItems.where((x) => x).length})"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}