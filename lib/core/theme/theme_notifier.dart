import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // KAYIT İÇİN EKLENDİ

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode;

  // 1. Constructor (Kurucu) değiştirdik:
  // Artık dışarıdan "isDark" bilgisini alarak başlıyor.
  ThemeNotifier(bool isDark) : _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }
    notifyListeners();

    // 2. Değişikliği Kalıcı Hafızaya Yazıyoruz:
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);
  }
}