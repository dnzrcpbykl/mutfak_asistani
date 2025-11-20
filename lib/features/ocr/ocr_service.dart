import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../secrets.dart'; // veya import 'package:mutfak_asistani/secrets.dart';

class OCRService {

static const String _apiKey = Secrets.geminiApiKey; // YENİSİ
  static List<String> lastScannedList = [];

  Future<String?> pickImageFromCamera() async {
    final ImagePicker picker = ImagePicker();
    // Test için Gallery, gerçek kullanımda Camera yapabilirsin
    final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
    return photo?.path;
  }

  Future<List<String>> textToIngredients(String imagePath) async {
    debugPrint("🚀 Gemini (HTTP) İşlemi Başladı...");

    try {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);

      // DÜZELTME: Model isminin sonuna '-latest' ekledik.
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$_apiKey');

      final headers = {'Content-Type': 'application/json'};

      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text": "Bu bir market fişi. Fotoğrafı analiz et ve SADECE gıda ve temizlik ürünlerinin isimlerini temiz bir liste olarak ver. Fiyatları, tarihleri, mağaza adını, adresleri, KDV ve toplam tutarları yoksay. Marka isimleri kalabilir. Cevabında sadece ürün isimleri olsun, her satıra bir ürün yaz."
              },
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }
        ]
      });

      final response = await http.post(url, headers: headers, body: body);

      debugPrint("📡 Sunucu Cevap Kodu: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Google'ın yapısına göre cevabı çekiyoruz
        final String content = data['candidates'][0]['content']['parts'][0]['text'];
        
        debugPrint("🤖 Gemini Cevabı:\n$content");

        List<String> ingredients = content
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty && e.length > 2)
            .map((e) => e.replaceAll(RegExp(r'^[-*•]\s*'), '')) 
            .toList();

            lastScannedList = ingredients;

        return ingredients;
      } else {
        debugPrint("❌ HATA: ${response.body}");
        return ["Bağlantı Hatası: ${response.statusCode}"];
      }

    } catch (e) {
      debugPrint("🔥 KRİTİK HATA: $e");
      return ["Hata Oluştu"];
    }
  }
}