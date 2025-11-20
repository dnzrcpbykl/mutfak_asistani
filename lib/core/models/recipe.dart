// lib/core/models/recipe.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Recipe {
  final String id;
  final String name;
  final String description;
  final List<String> ingredients; // Gerekli malzemelerin isimleri (Örn: ["Domates", "Yumurta"])
  final String instructions; // Yapılışı
  final int prepTime; // Dakika

  Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.ingredients,
    required this.instructions,
    required this.prepTime,
  });

  factory Recipe.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Recipe(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      // Firestore'dan gelen listeyi Dart listesine çeviriyoruz:
      ingredients: List<String>.from(data['ingredients'] ?? []),
      instructions: data['instructions'] ?? '',
      prepTime: data['prepTime'] ?? 0,
    );
  }
}