import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Auth paketi gerekli
import 'features/auth/login_screen.dart';
import 'features/home/main_layout.dart'; // Ana iskeletimiz

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MutfakAsistaniApp());
}

class MutfakAsistaniApp extends StatelessWidget {
  const MutfakAsistaniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mutfak Asistanı',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      // --- İŞTE SİHİRLİ KISIM BURASI ---
      home: StreamBuilder<User?>(
        // Firebase'in "Oturum Durumu"nu canlı dinle
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Eğer bağlantı bekleniyorsa boş bir yükleme ekranı gösterebiliriz
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          // 1. Kullanıcı verisi varsa (Daha önce girmişse) -> Ana Sayfaya (Menüye) git
          if (snapshot.hasData) {
            return const MainLayout();
          }
          
          // 2. Yoksa -> Giriş Ekranına git
          return const LoginScreen();
        },
      ),
    );
  }
}