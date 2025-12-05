// lib/features/home/weather_provider.dart

import 'package:flutter/material.dart';
import 'weather_service.dart';

class WeatherProvider extends ChangeNotifier {
  final WeatherService _service = WeatherService();
  
  Map<String, dynamic>? _weatherData;
  DateTime? _lastFetchTime;
  bool _isLoading = false;

  Map<String, dynamic>? get weatherData => _weatherData;
  bool get isLoading => _isLoading;

  // Veriyi getirme fonksiyonu
  Future<void> fetchWeather() async {
    // 1. KONTROL: Eğer veri varsa VE son güncelleme üzerinden 2 saat geçmediyse TEKRAR ÇEKME.
    if (_weatherData != null && _lastFetchTime != null) {
      final difference = DateTime.now().difference(_lastFetchTime!);
      // "2" yerine "24" yazarsan günde 1 kere çeker. Ancak hava durumu için 2-3 saat idealdir.
      if (difference.inHours < 2) {
        return; // Hafızadaki veriyi kullan, API'ye gitme.
      }
    }

    // Veri yoksa veya süre dolduysa API'ye git
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _service.getWeather();
      if (data['success'] == true) {
        _weatherData = data;
        _lastFetchTime = DateTime.now(); // Zaman damgasını güncelle
      }
    } catch (e) {
      debugPrint("Hava durumu hatası: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}