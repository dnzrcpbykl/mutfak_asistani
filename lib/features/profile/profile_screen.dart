// lib/features/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_notifier.dart';
import '../recipes/recipe_provider.dart'; 
import '../auth/login_screen.dart';
import 'saved_recipes_screen.dart';
import 'edit_profile_screen.dart'; // <--- Yeni ekranı import etmeyi unutma!

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _cikisYap(BuildContext context) async {
    // 1. ÖNCE HAFIZADAKİ ESKİ VERİLERİ SİLİYORUZ
    try {
      Provider.of<RecipeProvider>(context, listen: false).clearData();
    } catch (e) {
      debugPrint("Veri temizleme hatası (önemsiz): $e");
    }

    // 2. FIREBASE'DEN ÇIKIŞ YAPIYORUZ
    await FirebaseAuth.instance.signOut();
    
    if (!context.mounted) return;

    // 3. GİRİŞ EKRANINA YÖNLENDİRİYORUZ
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    // Temanın durumunu dinliyoruz
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = themeNotifier.isDarkMode;

    // Renkleri moda göre ayarlıyoruz
    final textColor = isDark ? Colors.white : Colors.black87;
    final tileColor = isDark ? AppTheme.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.grey.shade300;

    return Scaffold(
      appBar: AppBar(title: const Text("Profil")),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 30),
              
              // --- PROFİL RESMİ VE BİLGİSİ (DÜZENLEME İÇİN TIKLANABİLİR) ---
              GestureDetector(
                onTap: () {
                  // Düzenleme Sayfasına Git
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const EditProfileScreen())
                  );
                },
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.neonCyan, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.neonCyan.withOpacity(isDark ? 0.4 : 0.2), 
                                blurRadius: 15
                              )
                            ]
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: tileColor,
                            child: Icon(Icons.person, size: 50, color: isDark ? Colors.white : Colors.grey),
                          ),
                        ),
                        // Düzenleme ikonu (Sağ alt köşe)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    Text(
                      user?.email ?? "Misafir", 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Profili Düzenle", 
                      style: TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.w500)
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // --- MENÜLER ---
              
              // 1. Favorilerim
              _buildProfileTile(
                context, 
                icon: Icons.favorite, 
                color: Colors.redAccent, 
                title: "Favori Tariflerim",
                tileColor: tileColor,
                textColor: textColor,
                borderColor: borderColor,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedRecipesScreen())),
              ),

              // 2. TEMA DEĞİŞTİRME ANAHTARI
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: borderColor),
                  boxShadow: isDark ? [] : [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))]
                ),
                child: SwitchListTile(
                  title: Text(
                    isDark ? "Karanlık Mod" : "Aydınlık Mod",
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                  ),
                  secondary: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    color: isDark ? AppTheme.neonCyan : Colors.orange,
                  ),
                  value: isDark,
                  activeThumbColor: AppTheme.neonCyan,
                  onChanged: (value) {
                    themeNotifier.toggleTheme();
                  },
                ),
              ),

              // 3. Ayarlar (Placeholder)
              _buildProfileTile(
                context, 
                icon: Icons.settings, 
                color: AppTheme.softPeach, 
                title: "Ayarlar",
                tileColor: tileColor,
                textColor: textColor,
                borderColor: borderColor,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yakında..."))),
              ),

              // 4. Çıkış Yap
              _buildProfileTile(
                context, 
                icon: Icons.logout, 
                color: Colors.grey, 
                title: "Çıkış Yap",
                tileColor: tileColor,
                textColor: textColor,
                borderColor: borderColor,
                onTap: () => _cikisYap(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Yardımcı Widget: Menü Kutucukları
  Widget _buildProfileTile(
    BuildContext context, {
    required IconData icon, 
    required Color color, 
    required String title, 
    required VoidCallback onTap,
    required Color tileColor,
    required Color textColor,
    required Color borderColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: borderColor),
        boxShadow: tileColor == Colors.white 
            ? [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))]
            : []
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: textColor)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}