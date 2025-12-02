// lib/features/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../home/main_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Mod Kontrolü
  bool _isLogin = true;
  bool _isLoading = false;
  bool _isKvkkAccepted = false; // KVKK Onay Durumu

  // Hata Mesajı
  String? _errorMessage;

  // Form Kontrolcüleri
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _dobController = TextEditingController();

  DateTime? _selectedDate;

  // --- TARİH SEÇİCİ ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
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

  // --- KVKK AYDINLATMA METNİ PENCERESİ ---
  void _showKvkkDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                  child: Text("Aydınlatma Metni & Gizlilik",
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold))),
              const SizedBox(height: 20),
              const Text(
                """
1. VERİ SORUMLUSU
Bu uygulama ("Mutfak Asistanı"), kişisel verilerinizi KVKK ve GDPR kapsamında korumayı taahhüt eder.

2. İŞLENEN KİŞİSEL VERİLER
- Kimlik Bilgileri: Ad, Soyad, Doğum Tarihi.
- İletişim Bilgileri: E-posta adresi.
- Kullanım Verileri: Kiler envanteri, taranan fiş verileri, oluşturulan alışveriş listeleri.

3. VERİ İŞLEME AMACI
- Size kişiselleştirilmiş yemek tarifleri sunmak (AI destekli).
- Son kullanma tarihi yaklaşan ürünler için bildirim göndermek.
- Alışveriş alışkanlıklarınıza dair istatistikler oluşturmak.

4. VERİLERİN AKTARILMASI
Verileriniz, hizmetin sağlanması amacıyla güvenli bulut sunucularında (Firebase) saklanmaktadır.
AI işlemleri için veriler anonimleştirilerek işleme tabi tutulabilir. Yasal zorunluluklar dışında üçüncü kişilerle paylaşılmaz.

5. HAKLARINIZ
Dilediğiniz zaman "Ayarlar" menüsünden hesabınızı ve tüm verilerinizi kalıcı olarak silebilirsiniz.
""",
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Okudum, Anladım"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- YENİ EKLENEN: ŞİFRE SIFIRLAMA DİYALOGU ---
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    // Eğer giriş ekranında e-posta zaten yazılıysa, kolaylık olsun diye buraya da taşıyalım
    if (_emailController.text.isNotEmpty) {
      resetEmailController.text = _emailController.text;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: const Text("Şifre Sıfırlama"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                "Hesabınıza ait e-posta adresinizi girin. Size bir sıfırlama bağlantısı göndereceğiz."),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "E-posta Adresi",
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Lütfen e-posta adresinizi girin.")),
                );
                return;
              }

              try {
                // Firebase şifre sıfırlama maili gönder
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: email);
                if (mounted) {
                  Navigator.pop(context); // Pencereyi kapat
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          "Sıfırlama bağlantısı e-posta adresinize gönderildi!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } on FirebaseAuthException catch (e) {
                String errorMsg = "Bir hata oluştu.";
                if (e.code == 'user-not-found')
                  errorMsg = "Bu e-posta ile kayıtlı kullanıcı bulunamadı.";
                if (e.code == 'invalid-email')
                  errorMsg = "Geçersiz e-posta formatı.";

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(errorMsg), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Gönder"),
          ),
        ],
      ),
    );
  }

  // --- ANA İŞLEM FONKSİYONU ---
  Future<void> _submitForm() async {
    // 1. Hata temizle
    setState(() {
      _errorMessage = null;
    });

    // 2. Zorunlu Alan Kontrolü
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = "E-posta ve şifre zorunludur.");
      return;
    }

    if (!_isLogin) {
      if (_nameController.text.isEmpty ||
          _surnameController.text.isEmpty ||
          _usernameController.text.isEmpty ||
          _selectedDate == null) {
        setState(
            () => _errorMessage = "Lütfen tüm alanları eksiksiz doldurun.");
        return;
      }

      // KVKK KONTROLÜ (Sadece kayıt olurken)
      if (!_isKvkkAccepted) {
        setState(() => _errorMessage =
            "Kayıt olmak için Aydınlatma Metni'ni onaylamanız gerekmektedir.");
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
        final userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // Firestore'a Ek Bilgileri Kaydet
        if (userCredential.user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
            'name': _nameController.text.trim(),
            'surname': _surnameController.text.trim(),
            'username': _usernameController.text.trim(),
            'email': _emailController.text.trim(),
            'birthDate': Timestamp.fromDate(_selectedDate!),
            'createdAt': FieldValue.serverTimestamp(),
            'kvkkAccepted': true, // Onay bilgisini de kaydedelim
            'kvkkAcceptedAt': FieldValue.serverTimestamp(),
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
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = "E-posta veya şifre yanlıştır.";
      } else if (e.code == 'email-already-in-use') {
        message = "Bu e-posta zaten kullanımda.";
      } else if (e.code == 'weak-password') {
        message = "Şifre çok zayıf.";
      } else if (e.code == 'invalid-email') {
        message = "Geçersiz e-posta formatı.";
      }

      setState(() => _errorMessage = message);
    } catch (e) {
      setState(() => _errorMessage = "Beklenmedik bir hata: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
        body: GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Center(
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
                      BoxShadow(
                          color: colorScheme.primary.withOpacity(0.3),
                          blurRadius: 20)
                    ]),
                child: Icon(Icons.smart_toy,
                    size: 60, color: colorScheme.primary),
              ),
              const SizedBox(height: 20),

              Text("Mutfak Asistanı",
                  style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface)),
              Text(
                  _isLogin ? "Tekrar Hoşgeldin Şef!" : "Aramıza Katıl",
                  style:
                      TextStyle(color: colorScheme.secondary, fontSize: 16)),

              const SizedBox(height: 30),

              // --- FORM ALANLARI ---
              if (!_isLogin) ...[
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(
                            "İsim", Icons.person, _nameController)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildTextField("Soyisim",
                            Icons.person_outline, _surnameController)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField("Kullanıcı Adı", Icons.alternate_email,
                    _usernameController),
                const SizedBox(height: 16),
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
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _buildTextField("E-posta Adresi", Icons.email_outlined,
                  _emailController,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildTextField(
                  "Şifre", Icons.lock_outline, _passwordController,
                  isObscure: true),

              // --- YENİ EKLENEN: ŞİFREMİ UNUTTUM BUTONU ---
              // Sadece Giriş Modunda (_isLogin) gösterilir
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 4),
                      foregroundColor: colorScheme.secondary,
                    ),
                    child: const Text("Şifremi Unuttum?",
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              // ---------------------------------------------

              // --- KVKK CHECKBOX (Sadece Kayıt Olurken) ---
              if (!_isLogin) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: _isKvkkAccepted,
                      activeColor: colorScheme.primary,
                      onChanged: (val) =>
                          setState(() => _isKvkkAccepted = val ?? false),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showKvkkDialog, // Yazıya tıklayınca metni aç
                        child: RichText(
                          text: TextSpan(
                            text: "Kişisel verilerimin işlenmesine ilişkin ",
                            style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.7),
                                fontSize: 12),
                            children: [
                              TextSpan(
                                text: "Aydınlatma Metni",
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const TextSpan(
                                  text: "'ni okudum ve kabul ediyorum."),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

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
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        // --- HATA MESAJI KUTUSU ---
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: colorScheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: colorScheme.error.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: colorScheme.error),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: colorScheme.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _errorMessage = null;
                              // Mod değişince checkbox'ı sıfırla
                              _isKvkkAccepted = false;
                            });
                          },
                          child: RichText(
                            text: TextSpan(
                              text: _isLogin
                                  ? "Hesabın yok mu? "
                                  : "Zaten hesabın var mı? ",
                              style: TextStyle(
                                  color: colorScheme.onSurface
                                      .withOpacity(0.7)),
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
              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildTextField(
      String label, IconData icon, TextEditingController controller,
      {bool isObscure = false, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}