import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; 
import 'features/recipes/recipe_provider.dart';

import 'features/auth/login_screen.dart';
import 'features/home/main_layout.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'features/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // 1. SharedPreferences'i başlatıp kayıtlı veriyi çekiyoruz
  final prefs = await SharedPreferences.getInstance();
  // Eğer daha önce kayıt yoksa varsayılan olarak 'false' (görülmedi) kabul et
  final bool seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
  final bool isDarkMode = prefs.getBool('isDarkMode') ?? true;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier(isDarkMode)),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
      ],
      // 2. Çektiğimiz 'seenOnboarding' verisini uygulamaya gönderiyoruz
      // (Buradaki 'const' ifadesini kaldırdık çünkü değer dinamik)
      child: MutfakAsistaniApp(seenOnboarding: seenOnboarding),
    ),
  );
}

class MutfakAsistaniApp extends StatelessWidget {
  // 3. Değişkeni burada tanımlıyoruz
  final bool seenOnboarding;
  
  // Constructor'da bu değeri zorunlu kılıyoruz
  const MutfakAsistaniApp({super.key, required this.seenOnboarding});

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

          if (!seenOnboarding) {
            return const OnboardingScreen();
          }
          
          if (snapshot.hasData) {
            return const MainLayout();
          }
          
          return const LoginScreen();
          
        },
      ),
    );
  }
}