import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_service.dart';
import 'premium_screen.dart'; // Satın alma ekranına yönlendirmek için

class SubscriptionSettingsScreen extends StatefulWidget {
  const SubscriptionSettingsScreen({super.key});

  @override
  State<SubscriptionSettingsScreen> createState() => _SubscriptionSettingsScreenState();
}

class _SubscriptionSettingsScreenState extends State<SubscriptionSettingsScreen> {
  final ProfileService _profileService = ProfileService();
  bool _isLoading = true;
  bool _isPremium = false;
  String _planType = "Ücretsiz";

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    final status = await _profileService.checkUsageRights();
    // Veritabanından plan tipini de çekmek gerekebilir ama şimdilik basit tutalım
    // Eğer isPremium true ise "Premium", değilse "Ücretsiz"
    
    // Plan detayını çekmek için profileService'e küçük bir ekleme yapılabilir veya
    // direkt kullanıcı dokümanını okuyabiliriz. Şimdilik basit:
    if (status['isPremium']) {
       // Kullanıcı dokümanından subscriptionType'ı alalım (Basitçe)
       final userDoc = await _profileService.getUserData();
       String type = userDoc?['subscriptionType'] == 'yearly' ? "Yıllık Premium" : "Aylık Premium";
       
       setState(() {
         _isPremium = true;
         _planType = type;
         _isLoading = false;
       });
    } else {
      setState(() {
        _isPremium = false;
        _planType = "Ücretsiz Paket";
        _isLoading = false;
      });
    }
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Aboneliği İptal Et?"),
        content: const Text(
          "Premium ayrıcalıklarınızı kaybedeceksiniz. Devam etmek istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              await _profileService.cancelSubscription();
              await _checkStatus(); // Ekranı yenile
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Abonelik iptal edildi.")));
              }
            },
            child: const Text("Evet, İptal Et"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Abonelik Yönetimi")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // DURUM KARTI
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: _isPremium 
                  ? const LinearGradient(colors: [Color(0xFF6A00FF), Color(0xFFFF00A8)])
                  : LinearGradient(colors: [Colors.grey.shade700, Colors.grey.shade900]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))]
              ),
              child: Column(
                children: [
                  Icon(_isPremium ? Icons.workspace_premium : Icons.person, size: 50, color: Colors.white),
                  const SizedBox(height: 10),
                  Text("Mevcut Planınız", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
                  Text(_planType, style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ÖZELLİK LİSTESİ
            Expanded(
              child: ListView(
                children: [
                  const Text("Paket Özellikleri:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  _buildAccessItem("Günlük Tarif Hakkı", _isPremium ? "Sınırsız" : "Günde 1 Adet", _isPremium),
                  _buildAccessItem("Reklamlar", _isPremium ? "Yok" : "Var", _isPremium),
                  _buildAccessItem("Özel İstek (Prompt)", _isPremium ? "Açık" : "Kapalı", _isPremium),
                  _buildAccessItem("Besin Değerleri", _isPremium ? "Detaylı" : "Kısıtlı", _isPremium),
                ],
              ),
            ),

            // AKSİYON BUTONU
            if (_isPremium)
              TextButton.icon(
                onPressed: _showCancelConfirmation,
                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                label: const Text("Aboneliği İptal Et", style: TextStyle(color: Colors.red)),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PremiumScreen())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black
                  ),
                  child: const Text("Premium'a Yükselt", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessItem(String title, String value, bool isGood) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(title),
        trailing: Text(value, style: TextStyle(
          fontWeight: FontWeight.bold, 
          color: isGood ? Colors.green : Colors.grey
        )),
      ),
    );
  }
}