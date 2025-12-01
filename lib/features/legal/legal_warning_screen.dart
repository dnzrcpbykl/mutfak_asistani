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
    await prefs.setBool('acceptedLegalTerms_v1', true); // Yasal onayı kaydet

    // DÜZELTME BURADA: 
    // Ezbere 'true' göndermek yerine, kullanıcının gerçekten tanıtımı görüp görmediğini kontrol ediyoruz.
    // İlk açılışta bu değer henüz 'false' olduğu için, yönlendirdiğimizde Tanıtım Ekranı açılacak.
    final bool currentSeenOnboarding = prefs.getBool('seenOnboarding') ?? false;

    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MutfakAsistaniApp(
          seenOnboarding: currentSeenOnboarding, // Sabit 'true' yerine gerçek değeri gönderdik
          acceptedLegal: true, 
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
            // EdgeInsets.all(20) yerine sadece yanlardan ve üstten verip,
            // alt kısmı dinamik hale getiriyoruz.
            padding: EdgeInsets.fromLTRB(
              20, 
              20, 
              20, 
              20 + MediaQuery.of(context).padding.bottom // <--- KRİTİK DÜZELTME
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _acceptTerms,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, 
                  foregroundColor: Colors.white,
                  elevation: 4, // Biraz gölge ekleyerek daha "basılabilir" hissettirelim
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)) // Modern köşe
                ),
                child: const Text("Okudum ve Kabul Ediyorum", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          )
        ],
      ),
    );
  }
}