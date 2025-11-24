import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // <--- Provider eklendi

import 'features/auth/login_screen.dart';
import 'features/home/main_layout.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart'; // <--- Notifier eklendi

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  runApp(
    // Uygulamayı Provider ile sarmalıyoruz
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const MutfakAsistaniApp(),
    ),
  );
}

class MutfakAsistaniApp extends StatelessWidget {
  const MutfakAsistaniApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Provider'dan o anki tema durumunu dinliyoruz
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return MaterialApp(
      title: 'Mutfak Asistanı',
      debugShowCheckedModeBanner: false,
      
      // Temaları tanımlıyoruz
      theme: AppTheme.lightTheme, 
      darkTheme: AppTheme.darkTheme,
      
      // Hangi modda olacağını Provider belirliyor
      themeMode: themeNotifier.themeMode, 

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Scaffold(body: Center(child: CircularProgressIndicator()));
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