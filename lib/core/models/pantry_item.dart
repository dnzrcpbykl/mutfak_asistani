// lib/core/models/pantry_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class PantryItem {
  final String id;
  final String userId;
  final String ingredientId;
  final String ingredientName;
  double quantity;
  String unit;
  DateTime? expirationDate;
  Timestamp createdAt;
  final String? brand;
  final String? marketName;
  final double? price;
  final String category;
  
  // YENİ ALAN: Bu ürün kaç paketten oluşuyor? (Örn: 3)
  final int pieceCount; 

  PantryItem({
    required this.id,
    required this.userId,
    required this.ingredientId,
    required this.ingredientName,
    required this.quantity,
    required this.unit,
    this.expirationDate,
    required this.createdAt,
    this.brand,
    this.marketName,
    this.price,
    this.category = 'Diğer',
    this.pieceCount = 1, // Varsayılan 1 paket
  });

  factory PantryItem.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return PantryItem(
      id: doc.id,
      userId: data['userId'] ?? '',
      ingredientId: data['ingredientId'] ?? '',
      ingredientName: data['ingredientName'] ?? '',
      quantity: (data['quantity'] as num).toDouble(),
      unit: data['unit'] ?? 'adet',
      expirationDate: (data['expirationDate'] as Timestamp?)?.toDate(),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      brand: data['brand'],
      marketName: data['marketName'],
      price: (data['price'] as num?)?.toDouble(),
      category: data['category'] ?? 'Diğer',
      // Firestore'dan okurken, eski kayıtlarda bu alan yoksa 1 kabul et
      pieceCount: data['pieceCount'] ?? 1, 
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'ingredientId': ingredientId,
      'ingredientName': ingredientName,
      'quantity': quantity,
      'unit': unit,
      'expirationDate': expirationDate != null ? Timestamp.fromDate(expirationDate!) : null,
      'createdAt': createdAt,
      'brand': brand,
      'marketName': marketName,
      'price': price,
      'category': category,
      // Veritabanına kaydet
      'pieceCount': pieceCount, 
    };
  }
}