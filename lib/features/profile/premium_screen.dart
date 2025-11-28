import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final ProfileService _profileService = ProfileService();
  bool _isLoading = false;
  String _selectedPlan = 'yearly';

  final double _monthlyPrice = 100.0;
  final double _yearlyPrice = 900.0;

  final Color _primaryPurple = const Color(0xFF6A00FF);
  final Color _accentPink = const Color(0xFFFF00A8);
  final Color _darkBgStart = const Color(0xFF12032E);
  final Color _darkBgEnd = const Color(0xFF280F54);
  final Color _cardUnselected = const Color(0xFF351B61).withOpacity(0.5);

  Future<void> _buySubscription() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    try {
      await _profileService.upgradeToPremium(_selectedPlan);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tebrikler! Artık Premium üyesiniz 👑"), backgroundColor: Colors.amber),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLegalDoc(String title, String text) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
              Center(child: Container(width: 40, height: 4, color: Colors.grey, margin: const EdgeInsets.only(bottom: 20))),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Text(text, style: const TextStyle(color: Colors.white70, height: 1.5)),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  final String _privacyText = """
1. VERİ GİZLİLİĞİ TAAHHÜDÜ
Mutfak Asistanı olarak, kişisel verilerinizi KVKK ve GDPR kapsamında koruyoruz.

2. ÖDEME BİLGİLERİ
Ödeme işlemleri Apple App Store ve Google Play Store üzerinden güvenle yapılır. Biz kredi kartı bilginizi görmeyiz.
""";

  final String _termsText = """
1. HİZMETİN KAPSAMI
Yapay zeka destekli tarifler ve kiler yönetimi.

2. İPTAL VE İADE
Ayarlar menüsünden aboneliğinizi dilediğiniz zaman yönetebilirsiniz.
""";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_darkBgStart, _darkBgEnd],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: _accentPink))
              : Stack(
                  children: [
                    // 1. İÇERİK (En alta koyduk, böylece buton bunun üstüne binecek)
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40), // Buton için üstten boşluk
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [_accentPink, _primaryPurple],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: const Icon(Icons.auto_awesome, size: 60, color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Mutfak Şefi Premium",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Sınırları kaldır, tüm özelliklere eriş!",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
                          ),

                          const SizedBox(height: 40),

                          _buildFeatureRow("Sınırsız Yapay Zeka Tarif Üretimi"),
                          _buildFeatureRow("Şefe Özel İstekler (Serbest Prompt)"),
                          _buildFeatureRow("Tamamen Reklamsız Deneyim"),
                          _buildFeatureRow("Sınırsız Fiş Tarama & Stoklama"),
                          _buildFeatureRow("Besin Değerleri Analizi"),

                          const SizedBox(height: 40),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: _buildPlanCard(
                                  title: "Aylık",
                                  price: "₺${_monthlyPrice.toStringAsFixed(0)}",
                                  period: "/ay",
                                  planKey: 'monthly',
                                  isBestValue: false,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildPlanCard(
                                  title: "Yıllık",
                                  price: "₺${_yearlyPrice.toStringAsFixed(0)}",
                                  period: "/yıl",
                                  subText: "Aylık sadece ₺${(_yearlyPrice / 12).toStringAsFixed(0)}",
                                  planKey: 'yearly',
                                  isBestValue: true,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),

                          InkWell(
                            onTap: _buySubscription,
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _selectedPlan == 'yearly' 
                                    ? [_accentPink, _primaryPurple] 
                                    : [_primaryPurple.withOpacity(0.8), _primaryPurple], 
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_selectedPlan == 'yearly' ? _accentPink : _primaryPurple).withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  )
                                ]
                              ),
                              child: Text(
                                "Premium'u Başlat",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () => _showLegalDoc("Gizlilik Politikası", _privacyText),
                                child: Text("Gizlilik Politikası", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
                              ),
                              Text("|", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
                              TextButton(
                                onPressed: () => _showLegalDoc("Kullanım Koşulları", _termsText),
                                child: Text("Kullanım Koşulları", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),

                    // 2. KAPATMA BUTONU (En üste koyduk ki tıklanabilsin)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: SafeArea( // SafeArea içinde olmalı
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 30),
                          onPressed: () {
                            print("Kapat butonuna basıldı!"); // Debug için
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: _accentPink, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 15))),
        ],
      ),
    );
  }

  Widget _buildPlanCard({required String title, required String price, required String period, required String planKey, String? subText, required bool isBestValue}) {
    final isSelected = _selectedPlan == planKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = planKey),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isSelected ? null : _cardUnselected,
              gradient: isSelected ? LinearGradient(
                colors: [_primaryPurple.withOpacity(0.6), _accentPink.withOpacity(0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight
              ) : null,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isSelected ? _accentPink : Colors.white.withOpacity(0.1), width: isSelected ? 2 : 1),
              boxShadow: isSelected ? [BoxShadow(color: _accentPink.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))] : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(price, style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.0)),
                    Text(period, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                  ],
                ),
                if (subText != null) ...[
                  const SizedBox(height: 8),
                  Text(subText, style: GoogleFonts.poppins(color: _accentPink, fontSize: 12, fontWeight: FontWeight.w500)),
                ]
              ],
            ),
          ),
          if (isBestValue)
            Positioned(
              top: -12, right: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _accentPink, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: _accentPink.withOpacity(0.5), blurRadius: 8)]),
                child: Text("EN İYİ FİYAT", style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}