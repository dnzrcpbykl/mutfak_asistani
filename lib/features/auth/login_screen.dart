import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mutfak_asistani/features/home/main_layout.dart'; // Ana sayfa import'u (dosya yoluna dikkat)

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Kullanıcının yazdıklarını tutan kontrolcüler
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Yükleniyor simgesi göstermek için değişken
  bool _isLoading = false;

  // Firebase Giriş Fonksiyonu
  Future<void> _girisYap() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      // Ekran kapandıysa işlemi durdur (Güvenlik)
      if (!mounted) return;

      // Başarılı mesajı
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Giriş Başarılı! Hoşgeldin Şef.")),
      );

      // --- ANA SAYFAYA YÖNLENDİRME (BURASI EKLENDİ) ---
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainLayout()),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: ${e.toString()}")),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Firebase Kayıt Fonksiyonu
  Future<void> _kayitOl() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kayıt Başarılı! Giriş yapılıyor...")),
      );

      // --- ANA SAYFAYA YÖNLENDİRME (DÜZELTİLDİ) ---
      // Sadece hata almazsa buraya gelir ve yönlendirir
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainLayout()),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Kayıt Hatası: ${e.toString()}")),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mutfak Asistanı Giriş")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo veya İkon
            const Icon(Icons.kitchen, size: 100, color: Colors.orange),
            const SizedBox(height: 20),
            
            // E-posta Kutusu
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "E-posta Adresi",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 10),
            
            // Şifre Kutusu
            TextField(
              controller: _passwordController,
              obscureText: true, // Şifreyi gizle
              decoration: const InputDecoration(
                labelText: "Şifre",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 20),

            // Butonlar veya Yükleniyor simgesi
            _isLoading
                ? const CircularProgressIndicator()
                : Column(
                    children: [
                      ElevatedButton(
                        onPressed: _girisYap,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text("Giriş Yap"),
                      ),
                      TextButton(
                        onPressed: _kayitOl,
                        child: const Text("Hesabın yok mu? Kayıt Ol"),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}