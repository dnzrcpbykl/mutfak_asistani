import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import '../../secrets.dart'; // Bu dosyanın olduğundan emin ol, yoksa API KEY'i direkt buraya string olarak yaz.

class OCRService {
  // API Key'i Secrets dosyasından çekiyoruz. Eğer hata verirse buraya direkt "AIza..." şeklinde yazabilirsin.
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
      // --- BELLEK YÖNETİMİ & SIKIŞTIRMA ---
      // Hata almamak için varsayılan olarak orijinal dosyayı atıyoruz.
      File fileToUpload = File(imagePath); 

      try {
        final dir = await path_provider.getTemporaryDirectory();
        final targetPath = '${dir.absolute.path}/ocr_temp_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
          imagePath,
          targetPath,
          minWidth: 1024,
          minHeight: 1024,
          quality: 75,
          format: CompressFormat.jpeg,
        );

        if (compressedFile != null) {
          fileToUpload = File(compressedFile.path);
          debugPrint("✅ Resim sıkıştırıldı. Orijinal: ${File(imagePath).lengthSync()} byte -> Yeni: ${fileToUpload.lengthSync()} byte");
        }
      } catch (e) {
        debugPrint("⚠️ Sıkıştırma hatası (Önemsiz, orijinal dosya kullanılacak): $e");
        // Hata durumunda fileToUpload zaten orijinal dosya olarak tanımlı.
      }

      // Dosyayı Byte'a çevir
      final bytes = await fileToUpload.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$_apiKey');
      
      final headers = {'Content-Type': 'application/json'};

      // --- İSTEM (PROMPT) ---
      const prompt = '''
      Bu market fişini analiz et ve aşağıdaki katı kurallara göre JSON formatında döndür.

      GÖREV 1: MARKET TESPİTİ
      "BIM", "A101", "SOK", "MIGROS", "CARREFOURSA" veya "DIGER".

      GÖREV 2: SADECE GIDA ÜRÜNLERİNİ AYIKLA
      Listeye SADECE insanın yiyip içebileceği GIDA ürünlerini al.
      ❌ Temizlik, Kişisel Bakım, Kağıt Ürünleri, Mutfak Gereçleri, Hayvan Mamaları, Poşet, İndirim, KDV satırlarını KESİNLİKLE GÖRMEZDEN GEL.

      GÖREV 3: MİKTAR VE BİRİM ANALİZİ
      Fişte yazan miktarları ve birimleri şu mantıkla dönüştür:
      A) ÇOKLU PAKETLERİ AÇ: "4x1L Süt" -> amount: 4, unit: "adet", product_name: "Süt (1L)".
      B) BOYUTU MİKTAR SANMA: "PİRİNÇ 2.5KG" -> amount: 1, unit: "adet", product_name: "Pirinç (2.5kg)".
      C) ADETLİ ÜRÜNLER: "2 AD X 15.00" -> amount: 2.

      GÖREV 4: FİŞ TARİHİ TESPİTİ (ÇOK ÖNEMLİ)
      Fişin üzerinde yazan alışveriş tarihini bul.
      - Tarihi "YYYY-MM-DD" formatına çevir (Örn: 2025-11-29).
      - Eğer tarih okunamazsa bugünün tarihini ver.

      VERİ FORMATI (JSON):
      {
        "market_name": "MARKET ADI",
        "date": "YYYY-MM-DD",
        "items": [
          {
            "product_name": "Ürün Adı",
            "brand": "Marka",
            "price": 10.50,
            "amount": 1,
            "unit": "adet",
            "category": "Temel Gıda",
            "days_to_expire": 7
          }
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
        
        // Güvenlik kontrolü: candidates boş mu?
        if (data['candidates'] == null || (data['candidates'] as List).isEmpty) {
          debugPrint("❌ Gemini boş yanıt döndü.");
          return {};
        }

        String content = data['candidates'][0]['content']['parts'][0]['text'];

        // Markdown temizliği
        content = content.replaceAll(RegExp(r'^```json', multiLine: true), '')
                        .replaceAll(RegExp(r'^```', multiLine: true), '')
                        .trim();

        int startIndex = content.indexOf('{');
        int endIndex = content.lastIndexOf('}');

        if (startIndex != -1 && endIndex != -1) {
          String cleanJson = content.substring(startIndex, endIndex + 1);
          try {
            Map<String, dynamic> resultData = jsonDecode(cleanJson);
            lastScannedResult = resultData;
            debugPrint("✅ Fiş Okundu! Tarih: ${resultData['date']}");
            return resultData;
          } catch (e) {
            debugPrint("❌ JSON Parse Hatası: $e");
            return {};
          }
        } else {
          debugPrint("❌ JSON formatı bulunamadı. Gelen: $content");
          return {};
        }
      } else {
        debugPrint("❌ HTTP HATA: ${response.statusCode} - ${response.body}");
        return {};
      }
    } catch (e) {
      debugPrint("🔥 GENEL HATA: $e");
      return {};
    }
  }
}