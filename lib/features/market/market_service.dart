import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/market_price.dart';

class MarketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Tüm market fiyatlarını getirir
  Future<List<MarketPrice>> getAllPrices() async {
    final snapshot = await _firestore.collection('market_prices').get();
    return snapshot.docs.map((doc) => MarketPrice.fromFirestore(doc)).toList();
  }

  // GÜNCEL HESAPLAMA MANTIĞI
  double calculateMissingCost(List<String> missingIngredients, List<MarketPrice> allPrices) {
    double totalCost = 0;

    for (var missingItem in missingIngredients) {
      String searchKey = missingItem.trim().toLowerCase();

      // Fiyat listesinde bu malzemeye benzeyen bir şey var mı?
      // Örn: Eksik="Soğan", Market="Kuru Soğan" -> Eşleşmeli.
      final pricesForThis = allPrices.where((p) {
        String marketItemName = p.ingredientName.toLowerCase();
        return marketItemName.contains(searchKey) || searchKey.contains(marketItemName);
      }).toList();

      if (pricesForThis.isNotEmpty) {
        // En ucuz fiyatı bul ve ekle
        pricesForThis.sort((a, b) => a.price.compareTo(b.price));
        totalCost += pricesForThis.first.price;
      } else {
        // Fiyat bulunamazsa varsayılan bir ortalama fiyat ekleyebiliriz (Örn: 20 TL)
        // Şimdilik 0 ekliyoruz ki yanlış bilgi vermeyelim.
        totalCost += 0; 
      }
    }
    return totalCost;
  }
}