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
  
  // --- YENİ EKLENEN ALAN ---
  final String category; // Örn: "Süt Ürünleri", "Bakliyat"
  // -------------------------

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
    this.category = 'Diğer', // Varsayılan değer
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
      // Kategori verisini al, yoksa 'Diğer' yap
      category: data['category'] ?? 'Diğer',
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
      // Kaydederken ekle
      'category': category,
    };
  }
}