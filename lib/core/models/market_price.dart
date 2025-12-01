// lib/core/models/market_price.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MarketPrice {
  final String id;
  final String title; // Ürün adı (Örn: Yetiş Yumuşatıcı...)
  final String normalizedTitle; // Arama için (yetisyumusatici...)
  final String category;
  final String imageUrl;
  final List<MarketInfo> markets; // YENİ: Market listesi

  MarketPrice({
    required this.id,
    required this.title,
    required this.normalizedTitle,
    required this.category,
    required this.imageUrl,
    required this.markets,
  });

  factory MarketPrice.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return MarketPrice(
      id: doc.id,
      title: data['title'] ?? '',
      normalizedTitle: data['normalizedTitle'] ?? '',
      category: data['category'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      // Marketler dizisini mapleme
      markets: (data['markets'] as List<dynamic>? ?? []).map((m) {
        return MarketInfo.fromJson(m);
      }).toList(),
    );
  }
}

// Alt Sınıf: Her bir marketin fiyat bilgisi
class MarketInfo {
  final String marketName;
  final String branchName;
  final double price;
  final String unitPriceText;

  MarketInfo({
    required this.marketName,
    required this.branchName,
    required this.price,
    required this.unitPriceText,
  });

  factory MarketInfo.fromJson(Map<String, dynamic> json) {
    return MarketInfo(
      marketName: json['marketName'] ?? '',
      branchName: json['branchName'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      unitPriceText: json['unitPriceText'] ?? '',
    );
  }
}