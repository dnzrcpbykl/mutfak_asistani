import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingItem {
  final String id;
  final String name;
  final bool isCompleted; // Ürün alındı mı? (Çizik atacağız)

  ShoppingItem({
    required this.id,
    required this.name,
    this.isCompleted = false,
  });

  factory ShoppingItem.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ShoppingItem(
      id: doc.id,
      name: data['name'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'isCompleted': isCompleted,
      'createdAt': FieldValue.serverTimestamp(), // Sıralama için zaman damgası
    };
  }
}