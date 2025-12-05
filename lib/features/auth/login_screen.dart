// lib/features/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../home/main_layout.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Mod Kontrolü
  bool _isLogin = true;
  bool _isLoading = false;
  bool _isKvkkAccepted = false;

  // Hata Mesajı
  String? _errorMessage;

  // Form Kontrolcüleri
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _usernameController = TextEditingController();
  // _dobController'ı kaldırdık, artık direkt değişken kullanıyoruz.

  DateTime? _selectedDate;
  
  // Konum Verileri
  String? _selectedCountry;
  String? _selectedCity;

  // Örnek Veri Seti
  final Map<String, List<String>> _locationData = {
    "Türkiye": [
      "İstanbul", "Ankara", "İzmir", "Adana", "Adıyaman", "Afyonkarahisar", "Ağrı", "Aksaray", "Amasya", "Antalya", "Ardahan", "Artvin", "Aydın", "Balıkesir", "Bartın", "Batman", "Bayburt", "Bilecik", "Bingöl", "Bitlis", "Bolu", "Burdur", "Bursa", "Çanakkale", "Çankırı", "Çorum", "Denizli", "Diyarbakır", "Düzce", "Edirne", "Elazığ", "Erzincan", "Erzurum", "Eskişehir", "Gaziantep", "Giresun", "Gümüşhane", "Hakkari", "Hatay", "Iğdır", "Isparta", "Kahramanmaraş", "Karabük", "Karaman", "Kars", "Kastamonu", "Kayseri", "Kırıkkale", "Kırklareli", "Kırşehir", "Kilis", "Kocaeli", "Konya", "Kütahya", "Malatya", "Manisa", "Mardin", "Mersin", "Muğla", "Muş", "Nevşehir", "Niğde", "Ordu", "Osmaniye", "Rize", "Sakarya", "Samsun", "Siirt", "Sinop", "Sivas", "Şanlıurfa", "Şırnak", "Tekirdağ", "Tokat", "Trabzon", "Tunceli", "Uşak", "Van", "Yalova", "Yozgat", "Zonguldak"
    ],
    "Almanya": ["Berlin", "Münih", "Hamburg", "Köln", "Frankfurt"],
    "Amerika Birleşik Devletleri": ["New York", "Los Angeles", "Chicago", "Houston", "Miami"],
    "İngiltere": ["Londra", "Manchester", "Liverpool", "Birmingham"],
    "Fransa": ["Paris", "Lyon", "Marsilya", "Nice"],
    "Azerbaycan": ["Bakü", "Gence", "Sumgayıt"],
    "Diğer": ["Diğer"]
  };

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // --- TARİH SEÇİCİ (TÜRKÇE) ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: const Locale('tr', 'TR'), // TÜRKÇE TAKVİM AYARI
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
      });
    }
  }

  // --- ARAMALI SEÇİM PENCERESİ ---
  void _showSearchableSelector(
      String title, List<String> items, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            String searchQuery = "";
            return StatefulBuilder(
              builder: (context, setModalState) {
                final filteredItems = items
                    .where((item) =>
                        item.toLowerCase().contains(searchQuery.toLowerCase()))
                    .toList();

                return Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Ara...",
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            searchQuery = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return ListTile(
                            title: Text(item),
                            onTap: () {
                              onSelect(item);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // --- KVKK DİYALOG ---
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
- Kimlik Bilgileri: Ad, Soyad, Doğum Tarihi, Konum.
- İletişim Bilgileri: E-posta adresi.
- Kullanım Verileri: Kiler envanteri, fiş verileri.

3. VERİ İŞLEME AMACI
- Size kişiselleştirilmiş yemek tarifleri sunmak.
- Bölgenizdeki market fiyatlarını analiz etmek.
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

  // --- ŞİFRE SIFIRLAMA ---
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
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
                "E-posta adresinizi girin. Size sıfırlama bağlantısı göndereceğiz."),
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
              if (email.isEmpty) return;
              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: email);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Sıfırlama bağlantısı gönderildi!"),
                      backgroundColor: Colors.green));
                }
              } on FirebaseAuthException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(e.message ?? "Hata"),
                      backgroundColor: Colors.red));
                }
              }
            },
            child: const Text("Gönder"),
          ),
        ],
      ),
    );
  }

  // --- SOSYAL GİRİŞLER ---
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _handleSocialLogin(credential);
    } catch (e) {
      _showError("Google giriş hatası: $e");
    }
  }

  Future<void> _signInWithFacebook() async {
    setState(() => _isLoading = true);
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        final AuthCredential credential =
            FacebookAuthProvider.credential(accessToken.tokenString);
        await _handleSocialLogin(credential);
      } else {
        setState(() => _isLoading = false);
        if (result.status == LoginStatus.failed) {
          _showError("Facebook hatası: ${result.message}");
        }
      }
    } catch (e) {
      _showError("Facebook hatası: $e");
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      final rawNonce = _generateNonce();
      final sha256Nonce = sha256.convert(utf8.encode(rawNonce)).toString();
      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256Nonce,
      );
      final OAuthProvider oAuthProvider = OAuthProvider("apple.com");
      final AuthCredential credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
        rawNonce: rawNonce,
      );
      await _handleSocialLogin(credential);
    } catch (e) {
      _showError("Apple giriş hatası: $e");
    }
  }

  Future<void> _handleSocialLogin(AuthCredential credential) async {
    try {
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        bool isMissingInfo = false;
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          if (!data.containsKey('city') || !data.containsKey('birthDate')) {
            isMissingInfo = true;
          }
        } else {
          isMissingInfo = true;
        }

        if (isMissingInfo) {
          await _showMissingInfoDialog(user.uid, isNewUser: !userDoc.exists);
        }
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainLayout()),
        );
      }
    } catch (e) {
      _showError("Giriş başarısız: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- EKSİK BİLGİ DİYALOGU (SOSYAL GİRİŞ SONRASI) ---
  Future<void> _showMissingInfoDialog(String userId,
      {bool isNewUser = false}) async {
    final cityController = TextEditingController(); 
    DateTime? selectedBirthDate;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text("Son Bir Adım Kaldı! 🚀"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  "Size en uygun tarifleri sunabilmemiz için bu bilgilere ihtiyacımız var."),
              const SizedBox(height: 20),
              TextField(
                controller: cityController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: "Yaşadığın Şehir",
                  prefixIcon: Icon(Icons.location_city),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(1995),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                    locale: const Locale('tr', 'TR'), // Türkçe Takvim
                  );
                  if (picked != null) {
                    setDialogState(() => selectedBirthDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Doğum Tarihi",
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    selectedBirthDate == null
                        ? "GG/AA/YYYY Seçiniz"
                        : DateFormat('dd/MM/yyyy').format(selectedBirthDate!),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                if (cityController.text.isNotEmpty &&
                    selectedBirthDate != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .set({
                    'city': cityController.text.trim(),
                    'birthDate': Timestamp.fromDate(selectedBirthDate!),
                    if (isNewUser) ...{
                      'email': FirebaseAuth.instance.currentUser?.email,
                      'name': FirebaseAuth.instance.currentUser?.displayName ??
                          'İsimsiz Şef',
                      'createdAt': FieldValue.serverTimestamp(),
                      'kvkkAccepted': true,
                    }
                  }, SetOptions(merge: true));
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text("Tamamla ve Başla"),
            )
          ],
        );
      }),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
        length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  // --- E-POSTA İLE MANUEL KAYIT/GİRİŞ ---
  Future<void> _submitForm() async {
    setState(() => _errorMessage = null);

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = "E-posta ve şifre zorunludur.");
      return;
    }

    if (!_isLogin) {
      if (_nameController.text.isEmpty ||
          _surnameController.text.isEmpty ||
          _usernameController.text.isEmpty ||
          _selectedDate == null ||
          _selectedCountry == null ||
          _selectedCity == null) {
        setState(
            () => _errorMessage = "Lütfen tüm alanları eksiksiz doldurun.");
        return;
      }

      if (!_isKvkkAccepted) {
        setState(() => _errorMessage = "Aydınlatma Metni'ni onaylamalısınız.");
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        final userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
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
            'country': _selectedCountry,
            'city': _selectedCity,
            'createdAt': FieldValue.serverTimestamp(),
            'kvkkAccepted': true,
            'kvkkAcceptedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainLayout()),
      );
    } on FirebaseAuthException catch (e) {
      String message = "Bir hata oluştu.";
      if (e.code == 'user-not-found') message = "Kullanıcı bulunamadı.";
      if (e.code == 'wrong-password') message = "Şifre hatalı.";
      if (e.code == 'email-already-in-use') message = "E-posta kullanımda.";
      if (e.code == 'weak-password') message = "Şifre zayıf.";
      if (e.code == 'invalid-email') message = "Geçersiz e-posta.";
      setState(() => _errorMessage = message);
    } catch (e) {
      setState(() => _errorMessage = "Hata: $e");
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
              // LOGO
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.surface,
                    border: Border.all(color: colorScheme.primary, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color:
                              colorScheme.primary.withAlpha((0.3 * 255).round()),
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
              Text(_isLogin ? "Tekrar Hoşgeldin Şef!" : "Aramıza Katıl",
                  style: TextStyle(color: colorScheme.secondary, fontSize: 16)),

              const SizedBox(height: 30),

              // --- MANUEL FORM ALANLARI ---
              if (!_isLogin) ...[
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(
                            "İsim", Icons.person, _nameController)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildTextField("Soyisim", Icons.person_outline,
                            _surnameController)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField("Kullanıcı Adı", Icons.alternate_email,
                    _usernameController),
                const SizedBox(height: 16),

                // -- ÜLKE & ŞEHİR SEÇİMİ --
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showSearchableSelector(
                            "Ülke Seç", _locationData.keys.toList(), (val) {
                          setState(() {
                            _selectedCountry = val;
                            _selectedCity = null;
                          });
                        }),
                        child: _buildSelectorDecoration(
                            _selectedCountry ?? "Ülke", Icons.public),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_selectedCountry == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Önce ülke seçmelisin.")));
                            return;
                          }
                          _showSearchableSelector(
                              "Şehir Seç",
                              _locationData[_selectedCountry] ?? [],
                              (val) => setState(() => _selectedCity = val));
                        },
                        child: _buildSelectorDecoration(
                            _selectedCity ?? "Şehir", Icons.location_city),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // -- DOĞUM TARİHİ (YENİ BASİT GÖRÜNÜM) --
                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: _buildSelectorDecoration(
                    _selectedDate == null 
                      ? "Doğum Tarihi" 
                      : DateFormat('dd/MM/yyyy').format(_selectedDate!), 
                    Icons.calendar_today
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

              // Şifremi Unuttum
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

              // KVKK
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
                        onTap: _showKvkkDialog,
                        child: RichText(
                          text: TextSpan(
                            text: "Kişisel verilerimin işlenmesine ilişkin ",
                            style: TextStyle(
                                color: colorScheme.onSurface
                                    .withAlpha((0.7 * 255).round()),
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

              // Giriş Butonu
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: colorScheme.error
                                  .withAlpha((0.1 * 255).round()),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: colorScheme.error
                                      .withAlpha((0.5 * 255).round())),
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
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Sosyal Giriş
                        Row(
                          children: [
                            Expanded(
                                child: Divider(color: Colors.grey.shade400)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text("veya şununla bağlan",
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12)),
                            ),
                            Expanded(
                                child: Divider(color: Colors.grey.shade400)),
                          ],
                        ),

                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _socialButton(Icons.g_mobiledata, Colors.red,
                                _signInWithGoogle),
                            _socialButton(Icons.facebook, Colors.blue.shade800,
                                _signInWithFacebook),
                            _socialButton(
                                Icons.apple, Colors.black, _signInWithApple),
                          ],
                        ),

                        const SizedBox(height: 20),

                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _errorMessage = null;
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
                                      .withAlpha((0.7 * 255).round())),
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

  // Ortak Seçim Kutusu Görünümü (Tarih, Ülke, Şehir için)
  Widget _buildSelectorDecoration(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: text == "Ülke" || text == "Şehir" || text == "Doğum Tarihi"
                      ? Colors.grey[700]
                      : Theme.of(context).colorScheme.onSurface),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _socialButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.white,
        ),
        child: Icon(icon, color: color, size: 32),
      ),
    );
  }
}