import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<Map<String, String>> _contents = [
    {
      "title": "Fişini Tara, Kilerini Doldur",
      "desc": "Market fişlerini yapay zeka ile saniyeler içinde tara, kilerine otomatik ekle.",
      "image": "assets/onboarding1.png"
    },
    {
      "title": "Şefe Sor, Ne Pişireceğini Bul",
      "desc": "Evinizdeki malzemelere göre size özel tarifler alın. 'Bugün ne pişirsem?' derdine son!",
      "image": "assets/onboarding2.png"
    },
    {
      "title": "Akıllı Mutfak Asistanı",
      "desc": "Adım adım sesli tarifler, sayaçlar ve akıllı alışveriş listesi ile mutfakta profesyonelleşin.",
      "image": "assets/onboarding3.png"
    },
  ];

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Ekran boyutunu alalım
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemCount: _contents.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30.0), // Kenar boşluklarını azalttım
                    child: Column(
                      children: [
                        // Dinamik üst boşluk
                        const Spacer(flex: 1),
                        
                        // RESİM (Ekran yüksekliğinin %40'ını geçmesin)
                        SizedBox(
                          height: size.height * 0.4, 
                          child: Image.asset(
                            _contents[index]["image"]!,
                            fit: BoxFit.contain,
                          ),
                        ),
                        
                        const Spacer(flex: 1),
                        
                        // BAŞLIK
                        Text(
                          _contents[index]["title"]!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // AÇIKLAMA
                        Text(
                          _contents[index]["desc"]!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: colorScheme.onSurface.withAlpha((0.7 * 255).round()), height: 1.4),
                        ),
                        
                        const Spacer(flex: 2), // Alt kısımda daha fazla boşluk kalsın
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Noktalar ve Butonun olduğu alt kısım (Sabit Yükseklik)
            Padding(
              padding: EdgeInsets.fromLTRB(30, 0, 30, 30 + MediaQuery.of(context).padding.bottom), // Alt boşluk için cihaz alt çubuğunu da ekledik
              child: Column(
                children: [
                  // Noktalar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_contents.length, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 8,
                        width: _currentIndex == index ? 24 : 8,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: _currentIndex == index ? colorScheme.primary : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  
                  const SizedBox(height: 30),

                  // Buton
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentIndex == _contents.length - 1) {
                          _finishOnboarding();
                        } else {
                          _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_currentIndex == _contents.length - 1 ? "Başla" : "İleri", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}