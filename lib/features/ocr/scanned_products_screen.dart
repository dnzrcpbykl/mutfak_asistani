import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/pantry_item.dart';
import '../pantry/pantry_service.dart';
import '../market/market_service.dart';

class ScannedProductsScreen extends StatefulWidget {
  final Map<String, dynamic> scannedData; 

  const ScannedProductsScreen({super.key, required this.scannedData});

  @override
  State<ScannedProductsScreen> createState() => _ScannedProductsScreenState();
}

class _ScannedProductsScreenState extends State<ScannedProductsScreen> {
  final PantryService _pantryService = PantryService();
  final MarketService _marketService = MarketService();
  
  late List<Map<String, dynamic>> _items;
  late String _marketName;
  late List<bool> _selectedItems;
  late List<DateTime> _expirationDates;
  late DateTime _receiptDate; // EKLENDİ: Fiş Tarihi

  @override
  void initState() {
    super.initState();
    List<dynamic> rawItems = widget.scannedData['items'] ?? [];
    _marketName = widget.scannedData['market_name'] ?? 'Bilinmiyor';
    
    // EKLENDİ: OCR sonucundan tarihi çek, yoksa şu anı al
    String dateStr = widget.scannedData['date'] ?? DateTime.now().toIso8601String();
    // tryParse hata verirse (null dönerse) bugünü kullan
    _receiptDate = DateTime.tryParse(dateStr) ?? DateTime.now();

    // Artık karmaşık parse işlemlerine gerek yok, AI temiz veri veriyor.
    // Sadece aynı ürünleri (İsimleri aynı olanları) birleştiriyoruz.
    _items = _mergeItemsSimple(rawItems);

    _selectedItems = List.generate(_items.length, (index) => true);
    _expirationDates = _items.map((item) {
      int days = item['days_to_expire'] ?? 7;
      return DateTime.now().add(Duration(days: days));
    }).toList();
  }

  // --- MASTER SEVİYE BİRLEŞTİRME VE TEMİZLEME ---
  List<Map<String, dynamic>> _mergeItemsSimple(List<dynamic> rawList) {
    List<Map<String, dynamic>> mergedList = [];
    
    // YASAKLI MARKA LİSTESİ
    final List<String> ignoredBrands = ['diger', 'diğer', 'bilinmiyor', 'markasız', 'genel', 'tanımsız'];

    for (var item in rawList) {
      String rawName = (item['product_name'] ?? '').trim();
      String brand = (item['brand'] ?? '').trim();
      
      // 1. İSMİN İÇİNDEKİ MİKTARLARI TEMİZLE (Örn: "Ayçiçek Yağı 5L" -> "Ayçiçek Yağı")
      // Bu Regex; ismin sonundaki sayıları ve birimleri (5kg, 500gr, 1 lt vb.) siler.
      String name = rawName.replaceAll(RegExp(r'\s*\d+[.,]?\d*\s*(kg|lt|litre|gr|gram|ml)\s*$', caseSensitive: false), '').trim();

      // 2. Marka Temizliği
      if (ignoredBrands.contains(brand.toLowerCase())) {
        brand = ""; 
      }

      // 3. Markayı İsme Ekle (Eğer isimde zaten yoksa)
      if (brand.isNotEmpty && !name.toLowerCase().contains(brand.toLowerCase())) {
        name = "$brand $name";
      }
      
      // Baş harfleri büyüt
      name = toTitleCase(name);

      double amount = (item['amount'] as num).toDouble();
      String unit = (item['unit'] ?? 'adet').toString().toLowerCase();
      double price = (item['price'] as num?)?.toDouble() ?? 0.0;

      // LİSTEDE VAR MI? (Aynı isim ve birimle)
      int existingIndex = mergedList.indexWhere((element) => 
          element['product_name'] == name && 
          element['unit'] == unit
      );

      if (existingIndex != -1) {
        // VARSA ÜSTÜNE EKLE (Örn: 2 tane 1 Litrelik süt varsa -> 2 Litre Süt olur)
        mergedList[existingIndex]['amount'] += amount;
        mergedList[existingIndex]['price'] += price;
      } else {
        // YOKSA YENİ EKLE
        var newItem = Map<String, dynamic>.from(item);
        newItem['product_name'] = name;
        newItem['brand'] = brand;
        newItem['amount'] = amount;
        newItem['unit'] = unit;
        newItem['pieceCount'] = 1; // Artık paket sayısını değil, toplam miktarı tutuyoruz
        mergedList.add(newItem);
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

    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator())
    );

    final pantrySnapshot = await _pantryService.pantryRef.get();
    final existingPantryItems = pantrySnapshot.docs;

    int count = 0;
    for (int i = 0; i < _items.length; i++) {
      if (_selectedItems[i]) {
        final itemData = _items[i];
        String ingredientName = itemData['product_name'];
        double quantityToAdd = (itemData['amount'] as num).toDouble();
        String unit = itemData['unit'];
        double price = (itemData['price'] as num?)?.toDouble() ?? 0.0;

        // Kilerde var mı kontrol et
        DocumentSnapshot? matchingDoc;
        try {
          matchingDoc = existingPantryItems.firstWhere((doc) {
            final data = doc.data();
            return data.ingredientName.toLowerCase() == ingredientName.toLowerCase() &&
                   data.unit.toLowerCase() == unit.toLowerCase();
          });
        } catch (e) {
          matchingDoc = null;
        }

        if (matchingDoc != null) {
          final existingItem = matchingDoc.data() as PantryItem;
          await _pantryService.updatePantryItemQuantity(matchingDoc.id, existingItem.quantity + quantityToAdd);
        } else {
          final newItem = PantryItem(
            id: '',
            userId: user.uid,
            ingredientId: 'auto_ocr_${DateTime.now().millisecondsSinceEpoch}_$i',
            ingredientName: ingredientName,
            quantity: quantityToAdd,
            unit: unit, 
            expirationDate: _expirationDates[i],
            // DÜZELTME: Fiş tarihini harcama tarihi olarak işle
            createdAt: Timestamp.fromDate(_receiptDate), 
            brand: itemData['brand'],
            marketName: _marketName,
            price: price,
            category: itemData['category'] ?? 'Diğer',
            pieceCount: 1,
          );
          await _pantryService.addPantryItem(newItem);
        }

        if (price > 0) {
          // GÜNCELLEME BURADA: Fiş tarihini (_receiptDate) de gönderiyoruz
          await _marketService.addPriceInfo(ingredientName, _marketName, price, _receiptDate);
        }
        count++;
      }
    }

    if (!mounted) return;
    Navigator.pop(context); 
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$count ürün kilere eklendi!"), backgroundColor: Colors.green),
    );
  }

  String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return '';
      if (word.startsWith('(')) return word.toUpperCase(); 
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                        color: colorScheme.primary.withAlpha((0.2 * 255).round()),
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
                // EKLENDİ: Fiş Tarihini Kullanıcıya Göster (Opsiyonel ama şık durur)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 34),
                  child: Text(
                    "Fiş Tarihi: ${DateFormat('dd.MM.yyyy').format(_receiptDate)}",
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withAlpha((0.6 * 255).round())),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
                
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  color: _selectedItems[index] ? theme.cardTheme.color : theme.cardTheme.color?.withAlpha((0.5 * 255).round()),
                  child: ListTile(
                    leading: Checkbox(
                      value: _selectedItems[index],
                      activeColor: colorScheme.primary,
                      onChanged: (val) => setState(() => _selectedItems[index] = val ?? false),
                    ),
                    
                    title: Text(
                      item['product_name'],
                      style: TextStyle(fontWeight: FontWeight.bold, color: _selectedItems[index] ? colorScheme.onSurface : Colors.grey)
                    ),
                    
                    subtitle: Text(
                      "${(item['amount'] as num).toDouble() == (item['amount'] as num).toInt() ? (item['amount'] as num).toInt() : (item['amount'] as num).toString()} ${item['unit']}",
                      style: TextStyle(color: colorScheme.onSurface.withAlpha((0.6 * 255).round())),
                    ),
                    
                    trailing: SizedBox(
                      width: 90, 
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "${price.toStringAsFixed(2)} TL",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _selectedItems[index] ? colorScheme.secondary : Colors.grey),
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
                                border: Border.all(color: Colors.grey.withAlpha((0.5 * 255).round())),
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
          
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.05 * 255).round()), blurRadius: 10, offset: const Offset(0, -5))]
            ),
            child: SafeArea(
              top: false, 
              child: Padding(
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
            ),
          ),
        ],
      ),
    );
  }
}
