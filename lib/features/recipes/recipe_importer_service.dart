import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../secrets.dart'; // Secrets dosyanın yerinde olduğundan emin ol

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
  Future<void> generateRecipesFromPantry(List<String> myIngredients, {String userPreference = "Fark etmez, genel öneriler ver.", String? customInstruction}) async {
    // Önce temizlik
    await _clearOldRecipes();
    
    if (myIngredients.isEmpty) {
      debugPrint("⚠️ Kiler boş.");
      return;
    }

    String ingredientsText = myIngredients.join(", ");
    
    // Kullanıcı isteği
    String finalUserRequest = (customInstruction != null && customInstruction.trim().isNotEmpty) 
        ? "KULLANICININ ÖZEL VE KESİN İSTEĞİ: $customInstruction"
        : "Kullanıcı Tercihi: $userPreference";
        
    debugPrint("🤖 Şef düşünüyor... Eldekiler: $ingredientsText | İstek: $finalUserRequest");

    // NOT: Secrets.geminiApiKey kullandığın varsayıldı.
    // Eğer .env kullanıyorsan: dotenv.env['GEMINI_API_KEY'] şeklinde değiştir.
    const String apiKey = Secrets.geminiApiKey;
    
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$apiKey');

    final headers = {'Content-Type': 'application/json'};

    // --- PROMPT YAPISI ---
    final prompt = '''
      Sen Türk mutfağına hakim, teknik detaylara önem veren profesyonel bir şefsin ve aynı zamanda diyetisyensin.
      Elimdeki malzemeler: [$ingredientsText]
      
      **KULLANICI TERCİHİ (ÇOK ÖNEMLİ):** $finalUserRequest.
      Lütfen tarifleri seçerken BU TERCİHE ÖNCELİK VER.
      
      GÖREVİN:
      Bu malzemelerin çoğunluğunu (ve gerekirse her evde bulunan su, tuz, karabiber, sıvı yağ, salça gibi temel malzemeleri de ekleyerek) kullanarak yapılabilecek en iyi 5 tarifi oluştur.

      ÇOK ÖNEMLİ KURALLAR (BUNLARA KESİN UY):
      1. **NET MİKTARLAR:** Malzeme listesinde ASLA belirsiz ifade kullanma. "Yumurta" YAZMA, "2 adet Yumurta" YAZ. "Un" YAZMA, "1 su bardağı Un" YAZ.
      2. **NET SÜRELER:** Yapılış adımlarında "pişirin" deyip geçme. "Kısık ateşte 15 dakika pişirin" gibi net süre ver.
      3. **MARKA YOK:** Marka adı kullanma.
      4. **BESİN DEĞERLERİ (ZORUNLU):** Her bir tarif için 1 porsiyonluk tahmini Kalori (kcal), Protein (g), Karbonhidrat (g) ve Yağ (g) değerlerini hesapla ve JSON'a ekle.
      5. **SPESİFİK OL (ÇOK ÖNEMLİ):** Malzeme isimlerinde asla genel kategori ismi kullanma.
         - "Sıvı yağ" DEME -> "Ayçiçek yağı" veya "Zeytinyağı" olarak belirt.
         - "Peynir" DEME -> "Kaşar Peyniri", "Beyaz Peynir" veya "Lor Peyniri" olarak belirt.
         - "Un" DEME -> "Beyaz Un", "Tam Buğday Unu" veya "Galeta Unu" olarak belirt.
         - "Biber" DEME -> "Yeşil Biber", "Kapya Biber" veya "Dolmalık Biber" olarak belirt.
      
      Bu kural, market alışveriş listesi oluştururken doğru ürünü bulmamız için kritiktir.

      İSTENEN JSON FORMATI (Sadece bu JSON'u döndür, yorum yapma):
      [
        {
          "name": "Yemek Adı",
          "description": "Yemeğin kısa, iştah açıcı tanımı",
          "ingredients": [
            "2 adet Yumurta", 
            "1 su bardağı Süt"
          ], 
          "instructions": "1. Kıymayı tavaya alın... ",
          "prepTime": 30,
          "difficulty": "Orta", 
          "category": "Ana Yemek",
          "calories": "450 kcal",
          "protein": "25g",
          "carbs": "10g",
          "fat": "15g"
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

        // 1. Google API hatası kontrolü
        if (data['error'] != null) {
          debugPrint("❌ API Hatası: ${data['error']['message']}");
          throw Exception(data['error']['message']);
        }

        // 2. Cevap boş mu kontrolü
        if (data['candidates'] == null || (data['candidates'] as List).isEmpty) {
          debugPrint("⚠️ AI cevap üretemedi (Güvenlik filtresi veya boş cevap).");
          return; 
        }

        // 3. İçerik kontrolü
        var candidate = data['candidates'][0];
        if (candidate['content'] == null || candidate['content']['parts'] == null) {
           debugPrint("⚠️ Cevap formatı bozuk.");
           return;
        }
        
        String content = data['candidates'][0]['content']['parts'][0]['text'];

        // --- GÜVENLİ VE ÇÖKMEZ JSON AYRIŞTIRMA (GÜNCELLEME BURADA) ---
        final jsonMatch = RegExp(r'\[\s*\{.*?\}\s*\]', dotAll: true).firstMatch(content);

        if (jsonMatch != null) {
          try {
            // Regex ile bulunan temiz JSON string'i
            String cleanJson = jsonMatch.group(0)!;
            
            // JSON Decode işlemi (Hata olursa catch'e düşer, uygulama çökmez)
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
                // --- EKLENEN BESİN DEĞERLERİ ---
                'calories': item['calories'] ?? 'Belirsiz',
                'protein': item['protein'] ?? '-',
                'carbs': item['carbs'] ?? '-',
                'fat': item['fat'] ?? '-',
                // ----------------------------
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
            await batch.commit(); 
            debugPrint("✅ Şef ${recipesJson.length} adet BESİN DEĞERLİ tarif önerdi!");

          } catch (e) {
            // JSON formatı bozuksa veya decode hatası olursa buraya düşer
            debugPrint("🛑 JSON Parse Hatası: AI bozuk format gönderdi. Detay: $e");
            debugPrint("Gelen Veri: $content");
            // Kullanıcıya çaktırmadan işlemi bitiriyoruz, uygulama kapanmıyor.
          }
        } else {
          debugPrint("⚠️ AI cevabında JSON bloğu bulunamadı.");
        }
        // -----------------------------------------------------------

      } else {
        throw Exception("API Hatası: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("🔥 Genel Hata: $e");
      // UI tarafında snackbar göstermek için hatayı yukarı fırlatabilirsin
      // veya sessizce loglayabilirsin.
      rethrow; 
    }
  }
}