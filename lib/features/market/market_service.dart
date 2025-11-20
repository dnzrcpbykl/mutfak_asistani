// lib/features/market/market_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/market_price.dart';

class MarketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Tüm market fiyatlarını getirir
  Future<List<MarketPrice>> getAllPrices() async {
    final snapshot = await _firestore.collection('market_prices').get();
    return snapshot.docs.map((doc) => MarketPrice.fromFirestore(doc)).toList();
  }

  // Eksik malzemelerin toplam tahmini maliyetini hesaplar
  double calculateMissingCost(List<String> missingIngredients, List<MarketPrice> allPrices) {
    double totalCost = 0;

    for (var ingredient in missingIngredients) {
      // Bu malzeme için fiyatları bul
      final pricesForThis = allPrices.where(
        (p) => p.ingredientName.toLowerCase() == ingredient.trim().toLowerCase()
      ).toList();

      if (pricesForThis.isNotEmpty) {
        // En ucuz fiyatı bul ve ekle
        // (pricesForThis listesini fiyata göre küçükten büyüğe sırala, ilkini al)
        pricesForThis.sort((a, b) => a.price.compareTo(b.price));
        totalCost += pricesForThis.first.price;
      } else {
        // Fiyat bulunamazsa ortalama bir değer ekle veya 0 say (Şimdilik 0)
      }
    }
    return totalCost;
  }
}