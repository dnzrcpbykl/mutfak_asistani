// lib/core/models/market_price.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MarketPrice {
  final String id;
  final String ingredientName; // Hangi ürün? (Örn: Biber)
  final String marketName;     // Hangi market? (Örn: A101, Bim, Şok)
  final double price;          // Fiyatı

  MarketPrice({
    required this.id,
    required this.ingredientName,
    required this.marketName,
    required this.price,
  });

  factory MarketPrice.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return MarketPrice(
      id: doc.id,
      ingredientName: data['ingredientName'] ?? '',
      marketName: data['marketName'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}