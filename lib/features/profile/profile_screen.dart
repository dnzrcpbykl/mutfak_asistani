import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // <--- EKLENDİ

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_notifier.dart'; // <--- EKLENDİ
import '../auth/login_screen.dart';
import 'saved_recipes_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _cikisYap(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    // Temanın durumunu dinliyoruz (Koyu mu Açık mı?)
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
              
              // --- PROFİL RESMİ ---
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
              const SizedBox(height: 20),
              
              Text(
                user?.email ?? "Misafir", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)
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

              // 2. TEMA DEĞİŞTİRME ANAHTARI (Switch) - BURASI YENİ
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

  // Yardımcı Widget: Menü Kutucukları (Renkleri parametre olarak alıyor)
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
        // Light modda hafif gölge olsun, Dark modda düz olsun
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