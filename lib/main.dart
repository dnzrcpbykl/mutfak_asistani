import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Güvenlik için eklemenizi önermiştim
import 'features/recipes/recipe_provider.dart';

import 'features/auth/login_screen.dart';
import 'features/home/main_layout.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/legal/legal_warning_screen.dart'; // YASAL UYARI EKRANI IMPORTU
import 'features/home/weather_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Dotenv yüklemesi (API Key güvenliği için .env kullanıyorsanız)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("DotEnv yüklenemedi: $e");
  }

  // 1. SharedPreferences'i başlatıp kayıtlı verileri çekiyoruz
  final prefs = await SharedPreferences.getInstance();
  
  final bool seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
  final bool isDarkMode = prefs.getBool('isDarkMode') ?? true;
  
  // --- YENİ EKLENEN: Yasal Uyarı Onay Durumu ---
  // Kullanıcı daha önce metni okuyup onayladı mı?
  final bool acceptedLegal = prefs.getBool('acceptedLegalTerms_v1') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier(isDarkMode)),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
      ],
      // 2. Değerleri ana widget'a gönderiyoruz
      child: MutfakAsistaniApp(
        seenOnboarding: seenOnboarding,
        acceptedLegal: acceptedLegal, // YENİ PARAMETRE
      ),
    ),
  );
}

class MutfakAsistaniApp extends StatelessWidget {
  final bool seenOnboarding;
  final bool acceptedLegal; // YENİ DEĞİŞKEN

  // Constructor'da bu değerleri zorunlu kılıyoruz
  const MutfakAsistaniApp({
    super.key, 
    required this.seenOnboarding,
    required this.acceptedLegal, // EKLENDİ
  });

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return MaterialApp(
      title: 'Mutfak Asistanı',
      debugShowCheckedModeBanner: false,
      
      theme: AppTheme.lightTheme, 
      darkTheme: AppTheme.darkTheme,
      themeMode: themeNotifier.themeMode, 

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          // --- AKIŞ SIRALAMASI (ÖNEMLİ) ---

          // 1. ÖNCE YASAL UYARI:
          // Kullanıcı giriş yapmış olsa bile, yasal metni onaylamadıysa
          // (örn: güncelleme sonrası) önce bunu görmeli.
          if (!acceptedLegal) {
            return const LegalWarningScreen();
          }

          // 2. SONRA TANITIM (ONBOARDING):
          // Yasal uyarıyı geçtiyse ama tanıtımı görmediyse.
          if (!seenOnboarding) {
            return const OnboardingScreen();
          }
          
          // 3. GİRİŞ YAPMIŞSA ANA EKRAN:
          if (snapshot.hasData) {
            return const MainLayout();
          }
          
          // 4. GİRİŞ YAPMAMIŞSA LOGIN:
          return const LoginScreen();
          
        },
      ),
    );
  }
}