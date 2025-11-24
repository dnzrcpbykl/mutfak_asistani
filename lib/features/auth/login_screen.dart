// lib/features/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Veritabanı için gerekli
import 'package:intl/intl.dart'; // Tarih formatı için
import '../home/main_layout.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Mod Kontrolü (Giriş mi Kayıt mı?)
  bool _isLogin = true; 
  bool _isLoading = false;

  // Form Kontrolcüleri
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _dobController = TextEditingController(); // Doğum tarihi (Görsel için)
  
  DateTime? _selectedDate; // Doğum tarihi (Veri için)

  // --- TARİH SEÇİCİ ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        // Takvim temasını da uygulamaya uyduralım
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  // --- ANA İŞLEM FONKSİYONU ---
  Future<void> _submitForm() async {
    // 1. Basit Validasyonlar
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("E-posta ve şifre zorunludur.");
      return;
    }

    if (!_isLogin) {
      // Kayıt modundaysak ek kontroller
      if (_nameController.text.isEmpty || 
          _surnameController.text.isEmpty || 
          _usernameController.text.isEmpty || 
          _selectedDate == null) {
        _showError("Lütfen tüm alanları doldurun.");
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // --- GİRİŞ YAPMA ---
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // --- KAYIT OLMA ---
        // 1. Auth'a Kayıt
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // 2. Firestore'a Ek Bilgileri Kaydet
        if (userCredential.user != null) {
          await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
            'name': _nameController.text.trim(),
            'surname': _surnameController.text.trim(),
            'username': _usernameController.text.trim(),
            'email': _emailController.text.trim(),
            'birthDate': Timestamp.fromDate(_selectedDate!), // Timestamp olarak kaydet
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Başarılıysa Yönlendir
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainLayout()),
      );

    } on FirebaseAuthException catch (e) {
      String message = "Bir hata oluştu.";
      if (e.code == 'user-not-found') {
        message = "Kullanıcı bulunamadı.";
      // ignore: curly_braces_in_flow_control_structures
      } else if (e.code == 'wrong-password') message = "Şifre hatalı.";
      // ignore: curly_braces_in_flow_control_structures
      else if (e.code == 'email-already-in-use') message = "Bu e-posta zaten kullanımda.";
      else if (e.code == 'weak-password') message = "Şifre çok zayıf.";
      
      _showError(message);
    } catch (e) {
      _showError("Hata: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: Theme.of(context).colorScheme.error
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tema verileri (Dinamik)
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- LOGO ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.surface,
                  border: Border.all(color: colorScheme.primary, width: 2),
                  boxShadow: [
                    BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 20)
                  ]
                ),
                child: Icon(Icons.smart_toy, size: 60, color: colorScheme.primary),
              ),
              const SizedBox(height: 20),
              
              Text("Mutfak Asistanı", 
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface
                )
              ),
              Text(
                _isLogin ? "Tekrar Hoşgeldin Şef!" : "Aramıza Katıl", 
                style: TextStyle(color: colorScheme.secondary, fontSize: 16)
              ),
              
              const SizedBox(height: 30),
              
              // --- FORM ALANLARI ---
              // Sadece Kayıt Modunda Görünen Alanlar
              if (!_isLogin) ...[
                Row(
                  children: [
                    Expanded(child: _buildTextField("İsim", Icons.person, _nameController)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField("Soyisim", Icons.person_outline, _surnameController)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField("Kullanıcı Adı", Icons.alternate_email, _usernameController),
                const SizedBox(height: 16),
                
                // Doğum Tarihi Seçici
                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: AbsorbPointer(
                    child: TextField(
                      controller: _dobController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: const InputDecoration(
                        labelText: "Doğum Tarihi",
                        prefixIcon: Icon(Icons.calendar_today),
                        hintText: "GG/AA/YYYY",
                        // Tema dosyasındaki input stili otomatik uygulanır
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Her İki Modda Görünen Alanlar
              _buildTextField("E-posta Adresi", Icons.email_outlined, _emailController, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildTextField("Şifre", Icons.lock_outline, _passwordController, isObscure: true),
              
              const SizedBox(height: 30),

              // --- BUTONLAR ---
              _isLoading
                  ? CircularProgressIndicator(color: colorScheme.primary)
                  : Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitForm,
                            child: Text(
                              _isLogin ? "Giriş Yap" : "Kayıt Ol",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Mod Değiştirme Butonu
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLogin = !_isLogin; // Modu tersine çevir
                              // Hata mesajlarını temizlemek istersen controller'ları burada temizleyebilirsin
                            });
                          },
                          child: RichText(
                            text: TextSpan(
                              text: _isLogin ? "Hesabın yok mu? " : "Zaten hesabın var mı? ",
                              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
                              children: [
                                TextSpan(
                                  text: _isLogin ? "Kayıt Ol" : "Giriş Yap",
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // Yardımcı Widget: TextField Oluşturucu (Kod tekrarını önlemek için)
  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {bool isObscure = false, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface), // Yazı rengi dinamik
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}