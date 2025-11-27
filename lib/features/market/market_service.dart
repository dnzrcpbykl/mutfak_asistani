import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/market_price.dart';

class MarketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Tüm market fiyatlarını getirir
  Future<List<MarketPrice>> getAllPrices() async {
    final snapshot = await _firestore.collection('market_prices').get();
    return snapshot.docs.map((doc) => MarketPrice.fromFirestore(doc)).toList();
  }

  // Fiyat Kaydetme Fonksiyonu
  Future<void> addPriceInfo(String ingredientName, String marketName, double price) async {
    final query = await _firestore.collection('market_prices')
        .where('ingredientName', isEqualTo: ingredientName)
        .where('marketName', isEqualTo: marketName)
        .get();

    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update({
        'price': price,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _firestore.collection('market_prices').add({
        'ingredientName': ingredientName,
        'marketName': marketName,
        'price': price,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Eksik maliyeti hesapla
  double calculateMissingCost(List<String> missingIngredients, List<MarketPrice> allPrices) {
    double totalCost = 0;
    for (var missingItem in missingIngredients) {
      String searchKey = missingItem.trim().toLowerCase();
      
      final pricesForThis = allPrices.where((p) {
        String marketItemName = p.ingredientName.toLowerCase().trim();
        if (marketItemName == searchKey) return true;
        List<String> marketWords = marketItemName.split(' ');
        if (marketWords.contains(searchKey)) return true;
        List<String> searchWords = searchKey.split(' ');
        if (searchWords.contains(marketItemName)) return true;
        return false;
      }).toList();

      if (pricesForThis.isNotEmpty) {
        pricesForThis.sort((a, b) => a.price.compareTo(b.price));
        totalCost += pricesForThis.first.price;
      }
    }
    return totalCost;
  }

  // Market Karşılaştırma (Tüm Liste)
  Future<List<Map<String, dynamic>>> compareMarketsForList(List<String> itemNames) async {
    if (itemNames.isEmpty) return [];
    final allPrices = await getAllPrices();
    final Set<String> markets = allPrices.map((e) => e.marketName).toSet();
    List<Map<String, dynamic>> marketResults = [];

    for (var market in markets) {
      final marketPrices = allPrices.where((p) => p.marketName == market).toList();
      double totalCost = 0.0;
      int foundCount = 0;

      for (var item in itemNames) {
        String searchKey = item.trim().toLowerCase();
        final matches = marketPrices.where((p) {
          String pName = p.ingredientName.toLowerCase();
          if (pName == searchKey) return true;
          List<String> words = pName.split(' ');
          return words.contains(searchKey);
        }).toList();

        if (matches.isNotEmpty) {
          matches.sort((a, b) => a.price.compareTo(b.price));
          totalCost += matches.first.price;
          foundCount++;
        }
      }

      if (foundCount > 0) {
        marketResults.add({
          'marketName': market,
          'totalPrice': totalCost,
          'foundItemCount': foundCount,
          'missingItemCount': itemNames.length - foundCount
        });
      }
    }
    marketResults.sort((a, b) => (a['totalPrice'] as double).compareTo(b['totalPrice'] as double));
    return marketResults;
  }

  // --- GÜNCELLENEN FONKSİYON: TÜM FİYATLARI LİSTELEME ---
  // Tek bir ürün için bulunan TÜM market fiyatlarını liste olarak döner.
  List<Map<String, dynamic>> findAllPricesFor(String itemName, List<MarketPrice> allPrices) {
    String searchKey = itemName.trim().toLowerCase();
    if (searchKey.isEmpty) return [];
    
    // Veritabanındaki tüm fiyatlar içinde bu ürünü arıyoruz
    final matches = allPrices.where((p) {
      String pName = p.ingredientName.toLowerCase().trim();
      // 1. Tam eşleşme
      if (pName == searchKey) return true;
      // 2. Kelime bazlı
      List<String> marketWords = pName.split(' ');
      if (marketWords.contains(searchKey)) return true;
      // 3. Tersi
      List<String> searchWords = searchKey.split(' ');
      if (searchWords.contains(pName)) return true;
      
      return false;
    }).toList();

    if (matches.isEmpty) return [];

    // En ucuza göre sırala
    matches.sort((a, b) => a.price.compareTo(b.price));

    // Listeyi map listesine çevirip döndür
    return matches.map((m) => {
      'market': m.marketName,
      'price': m.price,
    }).toList();
  }
}