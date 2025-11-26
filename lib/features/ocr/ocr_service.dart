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
      Bu market fişini analiz et ve aşağıdaki katı kurallara göre JSON formatında döndür.

      GÖREV 1: MARKET TESPİTİ
      "BIM", "A101", "SOK", "MIGROS", "CARREFOURSA" veya "DIGER".

      GÖREV 2: SADECE GIDA ÜRÜNLERİNİ AYIKLA
      Listeye SADECE insanın yiyip içebileceği GIDA ürünlerini al.
      ❌ Temizlik, Kişisel Bakım, Kağıt Ürünleri, Mutfak Gereçleri, Hayvan Mamaları, Poşet, İndirim, KDV satırlarını KESİNLİKLE GÖRMEZDEN GEL.

      GÖREV 3: MİKTAR VE BİRİM ANALİZİ (EN ÖNEMLİ KISIM)
      Fişte yazan miktarları ve birimleri şu mantıkla dönüştür:
      
      A) ÇOKLU PAKETLERİ AÇ (Multipacks):
         - Fişte "4x1L Süt" veya "6x200ml Meyve Suyu" yazıyorsa:
           -> amount: 4 (veya 6), unit: "adet".
           -> product_name: "Süt (1L)" veya "Meyve Suyu (200ml)".
           (Yani paketi patlat, içindeki adet sayısını 'amount' olarak ver.)

      B) BOYUTU MİKTAR SANMA (Size Confusion):
         - Fişte "PİRİNÇ 2.5KG" veya "GAZOZ 2.5L" yazıyorsa, buradaki 2.5 ürünün boyutudur, adedi DEĞİLDİR.
           -> amount: 1 (Eğer başında '2 AD' yazmıyorsa 1 kabul et).
           -> unit: "adet".
           -> product_name: "Pirinç (2.5kg)" veya "Gazoz (2.5L)".
      
      C) ADETLİ ÜRÜNLER:
         - Fişte "2 AD X 15.00" şeklinde satır varsa 'amount' 2 olmalıdır.

      GÖREV 4: KATEGORİLENDİRME
      1. "Et & Tavuk & Balık": (Kıyma, Tavuk, Balık, Sucuk, Sosis vb.)
      2. "Süt & Kahvaltılık": (Süt, Peynir, Yoğurt, Yumurta, Tereyağı, Zeytin vb.)
      3. "Meyve & Sebze": (Domates, Biber, Soğan, Meyveler vb.)
      4. "Temel Gıda & Bakliyat": (Un, Şeker, Tuz, Yağ, Pirinç, Makarna, Salça vb.)
      5. "Atıştırmalık": (Çikolata, Cips, Bisküvi, Kuruyemiş, Dondurma vb.)
      6. "İçecekler": (Su, Kola, Gazoz, Çay, Kahve vb.)
      7. "Diğer": (Diğer yenebilir gıdalar)

      VERİ FORMATI (JSON):
      - "product_name": Ürünün adı (Boyut bilgisi parantez içinde olsun. Örn: "Tavuk Baget (1kg)"). Markayı isme dahil etme, 'brand' alanına yaz.
      - "brand": Marka (Örn: "Torku", "Pınar"). Yoksa null.
      - "price": Son fiyat (Sayı).
      - "amount": Toplam adet (Sayı).
      - "unit": Sadece "adet" kullan. (Litre veya Kg olsa bile 'adet' yaz, boyutu isme parantez içine ekle).
      - "days_to_expire": Tahmini raf ömrü (gün).

      CEVAP ÖRNEĞİ:
      {
        "market_name": "MIGROS",
        "items": [
          {"product_name": "Yağlı Süt (1L)", "brand": "Torku", "category": "Süt & Kahvaltılık", "price": 100.00, "days_to_expire": 7, "amount": 4, "unit": "adet"},
          {"product_name": "Baldo Pirinç (2.5kg)", "brand": "Efsane", "category": "Temel Gıda & Bakliyat", "price": 135.00, "days_to_expire": 365, "amount": 1, "unit": "adet"}
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