import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../secrets.dart'; 

class RecipeImporterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Önceki Tarifleri Temizle (Sil)
  Future<void> _clearOldRecipes() async {
    final snapshot = await _firestore.collection('recipes').get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
    debugPrint("🧹 Eski tarifler temizlendi.");
  }

  // 2. Kilerdeki Malzemelere Göre Tarif Üret
  Future<void> generateRecipesFromPantry(List<String> myIngredients) async {
    // Önce temizlik yap
    await _clearOldRecipes();

    if (myIngredients.isEmpty) {
      debugPrint("⚠️ Kiler boş, rastgele öneri yapılacak.");
      // Kiler boşsa genel popüler yemekler isteyebiliriz veya uyarı verdirebiliriz.
      // Şimdilik devam edelim, Gemini "elindekilerle bir şey yapamazsın" diyebilir veya basit şeyler önerir.
    }

    // Malzeme listesini metne çevir (Örn: "Domates, Biber, Yumurta")
    String ingredientsText = myIngredients.join(", ");
    debugPrint("🤖 Şef düşünüyor... Eldekiler: $ingredientsText");

    const String apiKey = Secrets.geminiApiKey;
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$apiKey');

    final headers = {'Content-Type': 'application/json'};

    // AKILLI PROMPT (Senin isteğine göre düzenlendi)
    final prompt = '''
      Sen uzman bir Türk aşçısısın. Bir kullanıcının elinde şu malzemeler var:
      [$ingredientsText]
      
      GÖREVİN:
      Bu malzemelerin ÇOĞUNLUĞUNU kullanarak yapılabilecek en iyi 5 Türk yemeği tarifini ver.
      
      KURALLAR:
      1. Öncelik eldeki malzemelerle yapılabilen yemeklerindir.
      2. Eğer tam uyan yemek yoksa, kullanıcının en fazla 1-2 malzeme satın alarak yapabileceği yemekleri öner.
      3. Cevabın SADECE geçerli bir JSON listesi olsun.
      
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
      
      NOT: "ingredients" listesine sadece malzeme adını yaz (Miktar yazma).
    ''';

    final body = jsonEncode({
      "contents": [{"parts": [{"text": prompt}]}]
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String content = data['candidates'][0]['content']['parts'][0]['text'];
        content = content.replaceAll('```json', '').replaceAll('```', '').trim();

        List<dynamic> recipesJson = jsonDecode(content);
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
            'category': item['category'],
          });
        }

        await batch.commit(); 
        debugPrint("✅ Şef ${recipesJson.length} tarif önerdi!");
        
      } else {
        throw Exception("API Hatası: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("🔥 Hata: $e");
      rethrow;
    }
  }
}