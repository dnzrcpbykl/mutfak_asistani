import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MarketUtils {
  // ... (getLogoPath ve getMarketColor fonksiyonları aynı kalabilir) ...

  static String getLogoPath(String marketName) {
    final name = marketName.toLowerCase().trim();
    if (name.contains('bim')) return 'assets/markets/bim.png';
    if (name.contains('a101')) return 'assets/markets/a101.png';
    if (name.contains('şok') || name.contains('sok')) return 'assets/markets/sok.png';
    if (name.contains('migros')) return 'assets/markets/migros.png';
    if (name.contains('carrefoursa')) return 'assets/markets/carrefoursa.png';
    if (name.contains('tarim_kredi')) return 'assets/markets/tarim_kredi.png';
    
    return ''; 
  }

  // Market Linkini Açma (DÜZELTİLMİŞ HALİ)
  static Future<void> launchMarketLink(String marketName) async {
    String url = "";
    // Türkçe karakter sorununu (I-i / İ-i) garantiye almak için küçük harfe çeviriyoruz
    final name = marketName.toLowerCase().trim();

    debugPrint("🔗 Link deneniyor: Gelen isim -> $name"); // Konsoldan takip et

    // BLOKLARI SÜSLÜ PARANTEZ İÇİNE ALDIK (Mavi çizgi gider)
    if (name.contains('bim')) {
      url = "https://www.bim.com.tr/";
    } else if (name.contains('a101')) {
      url = "https://www.a101.com.tr/kapida";
    } else if (name.contains('şok') || name.contains('sok')) {
      url = "https://www.sokmarket.com.tr/";
    } else if (name.contains('migros')) {
      url = "https://www.migros.com.tr/";
    } else if (name.contains('carrefoursa')) {
      url = "https://www.carrefoursa.com/";
    } else if (name.contains('tarim_kredi')) {
      url = "https://www.tkkoop.com.tr/";
    }

    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          debugPrint("❌ Link açılamıyor (Tarayıcı bulunamadı veya izin yok): $url");
        }
      } catch (e) {
        debugPrint("❌ Hata oluştu: $e");
      }
    } else {
      debugPrint("⚠️ Bu market için tanımlı link yok: $marketName");
    }
  }
}