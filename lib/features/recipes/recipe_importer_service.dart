// lib/features/recipes/recipe_importer_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Auth eklendi
import '../../secrets.dart';

class RecipeImporterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // Kullanıcıyı tanımak için

  // Yardımcı: O anki kullanıcının tarif önerileri koleksiyonunu getirir
  CollectionReference? _getUserRecipeCollection() {
    final user = _auth.currentUser;
    if (user == null) return null;
    // Örnek Yol: users/USER_ID_123/suggestions
    return _firestore.collection('users').doc(user.uid).collection('suggestions');
  }

  // 1. Önceki Şahsi Tarifleri Temizle
  Future<void> _clearOldRecipes() async {
    final collectionRef = _getUserRecipeCollection();
    if (collectionRef == null) return;

    final snapshot = await collectionRef.get();
    
    // Batch (Toplu işlem) ile silme daha performanslıdır
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    
    debugPrint("🧹 Kullanıcının eski önerileri temizlendi.");
  }

  // 2. Kilerdeki Malzemelere Göre Tarif Üret
  Future<void> generateRecipesFromPantry(List<String> myIngredients) async {
    // Önce kullanıcının kendi eski önerilerini temizle
    await _clearOldRecipes();

    if (myIngredients.isEmpty) {
      debugPrint("⚠️ Kiler boş.");
      return;
    }

    String ingredientsText = myIngredients.join(", ");
    debugPrint("🤖 Şef düşünüyor... Eldekiler: $ingredientsText");

    const String apiKey = Secrets.geminiApiKey;
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$apiKey');

    final headers = {'Content-Type': 'application/json'};
    
    final prompt = '''
      Sen Türk mutfağına hakim uzman bir şefsin.
      Elimdeki malzemeler: [$ingredientsText]
      
      GÖREVİN:
      Bu malzemelerin ÇOĞUNLUĞUNU kullanarak yapılabilecek en iyi 5-6 tarifi ver.
      
      ÖNEMLİ KURAL:
      Malzeme listesinde ASLA marka adı kullanma.
      (Örn: "Dr. Oetker Kabartma Tozu" yazma, sadece "Kabartma Tozu" yaz. "Pınar Süt" yazma, "Süt" yaz).
      
      ÖNCELİK SIRALAMASI:
      1. Çorbalar
      2. Ana Yemekler
      3. Ara Sıcak / Aperatif
      4. Tatlı
      
      JSON FORMATI:
      [
        {
          "name": "Yemek Adı",
          "description": "Kısa açıklama",
          "ingredients": ["Malzeme 1", "Malzeme 2"], 
          "instructions": "Yapılış...",
          "prepTime": 30,
          "difficulty": "Kolay", 
          "category": "Ana Yemek"
        }
      ]
    ''';

    final body = jsonEncode({
      "contents": [{"parts": [{"text": prompt}]}]
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] == null || (data['candidates'] as List).isEmpty) return;
        
        String content = data['candidates'][0]['content']['parts'][0]['text'];
        
        final jsonMatch = RegExp(r'\[\s*\{.*?\}\s*\]', dotAll: true).firstMatch(content);

        if (jsonMatch != null) {
          String cleanJson = jsonMatch.group(0)!;
          List<dynamic> recipesJson = jsonDecode(cleanJson);
          
          final collectionRef = _getUserRecipeCollection();
          if (collectionRef == null) return;

          final batch = _firestore.batch();
          
          for (var item in recipesJson) {
            // Kullanıcının kendi 'suggestions' koleksiyonuna ekle
            final docRef = collectionRef.doc(); 
            
            batch.set(docRef, {
              'name': item['name'],
              'description': item['description'],
              'ingredients': item['ingredients'],
              'instructions': item['instructions'],
              'prepTime': item['prepTime'],
              'difficulty': item['difficulty'],
              'category': item['category'],
              'createdAt': FieldValue.serverTimestamp(), // Tarih de ekleyelim
            });
          }
          await batch.commit(); 
          debugPrint("✅ Şef ${recipesJson.length} tarif önerdi (Kullanıcıya özel)!");
        }
      } else {
        throw Exception("API Hatası: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("🔥 Hata: $e");
      rethrow;
    }
  }
}