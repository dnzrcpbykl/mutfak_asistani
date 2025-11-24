import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BarcodeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _baseUrl = 'https://world.openfoodfacts.org/api/v0/product';

  /// 1. Ürünü Bulma (Önce Firebase, Sonra API)
  Future<String?> findProduct(String barcode) async {
    // A) Önce kendi global havuzumuza bakalım
    try {
      final doc = await _firestore.collection('global_products').doc(barcode).get();
      if (doc.exists && doc.data() != null) {
        debugPrint("✅ Ürün Firebase havuzundan geldi: ${doc.data()!['name']}");
        return doc.data()!['name'] as String;
      }
    } catch (e) {
      debugPrint("Firebase okuma hatası: $e");
    }

    // B) Bizde yoksa OpenFoodFacts API'sine soralım
    String? apiProductName = await _getFromOpenFoodFacts(barcode);
    
    if (apiProductName != null) {
      // API'de bulduysak, hemen kendi havuzumuza kaydedelim (Bir dahaki sefere hızlanır)
      _saveToGlobalPool(barcode, apiProductName);
      return apiProductName;
    }

    // C) Hiçbir yerde yok
    return null;
  }

  /// 2. Kullanıcının girdiği ismi havuza ekleme
  Future<void> contributeToPool(String barcode, String name) async {
    await _saveToGlobalPool(barcode, name);
  }

  // Veritabanına yazma işlemi (CORE İŞLEM BURASI)
  Future<void> _saveToGlobalPool(String barcode, String name) async {
    try {
      // 'global_products' koleksiyonuna, barkodu ID yaparak ekliyoruz.
      // Böylece bir dahaki sefere sorgularken direkt barkod ID'sinden bulacağız.
      await _firestore.collection('global_products').doc(barcode).set({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(), // Ne zaman eklendi?
        'source': 'user_contribution', // Kullanıcı ekledi etiketi (Opsiyonel)
      });
      debugPrint("💾 Ürün veritabanımıza eklendi: $name ($barcode)");
    } catch (e) {
      debugPrint("Havuza ekleme hatası: $e");
    }
  }

  /// Yardımcı: OpenFoodFacts API Sorgusu
  Future<String?> _getFromOpenFoodFacts(String barcode) async {
    try {
      final url = Uri.parse('$_baseUrl/$barcode.json');
      final response = await http.get(
        url,
        headers: {'User-Agent': 'MutfakAsistani/1.0 (com.example.mutfak_asistani)'}, 
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1) {
          final product = data['product'];
          
          // İsim bulma öncelik sırası
          String? name = product['product_name_tr']; // 1. Türkçe isim
          if (name == null || name.isEmpty) name = product['product_name']; // 2. Varsayılan
          if (name == null || name.isEmpty) name = product['generic_name_tr']; // 3. Genel ad
          if (name == null || name.isEmpty) name = product['generic_name'];
          
          // 4. Hiçbiri yoksa Marka adı
          if (name == null || name.isEmpty) {
             String? brand = product['brands'];
             if (brand != null && brand.isNotEmpty) name = "$brand Ürünü";
          }
          return name;
        }
      }
      return null; 
    } catch (e) {
      return null;
    }
  }
}