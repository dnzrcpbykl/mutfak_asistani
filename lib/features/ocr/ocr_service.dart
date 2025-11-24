import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../secrets.dart';

class OCRService {
  static const String _apiKey = Secrets.geminiApiKey;
  static Map<String, dynamic> lastScannedResult = {}; 

  Future<String?> pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: source); 
    return photo?.path;
  }

  Future<Map<String, dynamic>> textToIngredients(String imagePath) async {
    debugPrint("🚀 Cyber Chef Fişi Analiz Ediyor (Sadece Gıda & Doğru Model)...");

    try {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // DÜZELTME: İsteğin üzerine model ismi güncellendi
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$_apiKey');
      
      final headers = {'Content-Type': 'application/json'};

      // --- KATI GIDA FİLTRESİ VE KATEGORİ PROMPT'U ---
      const prompt = '''
      Bu market fişini analiz et.
      
      GÖREV 1: MARKET TESPİTİ
      "BIM", "A101", "SOK", "MIGROS", "CARREFOURSA" veya "DIGER".

      GÖREV 2: SADECE GIDA ÜRÜNLERİNİ AYIKLA (ÇOK KRİTİK)
      Listeye SADECE insanın yiyip içebileceği GIDA ürünlerini al.
      
      AŞAĞIDAKİLERİ KESİNLİKLE LİSTEYE ALMA (GÖRMEZDEN GEL):
      ❌ Temizlik (Deterjan, Sabun, Yumuşatıcı, Çamaşır Suyu)
      ❌ Kişisel Bakım (Şampuan, Diş Macunu, Tıraş Bıçağı, Pamuk)
      ❌ Kağıt Ürünleri (Tuvalet Kağıdı, Havlu Kağıt, Peçete, Islak Mendil)
      ❌ Mutfak Gereçleri (Folyo, Çöp Torbası, Bardak, Tabak)
      ❌ Hayvan Mamaları (Kedi/Köpek maması)
      ❌ Poşet, İndirim, KDV satırları.

      GÖREV 3: DOĞRU KATEGORİLENDİRME
      Her ürün için "category" alanına SADECE şu listeden en uygununu seç:

      1. "Et & Tavuk & Balık": (TÜM ET ÜRÜNLERİ BURAYA. Kıyma, Kuşbaşı, Tavuk, Baget, Bonfile, Kanat, Balık, Ton Balığı, Salam, Sucuk, Sosis, Pastırma, Kavurma vb.) -> Tavuk ürünlerini sakın kahvaltılığa atma!
      2. "Süt & Kahvaltılık": (Süt, Peynir Çeşitleri, Yoğurt, Ayran, Kefir, Yumurta, Tereyağı, Margarin, Zeytin, Reçel, Bal, Kaymak, Helva)
      3. "Meyve & Sebze": (Domates, Biber, Soğan, Patates, Meyveler, Yeşillikler)
      4. "Temel Gıda & Bakliyat": (Un, Şeker, Tuz, Sıvı Yağ, Pirinç, Bulgur, Makarna, Nohut, Mercimek, Salça, Baharat, Sirke, Turşu, Konserve)
      5. "Atıştırmalık": (Çikolata, Cips, Bisküvi, Kek, Gofret, Kuruyemiş, Dondurma)
      6. "İçecekler": (Su, Kola, Gazoz, Meyve Suyu, Çay, Kahve, Soda, Maden Suyu)
      7. "Diğer": (Sadece yukarıdakilere uymayan YENEBİLİR gıdalar)

      VERİ FORMATI (JSON):
      - "product_name": Ürünün genel adı (Markasız. Örn: "Tavuk Baget").
      - "brand": Marka (Örn: "Banvit"). Yoksa null.
      - "price": Son fiyat (Sayı).
      - "amount" & "unit": Miktar ve birim (Bulamazsan 1 adet).
      - "days_to_expire": Tahmini raf ömrü (gün).

      CEVAP ÖRNEĞİ:
      {
        "market_name": "MIGROS",
        "items": [
          {"product_name": "Tavuk Bonfile", "brand": "Banvit", "category": "Et & Tavuk & Balık", "price": 150.00, "days_to_expire": 4, "amount": 1, "unit": "paket"},
          {"product_name": "Yumurta", "brand": "Koru", "category": "Süt & Kahvaltılık", "price": 45.50, "days_to_expire": 21, "amount": 15, "unit": "adet"}
        ]
      }
      ''';

      final safetySettings = [
        {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
        {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
        {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
        {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"}
      ];

      final body = jsonEncode({
        "contents": [{"parts": [{"text": prompt}, {"inline_data": {"mime_type": "image/jpeg", "data": base64Image}}]}],
        "safetySettings": safetySettings,
        "generationConfig": {"temperature": 0.1, "responseMimeType": "application/json"}
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] == null || (data['candidates'] as List).isEmpty) return {};

        String content = data['candidates'][0]['content']['parts'][0]['text'];
        
        final jsonMatch = RegExp(r'\{[\s\S]*\}', dotAll: true).firstMatch(content);

        if (jsonMatch != null) {
          String cleanJson = jsonMatch.group(0)!;
          try {
            Map<String, dynamic> resultData = jsonDecode(cleanJson);
            lastScannedResult = resultData;
            debugPrint("✅ Gıda Odaklı Okuma Başarılı: ${resultData['items'].length} ürün.");
            return resultData;
          } catch (e) {
            debugPrint("❌ JSON Parse Hatası: $e");
            return {};
          }
        } else {
          debugPrint("❌ JSON bulunamadı.");
          return {};
        }
      } else {
        debugPrint("❌ HTTP HATA: ${response.statusCode}");
        return {};
      }
    } catch (e) {
      debugPrint("🔥 HATA: $e");
      return {};
    }
  }
}