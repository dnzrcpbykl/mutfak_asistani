import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- RENK PALETİ (İKONUNDAN ALINDI) ---
  
  // Robotun yüzündeki koyu ekran rengi (Zemin)
  static const Color darkBackground = Color(0xFF1A1A2E); 
  
  // Robotun gözlerindeki neon turkuaz (Ana Teknoloji Rengi)
  static const Color neonCyan = Color(0xFF00E5FF);
  
  // Robotun gövdesindeki şeftali tonu (Sıcaklık/Vurgu)
  static const Color softPeach = Color(0xFFFFCCBC);
  
  // Kartlar için biraz daha açık bir koyu ton
  static const Color surfaceDark = Color(0xFF252538);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: neonCyan,
      
      // Renk Şeması
      colorScheme: const ColorScheme.dark(
        primary: neonCyan,
        onPrimary: Colors.black, // Cyan üstüne siyah yazı okunur
        secondary: softPeach,
        onSecondary: Colors.black, // Şeftali üstüne siyah yazı
        surface: surfaceDark,
        onSurface: Colors.white,
        error: Color(0xFFFF5252),
      ),

      // Yazı Tipi (Google Fonts - Outfit veya Poppins çok modern durur)
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: Colors.white70,
        displayColor: Colors.white,
      ),

      // Kart Tasarımı (Glassmorphism hissiyatı için)
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0, // Düz modern görünüm
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // Robotun yuvarlak hatları gibi
          side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1), // İnce bir çerçeve
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),

      // App Bar Tasarımı
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent, // Şeffaf
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        iconTheme: IconThemeData(color: softPeach),
      ),

      // Buton Tasarımı (Elevated Button)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonCyan,
          foregroundColor: Colors.black,
          elevation: 5,
          // Butonların mobilde daha rahat basılması için minimum yükseklik
          minimumSize: const Size(0, 54), 
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),

      // TextButton (Sıcak renk kullanalım)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: softPeach,
        ),
      ),

      // Input (Form) Alanları
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        contentPadding: const EdgeInsets.all(20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: neonCyan, width: 2), // Odaklanınca parlasın
        ),
        prefixIconColor: Colors.grey,
        labelStyle: const TextStyle(color: Colors.grey),
      ),

      // Alt Menü (Bottom Navigation)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkBackground,
        indicatorColor: neonCyan.withOpacity(0.2),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: neonCyan);
          }
          return const IconThemeData(color: Colors.grey);
        }),
      ),
      
      
      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: softPeach,
        foregroundColor: Colors.black,
      ),
    );
  }

  // ... darkTheme kodları bittikten sonra ...

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F5F7), // Hafif gri beyaz (Apple stili)
      primaryColor: neonCyan,

      colorScheme: const ColorScheme.light(
        primary: neonCyan,
        onPrimary: Colors.black,
        secondary: softPeach,
        onSecondary: Colors.black,
        surface: Colors.white,
        onSurface: Colors.black87,
        error: Color(0xFFFF5252),
      ),

      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: Colors.black87,
        displayColor: Colors.black,
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      
      // Light modda input alanları
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: neonCyan, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
           borderRadius: BorderRadius.circular(16),
           borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),

      // Diğer buton stilleri Dark tema ile aynı kalabilir veya özelleştirilebilir
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonCyan,
          foregroundColor: Colors.black,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      ),
      
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: neonCyan.withOpacity(0.3),
        surfaceTintColor: Colors.white,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Colors.black);
          }
          return const IconThemeData(color: Colors.grey);
        }),
      ),
    );
  }

  static Color? get primaryCyan => null;
}