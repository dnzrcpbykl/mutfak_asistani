// lib/core/models/ingredient.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Ingredient {
  final String id;
  final String name;
  final String category; // Sebze, Bakliyat, Süt Ürünü vb.
  final String unit; // kg, adet, litre

  Ingredient({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
  });

  // Firestore'dan veri okurken kullanacağımız fabrika metodu
  factory Ingredient.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Ingredient(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      unit: data['unit'] ?? '',
    );
  }

  // Firestore'a veri yazarken kullanacağımız metot
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'unit': unit,
    };
  }
}