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

  // --- 2. AKILLI ARAMA MOTORU (BURASI DEĞİŞTİ) ---
  Future<List<Map<String, dynamic>>> searchProducts(String userQuery) async {
    // Arama boşsa dön
    if (userQuery.trim().isEmpty) return [];

    // Kullanıcının sorgusunu temizle (Boşlukları KORU!)
    // Örn: "Süt" -> "sut"
    final String cleanQuery = _normalizeWithSpaces(userQuery); 
    final List<String> queryWords = cleanQuery.split(' '); // ["sut"]

    final snapshot = await _firestore.collection('market_prices').get();

    List<Map<String, dynamic>> scoredResults = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      // Veritabanındaki 'title'ı alıyoruz (normalizedTitle değil!)
      // Örn: "Torku Süt 1 Lt"
      final String originalTitle = data['title'] ?? '';
      
      // Başlığı temizle ve kelimelere ayır
      // "torku sut 1 lt"
      final String cleanTitle = _normalizeWithSpaces(originalTitle);
      final List<String> titleWords = cleanTitle.split(' ');

      int score = 0;

      // --- PUANLAMA ALGORİTMASI ---
      
      // KURAL 1: Tam Eşleşme (En Yüksek Puan)
      // Kullanıcı "süt" yazdı, ürünün içinde tam olarak "süt" kelimesi geçiyor mu?
      // "sütlü" -> "süt" değildir. "süt" -> "süt"tür.
      if (titleWords.contains(cleanQuery)) {
        score += 100;
      }

      // KURAL 2: Başlangıç Eşleşmesi (Yüksek Puan)
      // Ürün ismi aranan kelimeyle mi başlıyor? Örn: "Sütaş Süt..."
      if (cleanTitle.startsWith(cleanQuery)) {
        score += 50;
      }

      // KURAL 3: Kelime Başlangıcı (Orta Puan)
      // Ürünün herhangi bir kelimesi arananla başlıyor mu?
      // Örn: "Pınar Süt" -> "Süt" kelimesi "süt" ile başlıyor.
      // Örn: "Sütlü Çikolata" -> "Sütlü" kelimesi "süt" ile başlıyor.
      for (var word in titleWords) {
        if (word.startsWith(cleanQuery)) {
          score += 20;
          // Eğer kelime tam olarak eşleşmiyorsa (yani "sütlü" gibi ek almışsa) puanı biraz kıralım
          if (word.length > cleanQuery.length) {
            score -= 5; // "Sütlü"yü, saf "Süt"ün altına atmak için
          }
        }
      }

      // KURAL 4: Düz İçerme (Düşük Puan - Yedek)
      // Hiçbir kelime uymuyor ama harfler içinde geçiyor
      if (score == 0 && cleanTitle.contains(cleanQuery)) {
        score += 1;
      }

      // Eğer puan aldıysa listeye ekle
      if (score > 0) {
        scoredResults.add({
          'id': doc.id,
          'title': originalTitle,
          'imageUrl': data['imageUrl'] ?? '',
          'markets': data['markets'] ?? [],
          'price': _extractMinPrice(data['markets']),
          'score': score, // Sıralama için puanı tutuyoruz
        });
      }
    }

    // --- SONUÇLARI SIRALA ---
    // Puanı yüksek olan en üste, puanlar eşitse fiyata göre sırala
    scoredResults.sort((a, b) {
      int scoreCompare = b['score'].compareTo(a['score']);
      if (scoreCompare != 0) return scoreCompare;
      return (a['price'] as double).compareTo(b['price'] as double);
    });

    return scoredResults;
  }

  // --- YENİ HELPER: BOŞLUKLARI KORUYAN NORMALİZASYON ---
  // "Sütlü Çikolata" -> "sutlu cikolata" (Boşluklar duruyor!)
  String _normalizeWithSpaces(String text) {
    return text.toLowerCase()
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .replaceAll('ı', 'i') 
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        // Boşlukları SİLMİYORUZ, tireleri boşluğa çeviriyoruz ki kelimeler ayrılsın
        .replaceAll('-', ' ') 
        .replaceAll(RegExp(r'\s+'), ' ') // Çoklu boşlukları teke düşür
        .trim();
  }

  // En düşük fiyatı bulma yardımcısı (Aynı)
  double _extractMinPrice(dynamic markets) {
    if (markets == null || markets is! List || markets.isEmpty) return 0.0;
    try {
      double minP = 999999.0;
      for (var m in markets) {
        double p = (m['price'] as num?)?.toDouble() ?? 0.0;
        if (p > 0 && p < minP) minP = p;
      }
      return minP == 999999.0 ? 0.0 : minP;
    } catch (e) {
      return 0.0;
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