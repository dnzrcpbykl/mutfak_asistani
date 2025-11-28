import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../secrets.dart'; // API Key'in olduğu dosya

class RecipeImporterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Yardımcı: O anki kullanıcının tarif önerileri koleksiyonunu getirir
  CollectionReference? _getUserRecipeCollection() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _firestore.collection('users').doc(user.uid).collection('suggestions');
  }

  // 1. Önceki Şahsi Tarifleri Temizle
  Future<void> _clearOldRecipes() async {
    final collectionRef = _getUserRecipeCollection();
    if (collectionRef == null) return;

    final snapshot = await collectionRef.get();
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    debugPrint("🧹 Kullanıcının eski önerileri temizlendi.");
  }

  // 2. Kilerdeki Malzemelere Göre Tarif Üret
  // GÜNCELLEME: 'customInstruction' parametresi eklendi.
  Future<void> generateRecipesFromPantry(List<String> myIngredients, {String userPreference = "Fark etmez, genel öneriler ver.", String? customInstruction}) async {
    // Önce temizlik
    await _clearOldRecipes();

    if (myIngredients.isEmpty) {
      debugPrint("⚠️ Kiler boş.");
      return;
    }

    String ingredientsText = myIngredients.join(", ");
    
    // --- GÜNCELLENEN MANTIK BAŞLANGIÇ ---
    // Eğer özel bir talimat (customInstruction) geldiyse onu kullan, yoksa buton seçimini (userPreference) kullan.
    String finalUserRequest = (customInstruction != null && customInstruction.trim().isNotEmpty) 
        ? "KULLANICININ ÖZEL VE KESİN İSTEĞİ: $customInstruction"
        : "Kullanıcı Tercihi: $userPreference";
    // ------------------------------------

    debugPrint("🤖 Şef düşünüyor... Eldekiler: $ingredientsText | İstek: $finalUserRequest");

    const String apiKey = Secrets.geminiApiKey;
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$apiKey');

    final headers = {'Content-Type': 'application/json'};

    // --- SENİN ORİJİNAL PROMPT YAPIN (KORUNDU) ---
    // Sadece dinamik istek kısmı ($finalUserRequest) araya yerleştirildi.
    final prompt = '''
      Sen Türk mutfağına hakim, teknik detaylara önem veren profesyonel bir şefsin.
      Elimdeki malzemeler: [$ingredientsText]
      
      **KULLANICI TERCİHİ (ÇOK ÖNEMLİ):** $finalUserRequest.
      Lütfen tarifleri seçerken BU TERCİHE ÖNCELİK VER.
      
      GÖREVİN:
      Bu malzemelerin çoğunluğunu (ve gerekirse her evde bulunan su, tuz, karabiber, sıvı yağ, salça gibi temel malzemeleri de ekleyerek) kullanarak yapılabilecek en iyi 5 tarifi oluştur.
      
      ÇOK ÖNEMLİ KURALLAR (BUNLARA KESİN UY):
      1. **NET MİKTARLAR:** Malzeme listesinde ASLA belirsiz ifade kullanma. "Yumurta" YAZMA, "2 adet Yumurta" YAZ. "Un" YAZMA, "1 su bardağı Un" YAZ. Miktarı olmayan malzeme kabul edilmez.
      2. **NET SÜRELER:** Yapılış adımlarında "pişirin" veya "haşlayın" deyip geçme. "Kısık ateşte 15 dakika pişirin", "200 derece fırında 25 dakika bekletin" gibi net SÜRE ve ISI bilgisi ver.
      3. **MARKA YOK:** Marka adı kullanma (Örn: "Pakmaya" değil "Maya" yaz).
      4. **KATEGORİLER:** Çorba, Ana Yemek, Ara Sıcak veya Tatlı olarak belirt.
      
      İSTENEN JSON FORMATI (Sadece bu JSON'u döndür, yorum yapma):
      [
        {
          "name": "Yemek Adı",
          "description": "Yemeğin kısa, iştah açıcı tanımı",
          "ingredients": [
            "2 adet Yumurta", 
            "1 su bardağı Süt", 
            "500 gr Kıyma", 
            "1 çay kaşığı Tuz"
          ], 
          "instructions": "1. Kıymayı tavaya alın ve suyunu çekene kadar (yaklaşık 10 dk) kavurun.\\n2. Soğanları ekleyip pembeleşinceye kadar 5 dakika daha kavurun.\\n3. ...",
          "prepTime": 30,
          "difficulty": "Orta", 
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
        
        // JSON bloğunu metnin içinden ayıkla
        final jsonMatch = RegExp(r'\[\s*\{.*?\}\s*\]', dotAll: true).firstMatch(content);
        
        if (jsonMatch != null) {
          String cleanJson = jsonMatch.group(0)!;
          List<dynamic> recipesJson = jsonDecode(cleanJson);
          
          final collectionRef = _getUserRecipeCollection();
          if (collectionRef == null) return;

          final batch = _firestore.batch();

          for (var item in recipesJson) {
            final docRef = collectionRef.doc();
            batch.set(docRef, {
              'name': item['name'],
              'description': item['description'],
              'ingredients': item['ingredients'],
              'instructions': item['instructions'],
              'prepTime': item['prepTime'],
              'difficulty': item['difficulty'],
              'category': item['category'],
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
          await batch.commit(); 
          debugPrint("✅ Şef ${recipesJson.length} adet DETAYLI tarif önerdi!");
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