import 'package:cloud_firestore/cloud_firestore.dart';

class Recipe {
  final String id;
  final String name;
  final String description;
  final List<String> ingredients;
  final String instructions;
  final int prepTime;
  final String difficulty;
  final String category;
  
  // --- YENİ EKLENEN ALANLAR (Hatanın Çözümü) ---
  final String calories; 
  final String protein;  
  final String carbs;    
  final String fat;      

  Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.ingredients,
    required this.instructions,
    this.prepTime = 15, 
    this.difficulty = 'Orta',
    this.category = 'Genel',
    // Varsayılan değerler (Eski veriler patlamasın diye)
    this.calories = 'Hesaplanmadı',
    this.protein = '-',
    this.carbs = '-',
    this.fat = '-',
  });

  factory Recipe.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Recipe(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      ingredients: List<String>.from(data['ingredients'] ?? []),
      instructions: data['instructions'] ?? '',
      prepTime: data['prepTime'] ?? 15,
      difficulty: data['difficulty'] ?? 'Orta',
      category: data['category'] ?? 'Genel',
      
      // Firestore'dan okuma kısmı
      calories: data['calories'] ?? 'Hesaplanmadı',
      protein: data['protein'] ?? '-',
      carbs: data['carbs'] ?? '-',
      fat: data['fat'] ?? '-',
    );
  }
}