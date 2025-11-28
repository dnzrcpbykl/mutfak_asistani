import 'package:flutter/material.dart';
import 'package:mutfak_asistani/features/auth/login_screen.dart';
import 'package:mutfak_asistani/features/profile/profile_service.dart';
import '../profile/subscription_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ProfileService _profileService = ProfileService();
  bool _isLoading = false;

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hesabı Sil", style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Bu işlem geri alınamaz! Tüm kileriniz, tarifleriniz ve verileriniz kalıcı olarak silinecektir.",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            const Text("Onaylamak için şifrenizi girin:", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "Mevcut Şifre",
                prefixIcon: Icon(Icons.lock_outline),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (passwordController.text.isEmpty) return;
              
              Navigator.pop(context); // Dialogu kapat
              await _performDelete(passwordController.text.trim());
            },
            child: const Text("Hesabımı Kalıcı Olarak Sil"),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(String password) async {
    setState(() => _isLoading = true);
    try {
      await _profileService.deleteAccount(password);
      
      if (!mounted) return;
      // Başarılı olursa Login ekranına at ve geçmişi temizle
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hesabınız başarıyla silindi. Hoşçakalın."), backgroundColor: Colors.grey),
      );

    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll("Exception:", "")), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Ayarlar")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- ABONELİK YÖNETİMİ (YENİ) ---
          ListTile(
            leading: const Icon(Icons.card_membership, color: Colors.amber),
            title: const Text("Abonelik ve Paketim"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionSettingsScreen())),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.notifications_outlined),
            title: Text("Bildirim Ayarları"),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.language),
            title: Text("Dil Seçeneği"),
            subtitle: Text("Türkçe"),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("Uygulama Hakkında"),
            subtitle: Text("v1.0.0"),
          ),
          const SizedBox(height: 40),
          
          // TEHLİKELİ BÖLGE
          const SizedBox(height: 10),
          ListTile(
            tileColor: Colors.red.withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Hesabımı Sil", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: _showDeleteAccountDialog,
          ),
        ],
      ),
    );
  }
}