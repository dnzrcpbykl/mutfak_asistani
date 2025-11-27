import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WeatherService {
  // WeatherAPI.com'dan aldığınız API Key'i buraya yapıştırın.
  String get apiKey => dotenv.env['WEATHER_API_KEY'] ?? ''; 

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Servis açık mı kontrol et
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Konum servisi kapalı.');
    }

    // İzinleri kontrol et
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Konum izni reddedildi.');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Konum izni kalıcı olarak engellendi.');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<Map<String, dynamic>> getWeather() async {
    try {
      Position position = await _determinePosition();
      
      // WeatherAPI.com Endpoint (lang=tr ile Türkçe veri çekiyoruz)
      final url = Uri.parse(
          'http://api.weatherapi.com/v1/current.json?key=$apiKey&q=${position.latitude},${position.longitude}&lang=tr');
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // WeatherAPI'den gelen veriyi parse ediyoruz
        String conditionText = data['current']['condition']['text'];
        double tempC = data['current']['temp_c'];
        String cityName = data['location']['name'];

        // UI tarafındaki ikon mantığının bozulmaması için 'main' parametresini
        // Türkçe metne göre İngilizce anahtar kelimelere çeviriyoruz.
        String mainCondition = "Clear"; 
        String lowerCondition = conditionText.toLowerCase();
        
        if (lowerCondition.contains("yağmur") || lowerCondition.contains("sağanak")) {
          mainCondition = "Rain";
        } else if (lowerCondition.contains("kar")) {
          mainCondition = "Snow";
        } else if (lowerCondition.contains("bulut") || lowerCondition.contains("kapalı")) {
          mainCondition = "Clouds";
        }

        return {
          'temp': tempC.round(),
          'description': conditionText, // Örn: "Parçalı Bulutlu"
          'main': mainCondition, // UI'daki ikon seçimi için (Rain, Clear vb.)
          'city': cityName,
          'success': true
        };
      } else {
        return {'success': false, 'error': 'Hava durumu alınamadı (Kod: ${response.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Havaya Göre Şefin Tavsiyesi
  String getSuggestion(String mainCondition, int temp) {
    // Önce sıcaklığa bak
    if (temp < 5) return "Brrr! Hava buz gibi ❄️ Fırını çalıştırıp evi ısıtacak bir yemek yap.";
    if (temp < 12) return "Serin bir gün 🧣 Sıcak bir çorba veya güveç harika gider.";
    if (temp > 30) return "Çok sıcak! ☀️ Ocağı fazla yakma, salata veya soğuk sandviç yap.";
    
    // Sonra hava durumuna bak (Main parametresi yukarıda ürettiğimiz İngilizce kod)
    if (mainCondition == "Rain") return "Dışarısı yağmurlu 🌧️ Çayını demle, kurabiye yap.";
    if (mainCondition == "Snow") return "Kar yağıyor! ☃️ Sahlep veya sıcak çikolata zamanı.";
    if (mainCondition == "Clouds") return "Hava kapalı ☁️ Mutfağı renklendirecek bir tatlıya ne dersin?";
    
    return "Hava mis gibi! ☀️ Taze sebzelerle harikalar yaratabilirsin.";
  }
}