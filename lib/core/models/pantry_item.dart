// lib/core/models/pantry_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class PantryItem {
  final String id; // Firestore doküman ID'si
  final String userId;
  final String ingredientId; // Hangi malzeme (Ingredient tablosundan)
  final String ingredientName; // Kolaylık için malzemenin adı
  double quantity;
  String unit; // ad/kg/litre
  DateTime? expirationDate; // Son kullanma tarihi (nullable)
  Timestamp createdAt; // Eklendiği zaman

  PantryItem({
    required this.id,
    required this.userId,
    required this.ingredientId,
    required this.ingredientName,
    required this.quantity,
    required this.unit,
    this.expirationDate,
    required this.createdAt,
  });

  // Firestore'dan veri okurken
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
    );
  }

  // Firestore'a veri yazarken
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'ingredientId': ingredientId,
      'ingredientName': ingredientName,
      'quantity': quantity,
      'unit': unit,
      'expirationDate': expirationDate != null ? Timestamp.fromDate(expirationDate!) : null,
      'createdAt': createdAt,
    };
  }
}