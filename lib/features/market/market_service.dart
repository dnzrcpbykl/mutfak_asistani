// lib/features/market/market_service.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/market_price.dart';

class MarketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- 1. TÜM FİYATLARI GETİR ---
  Future<List<MarketPrice>> getAllPrices() async {
    try {
      final snapshot = await _firestore.collection('market_prices').get();
      return snapshot.docs.map((doc) {
        try {
          return MarketPrice.fromFirestore(doc);
        } catch (e) {
          debugPrint("Parse hatası (${doc.id}): $e");
          return null;
        }
      }).whereType<MarketPrice>().toList();
    } catch (e) {
      debugPrint("Fiyat çekme hatası: $e");
      return [];
    }
  }

  // --- 2. FİYAT KAYDETME ---
  Future<void> addPriceInfo(String ingredientName, String marketName, double price, DateTime receiptDate) async {
    final normalizedTitle = _normalizeForSearch(ingredientName);
    
    final query = await _firestore.collection('market_prices')
        .where('normalizedTitle', isEqualTo: normalizedTitle)
        .limit(1)
        .get();

    final newMarketEntry = {
      'marketName': marketName,
      'branchName': 'Fiş Taraması', 
      'price': price,
      'unitPriceText': '', 
    };

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final data = doc.data();

      Timestamp? lastUpdateTs = data['updatedAt'];
      DateTime lastUpdate = lastUpdateTs?.toDate() ?? DateTime(2000); 

      if (receiptDate.isBefore(lastUpdate)) return; 

      List<dynamic> markets = List.from(data['markets'] ?? []);
      int existingIndex = markets.indexWhere((m) => 
          (m['marketName'] ?? '').toString().toLowerCase() == marketName.toLowerCase());

      if (existingIndex != -1) {
        markets[existingIndex]['price'] = price;
      } else {
        markets.add(newMarketEntry);
      }

      await doc.reference.update({
        'markets': markets,
        'updatedAt': Timestamp.fromDate(receiptDate),
      });

    } else {
      await _firestore.collection('market_prices').add({
        'title': ingredientName, 
        'normalizedTitle': normalizedTitle,
        'category': 'Genel',
        'imageUrl': '',
        'markets': [newMarketEntry], 
        'updatedAt': Timestamp.fromDate(receiptDate),
        'source': 'user_scan',
      });
    }
  }

  // --- 3. MALİYET HESAPLAMA (GÜÇLENDİRİLMİŞ) ---
  double calculateMissingCost(List<String> missingIngredients, List<MarketPrice> allPrices) {
    double totalCost = 0;

    for (var rawIngredientName in missingIngredients) {
      // 1. Temizle
      String searchKey = _cleanIngredientName(rawIngredientName);
      
      // 2. En uygun ürünü bul (Yasaklı kelime filtresi dahil)
      MarketPrice? bestProductMatch = _findBestProductWithScore(searchKey, allPrices);

      if (bestProductMatch != null && bestProductMatch.markets.isNotEmpty) {
        double minPrice = 999999.0;
        bool foundPrice = false;

        for (var market in bestProductMatch.markets) {
          if (market.price > 0 && market.price < minPrice) {
            minPrice = market.price;
            foundPrice = true;
          }
        }

        if (foundPrice) totalCost += minPrice;
      }
    }
    return totalCost;
  }

  // --- 4. ARAMA MOTORU ---
  Future<List<Map<String, dynamic>>> searchProducts(String userQuery) async {
    if (userQuery.trim().isEmpty) return [];
    
    final cleanQuery = _normalizeForSearch(userQuery);
    final snapshot = await _firestore.collection('market_prices').get();
    
    List<Map<String, dynamic>> results = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final title = data['title'] ?? '';
      
      int score = _calculateMatchScore(cleanQuery, title);

      if (score > 0) {
        List<dynamic> marketsRaw = data['markets'] ?? [];
        double minPrice = 0.0;
        if (marketsRaw.isNotEmpty) {
          final prices = marketsRaw.map((m) => (m['price'] as num).toDouble()).toList();
          prices.sort();
          minPrice = prices.first;
        }

        results.add({
          'title': title,
          'imageUrl': data['imageUrl'] ?? '',
          'markets': marketsRaw, 
          'price': minPrice, 
          'score': score, 
        });
      }
    }
    
    results.sort((a, b) => b['score'].compareTo(a['score']));
    return results;
  }

  // --- 5. EKSİK MALZEMELER İÇİN EN UYGUN ÜRÜNLERİ GETİR ---
  List<MarketPrice> findMatchingProducts(List<String> missingIngredients, List<MarketPrice> allPrices) {
    List<MarketPrice> foundProducts = [];

    for (var rawIngredientName in missingIngredients) {
      String searchKey = _cleanIngredientName(rawIngredientName);
      
      MarketPrice? bestProductMatch = _findBestProductWithScore(searchKey, allPrices);

      if (bestProductMatch != null) {
        foundProducts.add(bestProductMatch);
      } else {
        foundProducts.add(MarketPrice(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          title: _cleanIngredientName(rawIngredientName).toUpperCase(), 
          normalizedTitle: '',
          category: 'Genel',
          imageUrl: '', 
          markets: [], 
        ));
      }
    }
    return foundProducts;
  }

  // --- YARDIMCILAR ---

  // A) Temizleme Motoru (RecipeService ile benzer güçlü temizlik)
  String _cleanIngredientName(String raw) {
    String processed = raw.toLowerCase();
    
    // Parantezleri sil
    processed = processed.replaceAll(RegExp(r'\(.*?\)', caseSensitive: false), '');
    
    // Miktar ve Birimleri Sil
    processed = processed.replaceFirst(
      RegExp(r'^[\d\s\.,/-]+(gr|gram|kg|kilogram|lt|litre|ml|mililitre|adet|tane|kaşık|yemek kaşığı|çay kaşığı|tatlı kaşığı|bardak|su bardağı|çay bardağı|paket|kutu|kavanoz|demet|tutam|dilim|diş|baş|fincan|kahve fincanı)\s*', caseSensitive: false), 
      ''
    );

    // Boyut sıfatlarını sil 
    const List<String> adjectivesToRemove = [
      'küçük boy', 'orta boy', 'büyük boy', 'küçük', 'orta', 'büyük', 
      'rendelenmiş', 'doğranmış', 'kıyılmış', 'dilimlenmiş', 'soyulmuş', 
      'küp küp', 'ince ince', 'yarım ay', 'piyazlık', 
      'taze', 'kuru', 'yaş', 'donuk', 'dondurulmuş', 
      'organik', 'köy', 'yerli', 'ithal'
    ];

    for (var adj in adjectivesToRemove) {
      processed = processed.replaceAll(adj, '');
    }

    processed = _normalizeForSearch(processed);
    if (processed.trim().isEmpty) return _normalizeForSearch(raw);

    return processed.trim();
  }

  // B) Puanlama Bazlı Ürün Bulucu
  MarketPrice? _findBestProductWithScore(String searchKey, List<MarketPrice> allPrices) {
    if (searchKey.isEmpty) return null;

    MarketPrice? bestMatch;
    int highestScore = 0;

    for (var product in allPrices) {
      int score = _calculateMatchScore(searchKey, product.title);

      // Eşik değer (20)
      if (score > highestScore && score >= 20) {
        highestScore = score;
        bestMatch = product;
      }
    }
    
    return bestMatch;
  }

  // C) [GÜNCELLENDİ] Skor Hesaplama + GENİŞLETİLMİŞ YASAKLI KELİME LİSTESİ
  int _calculateMatchScore(String query, String targetTitle) {
    String cleanQuery = _normalizeForSearch(query);
    String cleanTarget = _normalizeForSearch(targetTitle);
    
    // --- GENİŞLETİLMİŞ NEGATİF FİLTRE ---
    // Saf ürün (Süt, Yoğurt) aranırken aromalıların çıkmasını engeller.
    
    const List<String> unwantedFlavors = [
      'aromalı', 'aromali', 
      'meyveli', 'mey.', 'mey ', // "Mey." kısaltması eklendi!
      'çilekli', 'muzlu', 'kakaolu', 'vanilyalı', 'orman mey', 
      'içimino', 'pınar çocuk', 'büyüme küpü', 'devam sütü', 
      'laktozsuz' // Bazı tariflerde laktozsuz istenmiyorsa eklenebilir, şimdilik dursun
    ];

    bool queryHasFlavor = unwantedFlavors.any((f) => cleanQuery.contains(f));
    bool targetHasFlavor = unwantedFlavors.any((f) => cleanTarget.contains(f));

    // Eğer ben aromalı bir şey aramıyorsam (Sade Süt) AMA karşıma aromalı çıktıysa: PUAN SIFIR.
    if (!queryHasFlavor && targetHasFlavor) {
      return 0; 
    }
    // -------------------------------------

    if (cleanQuery == cleanTarget) return 100;

    List<String> queryWords = cleanQuery.split(' ').where((w) => w.length > 1).toList();
    List<String> targetWords = cleanTarget.split(' ');
    
    int score = 0;
    int matchCount = 0;

    for (var qWord in queryWords) {
      if (targetWords.contains(qWord)) {
        score += 30; 
        matchCount++;
      } else if (cleanTarget.contains(qWord)) {
        score += 10; 
      }
    }

    if (cleanTarget.startsWith(cleanQuery)) score += 20; 
    if (matchCount == queryWords.length && queryWords.isNotEmpty) score += 20;

    return score;
  }

  String _normalizeForSearch(String text) {
    return text.toLowerCase()
      .replaceAll('İ', 'i').replaceAll('I', 'ı').replaceAll('ı', 'i')
      .replaceAll('ğ', 'g').replaceAll('ü', 'u').replaceAll('ş', 's')
      .replaceAll('ö', 'o').replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^\w\s]'), ' ') 
      .replaceAll(RegExp(r'\s+'), ' ') 
      .trim();
  }
}