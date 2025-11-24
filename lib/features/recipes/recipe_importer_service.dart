import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../secrets.dart';

class RecipeImporterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Önceki Tarifleri Temizle
  Future<void> _clearOldRecipes() async {
    final snapshot = await _firestore.collection('recipes').get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
    debugPrint("🧹 Eski tarifler temizlendi.");
  }

  // 2. Kilerdeki Malzemelere Göre Tarif Üret
  Future<void> generateRecipesFromPantry(List<String> myIngredients) async {
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

    // --- PROMPT GÜNCELLEMESİ ---
    final prompt = '''
      Sen Türk mutfağına hakim uzman bir şefsin.
      Elimdeki malzemeler: [$ingredientsText]
      
      GÖREVİN:
      Bu malzemelerin ÇOĞUNLUĞUNU kullanarak yapılabilecek en iyi 5-6 tarifi ver.
      
      ÖNEMLİ KURAL:
      Malzeme listesinde ASLA marka adı kullanma. (Örn: "Dr. Oetker Kabartma Tozu" yazma, sadece "Kabartma Tozu" yaz. "Pınar Süt" yazma, "Süt" yaz).
      
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
          "ingredients": ["Malzeme 1", "Malzeme 2"], // Markasız yalın isimler!
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
        String content = data['candidates'][0]['content']['parts'][0]['text'];
        
        // JSON Temizliği
        final jsonMatch = RegExp(r'\[\s*\{.*?\}\s*\]', dotAll: true).firstMatch(content);

        if (jsonMatch != null) {
          String cleanJson = jsonMatch.group(0)!;
          List<dynamic> recipesJson = jsonDecode(cleanJson);
          
          final batch = _firestore.batch();
          for (var item in recipesJson) {
            final docRef = _firestore.collection('recipes').doc();
            batch.set(docRef, {
              'name': item['name'],
              'description': item['description'],
              'ingredients': item['ingredients'],
              'instructions': item['instructions'],
              'prepTime': item['prepTime'],
              'difficulty': item['difficulty'],
              'category': item['category'], // Kategori artık standart
            });
          }
          await batch.commit(); 
          debugPrint("✅ Şef ${recipesJson.length} tarif önerdi!");
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