// lib/features/profile/edit_profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'profile_service.dart';

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
    final pickedFile = await picker.pickImage(source: source, imageQuality: 50);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // 1. Temel Bilgileri Güncelle (Ad, Soyad)
      await _profileService.updateProfileInfo(
        _nameController.text.trim(),
        _surnameController.text.trim(),
      );

      // Değişiklik kontrolü için mevcut email
      final currentEmail = _profileService.currentUser?.email;
      final newEmail = _emailController.text.trim();
      final newPassword = _newPasswordController.text.trim();
      final currentPassword = _currentPasswordController.text.trim();

      // 2. Kritik İşlemler (Email veya Şifre Değişikliği)
      bool sensitiveChange = (newEmail != currentEmail) || (newPassword.isNotEmpty);

      if (sensitiveChange) {
        // Kritik işlem varsa mutlaka mevcut şifre girilmeli
        if (currentPassword.isEmpty) {
          throw Exception("E-posta veya şifre değiştirmek için 'Mevcut Şifrenizi' girmelisiniz.");
        }

        // A) E-posta güncelleme
        if (newEmail != currentEmail) {
          await _profileService.updateEmail(newEmail, currentPassword);
        }

        // B) Şifre güncelleme
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
      Navigator.pop(context);

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
                  ],
                ),
              ),
            ),
    );
  }
}