import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart'; // MutfakAsistaniApp'e dönmek için

class LegalWarningScreen extends StatefulWidget {
  const LegalWarningScreen({super.key});

  @override
  State<LegalWarningScreen> createState() => _LegalWarningScreenState();
}

class _LegalWarningScreenState extends State<LegalWarningScreen> {
  
  // YASAL METİN
  final String _legalText = """
1. FERAGATNAME (SORUMLULUK REDDİ)
Bu uygulama ("Mutfak Asistanı"), kullanıcıların market alışverişlerini planlamalarına yardımcı olmak amacıyla geliştirilmiş bir araçtır.

2. FİYAT VERİLERİ HAKKINDA
Uygulama içerisinde gösterilen ürün fiyatları, kullanıcılar tarafından taranan fişlerden elde edilen "Tahmini Veriler"dir. 
- Bu fiyatlar anlık piyasa koşullarını yansıtmayabilir.
- İlgili marketteki raf fiyatı ile uygulama fiyatı arasında farklılık olabilir.
- Mutfak Asistanı, fiyatların kesin doğruluğunu garanti etmez. Alışveriş kararı verirken lütfen marketin güncel raf/etiket fiyatlarını esas alınız.

3. LOGO VE MARKA KULLANIMI
Uygulama içerisinde gösterilen market logoları (BİM, A101, Şok, Migros vb.), ilgili şirketlerin tescilli markalarıdır.
- Logolar, sadece "Adil Kullanım" (Fair Use) ve "Tanımlama" amacıyla, kullanıcının hangi fiyatın hangi markete ait olduğunu ayırt edebilmesi için kullanılmıştır.
- Mutfak Asistanı uygulamasının bu markalarla herhangi bir ticari ortaklığı, sponsorluğu veya resmi bağı YOKTUR.
- Yönlendirme linkleri, kullanıcı kolaylığı sağlamak içindir.

4. KABUL
"Kabul Ediyorum" butonuna tıklayarak, yukarıdaki şartları okuduğunuzu, anladığınızı ve uygulamanın sağladığı verilerin sadece bilgilendirme amaçlı olduğunu kabul etmiş sayılırsınız.
""";

  Future<void> _acceptTerms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('acceptedLegalTerms_v1', true); // Kayıt edildi

    if (!mounted) return;
    
    // --- DÜZELTİLEN KISIM BURASI ---
    // Ana uygulamayı yeniden başlatırken 'acceptedLegal: true' olarak gönderiyoruz.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MutfakAsistaniApp(
          seenOnboarding: true, 
          acceptedLegal: true, // <--- EKLENDİ (Hata bu satırın eksikliğinden kaynaklanıyordu)
        )
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Yasal Uyarı ve Kullanım"), 
        centerTitle: true,
        automaticallyImplyLeading: false, // Geri butonu olmasın (Zorunlu ekran)
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300)
                ),
                child: Text(_legalText, style: const TextStyle(fontSize: 14, height: 1.5)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _acceptTerms,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: const Text("Okudum ve Kabul Ediyorum", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
    );
  }
}