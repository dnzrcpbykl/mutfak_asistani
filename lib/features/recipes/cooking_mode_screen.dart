import 'package:flutter/material.dart';
import '../../core/models/recipe.dart';

class CookingModeScreen extends StatefulWidget {
  final Recipe recipe;
  final VoidCallback onComplete; // Pişirme bitince çalışacak fonksiyon

  const CookingModeScreen({super.key, required this.recipe, required this.onComplete});

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  late List<String> _steps;
  final PageController _pageController = PageController();
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    // Tarifi akıllıca adımlara bölüyoruz
    _steps = _parseInstructions(widget.recipe.instructions);
  }

  // --- DÜZELTİLEN BÖLÜM: AKILLI AYRIŞTIRICI ---
  List<String> _parseInstructions(String text) {
    // 1. Önce numaralandırma var mı bak (1. Adım, 2. Adım...)
    // Regex: Sayı, nokta ve boşluk (Örn: "1. ")
    final numberSplit = text.split(RegExp(r'\d+\.\s+'));
    
    // İlk eleman bazen boş gelir (metin "1." ile başlıyorsa), onu temizle
    List<String> cleanList = numberSplit.where((s) => s.trim().isNotEmpty).map((s) => s.trim()).toList();

    // Eğer numaralandırma işe yaradıysa ve birden fazla adım çıktıysa bunu döndür
    if (cleanList.length > 1) {
      return cleanList;
    }

    // 2. Numaralandırma yoksa, satır satır (\n) bölmeyi dene
    final lineSplit = text.split('\n');
    cleanList = lineSplit.where((s) => s.trim().isNotEmpty).map((s) => s.trim()).toList();
    
    if (cleanList.length > 1) {
      return cleanList;
    }

    // 3. O da yoksa cümle cümle (. ) bölmeyi dene
    // Son çare: Nokta ve boşluk gördüğü yerden böler.
    final sentenceSplit = text.split('. ');
    cleanList = sentenceSplit.where((s) => s.trim().isNotEmpty).map((s) => s.trim()).toList();

    // Hiçbiri olmazsa metni tek parça döndür ama en azından array olsun
    return cleanList.isNotEmpty ? cleanList : [text];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("Pişirme Modu: ${widget.recipe.name}"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // --- İLERLEME ÇUBUĞU ---
          LinearProgressIndicator(
            value: _steps.isNotEmpty ? (_currentStep + 1) / _steps.length : 1,
            backgroundColor: colorScheme.onSurface.withOpacity(0.1),
            color: colorScheme.primary,
            minHeight: 6,
          ),
          
          // --- ORTA KISIM (KAYDIRILABİLİR YAPILDI) ---
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentStep = index;
                });
              },
              itemCount: _steps.length,
              itemBuilder: (context, index) {
                // BURASI DÜZELTİLDİ: Center ve SingleChildScrollView eklendi
                // Artık metin uzunsa aşağı doğru kaydırılabilecek ve hata vermeyecek.
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "ADIM ${index + 1}",
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            fontSize: 16
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          _steps[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // --- KONTROL BUTONLARI ---
          Container(
            padding: const EdgeInsets.all(24),
            // Butonların arkasına hafif bir renk koyalım ki metin aksa bile butonlar net görünsün
            color: theme.scaffoldBackgroundColor, 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // GERİ BUTONU
                if (_currentStep > 0)
                  ElevatedButton.icon(
                    onPressed: () {
                      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Geri"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.surface,
                      foregroundColor: colorScheme.onSurface,
                    ),
                  )
                else 
                  const SizedBox(width: 100), // Boşluk tutucu (Düzeni bozmamak için)

                // İLERİ / BİTİR BUTONU
                if (_currentStep < _steps.length - 1)
                  ElevatedButton.icon(
                    onPressed: () {
                      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    },
                    // Yönlendirmeyi düzeltmek için (Sağ ikon)
                    icon: const SizedBox.shrink(), // Sol ikonu gizle
                    label: Row(
                      children: const [
                        Text("İleri"),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Moddan çık
                      widget.onComplete(); // Stok düşme dialogunu tetikle
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text("Yemeği Tamamla!"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}