// lib/features/profile/edit_profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'profile_service.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProfileService _profileService = ProfileService();

  // Kontrolcüler
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  
  // Şifre Kontrolcüleri
  final _newPasswordController = TextEditingController(); // YENİ: Yeni Şifre
  final _currentPasswordController = TextEditingController(); // Onay için Mevcut Şifre

  bool _isLoading = false;
  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final data = await _profileService.getUserData();
    if (data != null) {
      _nameController.text = data['name'] ?? '';
      _surnameController.text = data['surname'] ?? '';
      _emailController.text = _profileService.currentUser?.email ?? '';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () {
                  _getImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Kamera'),
                onTap: () {
                  _getImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source) async {
    final picker = ImagePicker();
    // 1. Resmi Seç (Burada kalite ayarı yapmıyoruz, orijinali alıyoruz)
    final XFile? pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() => _isLoading = true); // İşlem başlarken loading gösterelim

      try {
        // 2. Geçici dizini bul
        final dir = await path_provider.getTemporaryDirectory();
        // Yeni dosya yolu oluştur (sonuna .jpg ekleyerek)
        final targetPath = '${dir.absolute.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg';

        // 3. Resmi Sıkıştır ve Boyutlandır (Native İşlem)
        final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
          pickedFile.path,
          targetPath,
          minWidth: 800, // Genişlik en fazla 800px olsun (Yeterli kalite)
          minHeight: 800, // Yükseklik en fazla 800px olsun
          quality: 70, // Kalite %70 olsun (Gözle görülür fark olmaz ama dosya boyutu uçar)
          format: CompressFormat.jpeg,
        );

        if (compressedFile != null) {
          setState(() {
            _selectedImage = File(compressedFile.path);
          });
        }
      } catch (e) {
        debugPrint("Resim sıkıştırma hatası: $e");
        // Hata olursa orijinali kullan (Yedek plan)
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // --- GÜNCELLENEN KISIM: Resmi de gönderiyoruz ---
      await _profileService.updateProfileInfo(
        name: _nameController.text.trim(),
        surname: _surnameController.text.trim(),
        imageFile: _selectedImage, // Seçilen resmi buraya ekledik
      );
      // ------------------------------------------------

      final currentEmail = _profileService.currentUser?.email;
      final newEmail = _emailController.text.trim();
      final newPassword = _newPasswordController.text.trim();
      final currentPassword = _currentPasswordController.text.trim();

      bool sensitiveChange = (newEmail != currentEmail) || (newPassword.isNotEmpty);

      if (sensitiveChange) {
        if (currentPassword.isEmpty) {
          throw Exception("E-posta veya şifre değiştirmek için 'Mevcut Şifrenizi' girmelisiniz.");
        }
        if (newEmail != currentEmail) {
          await _profileService.updateEmail(newEmail, currentPassword);
        }
        if (newPassword.isNotEmpty) {
          if (newPassword.length < 6) {
            throw Exception("Yeni şifre en az 6 karakter olmalıdır.");
          }
          await _profileService.updatePassword(currentPassword, newPassword);
        }
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profil başarıyla güncellendi! ✅"), backgroundColor: Colors.green)
      );
      Navigator.pop(context, true); // Geri dönerken "güncellendi" sinyali ver (true)

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: ${e.toString()}"), backgroundColor: Colors.red)
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profili Düzenle"),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // --- PROFİL FOTOĞRAFI ALANI ---
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            backgroundImage: _selectedImage != null 
                                ? FileImage(_selectedImage!) 
                                : null,
                            child: _selectedImage == null 
                                ? Icon(Icons.person, size: 60, color: theme.colorScheme.onSurfaceVariant)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _pickImage,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // --- KİŞİSEL BİLGİLER ---
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "İsim",
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) => v!.isEmpty ? "İsim boş olamaz" : null,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _surnameController,
                      decoration: const InputDecoration(
                        labelText: "Soyisim",
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => v!.isEmpty ? "Soyisim boş olamaz" : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "E-posta Adresi",
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),

                    const SizedBox(height: 30),
                    
                    // --- GÜVENLİK ALANI ---
                    const Divider(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Şifre Değişikliği (İsteğe Bağlı)", 
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)
                      ),
                    ),
                    const SizedBox(height: 10),

                    // YENİ ŞİFRE ALANI
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: !_isNewPasswordVisible,
                      decoration: InputDecoration(
                        labelText: "Yeni Şifre",
                        hintText: "Değiştirmek istemiyorsanız boş bırakın",
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_isNewPasswordVisible ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _isNewPasswordVisible = !_isNewPasswordVisible),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),

                    // MEVCUT ŞİFRE (ONAY İÇİN)
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: !_isCurrentPasswordVisible,
                      decoration: InputDecoration(
                        labelText: "Mevcut Şifre (Onay İçin)",
                        helperText: "E-posta veya şifre değiştiriyorsanız gereklidir.",
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_isCurrentPasswordVisible ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _isCurrentPasswordVisible = !_isCurrentPasswordVisible),
                        ),
                        // Onay kutusunu biraz daha belirgin yapalım (kırmızımsı border vb. opsiyonel)
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.error),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // --- KAYDET BUTONU ---
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        child: const Text("Değişiklikleri Kaydet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                  ],
                ),
              ),
            ),
    );
  }
}