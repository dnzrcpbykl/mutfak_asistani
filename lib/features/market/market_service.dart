import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/market_price.dart';

class MarketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Tüm market fiyatlarını getirir
  Future<List<MarketPrice>> getAllPrices() async {
    try {
      final snapshot = await _firestore.collection('market_prices').get();
      // Güvenli veri okuma (Boş veya hatalı veri varsa atlar)
      return snapshot.docs.map((doc) {
        try {
          return MarketPrice.fromFirestore(doc);
        } catch (e) {
          return null;
        }
      }).whereType<MarketPrice>().toList();
    } catch (e) {
      debugPrint("Fiyat çekme hatası: $e");
      return [];
    }
  }

  // --- 1. FİYAT KAYDETME ---
  Future<void> addPriceInfo(String ingredientName, String marketName, double price, DateTime receiptDate) async {
    final normalizedName = _normalizeForSearch(ingredientName);
    
    final query = await _firestore.collection('market_prices')
        .where('ingredientName', isEqualTo: ingredientName)
        .where('marketName', isEqualTo: marketName)
        .get();

    final newData = {
      'ingredientName': ingredientName,
      'normalizedTitle': normalizedName,
      'marketName': marketName,
      'price': price,
      'updatedAt': Timestamp.fromDate(receiptDate),
      'source': 'user_scan',
    };

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final currentData = (doc.data() as Map<String, dynamic>?) ?? {};
      final Timestamp? dbTs = currentData['updatedAt'];
      final DateTime dbDate = dbTs?.toDate() ?? DateTime(2000);

      if (receiptDate.isAfter(dbDate)) {
        await doc.reference.update(newData);
      }
    } else {
      await _firestore.collection('market_prices').add(newData);
    }
  }

  // --- 2. EKSİK MALİYET HESAPLAMA (HATAYI ÇÖZEN KISIM) ---
  // Eksik malzemelerin (missingIngredients) en uygun fiyatlarını bulup toplar.
  double calculateMissingCost(List<String> missingIngredients, List<MarketPrice> allPrices) {
    double totalCost = 0;

    for (var item in missingIngredients) {
      // Bu ürün için tüm fiyatları bul (Akıllı arama ile)
      List<Map<String, dynamic>> prices = findAllPricesFor(item, allPrices);
      
      if (prices.isNotEmpty) {
        // Zaten findAllPricesFor fonksiyonu en ucuzu en başa koyuyor.
        // İlk sıradaki (en ucuz) fiyatı toplama ekle.
        totalCost += (prices.first['price'] as num).toDouble();
      }
    }
    
    return totalCost;
  }

  // --- 3. AKILLI ÜRÜN ARAMA (SEARCH BAR İÇİN) ---
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    if (query.length < 2) return [];

    final searchKey = _normalizeForSearch(query);

    try {
      final snapshot = await _firestore.collection('market_prices')
          .orderBy('ingredientName') 
          .startAt([query.toUpperCase()]) 
          .endAt(['${query.toLowerCase()}\uf8ff']) 
          .limit(100) 
          .get();

      List<Map<String, dynamic>> rawResults = [];
      
      // Veritabanından gelen verileri güvenli şekilde Map'e çevir
      rawResults = snapshot.docs.map((doc) {
        final data = (doc.data() as Map<String, dynamic>?) ?? {};
        return {
          'id': doc.id,
          'title': data['ingredientName'] ?? 'İsimsiz',
          'imageUrl': data['imageUrl'] ?? '',
          'markets': data['markets'] ?? [],
          'price': data['price'] ?? 0.0,
        };
      }).toList();

      // Akıllı Filtreleme
      final List<Map<String, dynamic>> filteredResults = [];
      for (var item in rawResults) {
        String title = _normalizeForSearch(item['title']);
        if (title.contains(searchKey)) {
          filteredResults.add(item);
        }
      }

      // Akıllı Sıralama (Puanlama)
      filteredResults.sort((a, b) {
        String titleA = _normalizeForSearch(a['title']);
        String titleB = _normalizeForSearch(b['title']);
        int scoreA = _calculateRelevance(titleA, searchKey);
        int scoreB = _calculateRelevance(titleB, searchKey);
        return scoreB.compareTo(scoreA); 
      });

      return filteredResults;
    } catch (e) {
      debugPrint("Arama Hatası: $e");
      return [];
    }
  }

  // --- 4. EŞLEŞTİRME VE FİYAT BULMA (LİSTE İÇİN) ---
  List<Map<String, dynamic>> findAllPricesFor(String listRowName, List<MarketPrice> allPrices) {
    String searchKey = _normalizeForSearch(listRowName);
    if (searchKey.isEmpty) return [];

    final matches = allPrices.where((p) {
      String dbProductName = _normalizeForSearch(p.ingredientName);
      
      // 1. Tam Eşleşme
      if (dbProductName == searchKey) return true;

      // 2. Kelime Bazlı Kapsama
      List<String> dbWords = dbProductName.split(' ');
      if (dbWords.contains(searchKey)) return true;

      // 3. Tersi
      List<String> listWords = searchKey.split(' ');
      if (listWords.contains(dbProductName)) return true;

      // 4. Alt Dize (Kısa kelimeler hariç)
      if (searchKey.length > 3 && dbProductName.contains(searchKey)) return true;

      return false;
    }).toList();

    if (matches.isEmpty) return [];

    matches.sort((a, b) => a.price.compareTo(b.price));

    final uniqueMarkets = <String>{};
    final List<Map<String, dynamic>> uniqueResults = [];

    for (var m in matches) {
      if (!uniqueMarkets.contains(m.marketName)) {
        uniqueMarkets.add(m.marketName);
        uniqueResults.add({
          'market': m.marketName,
          'price': m.price,
        });
      }
    }

    return uniqueResults;
  }

  // --- YARDIMCILAR ---

  int _calculateRelevance(String text, String query) {
    int score = 0;
    if (text == query) score += 100;
    List<String> words = text.split(' ');
    if (words.contains(query)) score += 50;
    if (text.startsWith(query)) score += 20;
    if (text.contains(query)) score += 10;
    return score;
  }

  String _normalizeForSearch(String text) {
    if (text.isEmpty) return "";
    return text
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .trim();
  }
}