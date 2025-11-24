// lib/core/theme/theme_notifier.dart
import 'package:flutter/material.dart';

class ThemeNotifier extends ChangeNotifier {
  // Varsayılan olarak Dark Mod ile başla
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  // Modun ne olduğunu soran yardımcı
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // Temayı Değiştir (Toggle)
  void toggleTheme() {
    if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }
    // Tüm uygulamaya "Ben değiştim, yenilenin!" diye haber ver
    notifyListeners();
  }
}