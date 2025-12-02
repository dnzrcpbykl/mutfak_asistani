import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/models/recipe.dart';

class CookingModeScreen extends StatefulWidget {
  final Recipe recipe;
  final VoidCallback onComplete;

  const CookingModeScreen({
    super.key,
    required this.recipe,
    required this.onComplete,
  });

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  late List<String> _steps;
  final PageController _pageController = PageController();
  int _currentStep = 0;
  
  // TTS
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  // Timer
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;
  bool _isTimerRunning = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    
    // Adımları ayıkla
    _steps = _parseInstructions(widget.recipe.instructions);
    
    // Sesi hazırla (Android için gecikmeli başlatma bazen sorunu çözer)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initTts();
    });
  }

  // --- KESİN ÇÖZÜM: SPLIT MANTIĞI ---
  List<String> _parseInstructions(String text) {
    if (text.trim().isEmpty) return ["Tarif hazırlanıyor..."];

    // 1. Temizlik
    String cleanText = text.replaceAll('**', '').trim();

    // 2. BÖLME İŞLEMİ (SPLIT)
    // Regex Açıklaması:
    // (?:^|\s+) -> Başlangıçta olabilir VEYA öncesinde boşluk olabilir
    // \d+       -> Bir veya daha fazla rakam (1, 2, 10...)
    // [\.\)\:]  -> Nokta, parantez veya iki nokta (1. veya 1) veya 1:)
    // \s+       -> Sonrasında boşluk
    final RegExp splitRegex = RegExp(r'(?:^|\s+)\d+[\.\)\:]\s+');

    // Metni sayılardan bölüyoruz.
    // Örnek: "Soğanı doğra. 2. Suyu ekle" -> ["Soğanı doğra. ", "Suyu ekle"]
    List<String> parts = cleanText.split(splitRegex);

    // 3. Boşlukları temizle ve listeyi oluştur
    List<String> steps = parts
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 2) // Çok kısa parçaları at (örn: sadece nokta kalmışsa)
        .toList();

    // 4. Eğer hiç bölünemediyse (Liste formatında değilse)
    if (steps.isEmpty) {
      // Satır satır bölmeyi dene
      steps = cleanText.split('\n').where((s) => s.trim().isNotEmpty).toList();
    }
    
    // 5. Hala boşsa orijinal metni tek parça olarak ver
    if (steps.isEmpty) return [cleanText];

    return steps;
  }

  // --- TTS ---
  Future<void> _initTts() async {
    try {
      // Dil ayarı
      await _flutterTts.setLanguage("tr-TR");
      
      // Ses özellikleri
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // iOS Ses Kategorisi
      if (Platform.isIOS) {
        await _flutterTts.setIosAudioCategory(
            IosTextToSpeechAudioCategory.playback,
            [
              IosTextToSpeechAudioCategoryOptions.allowBluetooth,
              IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
              IosTextToSpeechAudioCategoryOptions.mixWithOthers
            ],
            IosTextToSpeechAudioMode.defaultMode
        );
      }

      // 'awaitSpeakCompletion' Android'de bazen sorun çıkarabilir, 
      // çalışmazsa bu satırı yorum satırına almayı dene.
      await _flutterTts.awaitSpeakCompletion(true);

      _flutterTts.setStartHandler(() {
        if (mounted) setState(() => _isSpeaking = true);
      });

      _flutterTts.setCompletionHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint("TTS Hatası: $msg");
        if (mounted) setState(() => _isSpeaking = false);
      });
      
    } catch (e) {
      debugPrint("TTS Başlatma Hatası: $e");
    }
  }

  Future<void> _speakStep({String? customText}) async {
    // Eğer konuşuyorsa durdur
    if (_isSpeaking) {
      await _flutterTts.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return; // Fonksiyondan çık
    } 
    
    // Konuşmuyorsa başlat
    String textToSpeak = customText ?? (_steps.isNotEmpty ? _steps[_currentStep] : "");
    if (textToSpeak.isNotEmpty) {
      await _flutterTts.speak(textToSpeak);
    }
  }

  // --- TIMER ---
  void _startTimer(int minutes) {
    if (_countdownTimer != null) _countdownTimer!.cancel();
    setState(() {
      _remainingTime = Duration(minutes: minutes);
      _isTimerRunning = true;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        setState(() {
          _remainingTime = _remainingTime - const Duration(seconds: 1);
        });
      } else {
        _stopTimer();
        _speakStep(customText: "Süre doldu şefim!");
        _showTimeIsUpDialog();
      }
    });
  }

  void _stopTimer() {
    if (_countdownTimer != null) _countdownTimer!.cancel();
    setState(() {
      _isTimerRunning = false;
      _remainingTime = Duration.zero;
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  void _showTimerDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardTheme.color,
        title: const Text("Zamanlayıcı Kur"),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [1, 5, 10, 15, 20, 30, 45, 60].map((m) {
            return ActionChip(
              label: Text("$m dk"),
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              onPressed: () {
                Navigator.pop(context);
                _startTimer(m);
              },
            );
          }).toList(),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal"))],
      ),
    );
  }

  void _showTimeIsUpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("⏰ Süre Doldu!"),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tamam"))],
      ),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _pageController.dispose();
    _flutterTts.stop();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    double progress = _steps.isNotEmpty ? (_currentStep + 1) / _steps.length : 0.0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      
      appBar: AppBar(
        title: Text("Pişirme Modu", style: TextStyle(color: colorScheme.onSurface)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(_isTimerRunning ? Icons.timer_off : Icons.timer),
            color: _isTimerRunning ? Colors.orange : colorScheme.primary,
            onPressed: _isTimerRunning ? _stopTimer : _showTimerDialog,
          ),
          IconButton(
            icon: Icon(_isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up),
            color: _isSpeaking ? Colors.red : colorScheme.primary,
            onPressed: () => _speakStep(),
          ),
        ],
      ),
      
      body: SafeArea(
        child: Column(
          children: [
            // 1. ZAMANLAYICI
            if (_isTimerRunning)
              Container(
                width: double.infinity,
                color: Colors.orange.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    _formatDuration(_remainingTime),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ),
              ),

            // 2. PROGRESS BAR
            LinearProgressIndicator(
              value: progress,
              color: colorScheme.primary,
              backgroundColor: colorScheme.onSurface.withOpacity(0.1),
              minHeight: 6,
            ),

            // 3. ORTA ALAN (Metin)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentStep = index;
                    _isSpeaking = false;
                    _flutterTts.stop();
                  });
                },
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  return Container(
                    alignment: Alignment.center,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, 
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "ADIM ${index + 1}",
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              fontSize: 18
                            ),
                          ),
                          const SizedBox(height: 30),
                          
                          Text(
                            _steps[index],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22, 
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          
                          const SizedBox(height: 50),
                          
                          // ORTADAKİ SESLİ OKU BUTONU
                          SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () => _speakStep(),
                              icon: Icon(_isSpeaking ? Icons.stop : Icons.record_voice_over),
                              label: Text(_isSpeaking ? "Durdur" : "Sesli Oku"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary.withOpacity(0.1),
                                foregroundColor: colorScheme.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 30),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 4. ALT BUTONLAR (Sabit - Expanded ile düzeltildi)
            Container(
              padding: const EdgeInsets.all(24),
              color: theme.scaffoldBackgroundColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // GERİ BUTONU
                  if (_currentStep > 0)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text("Geri"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.surface,
                          foregroundColor: colorScheme.onSurface,
                        ),
                      ),
                    )
                  else
                    const Spacer(),

                  const SizedBox(width: 16),

                  // İLERİ / BİTİR BUTONU
                  Expanded(
                    child: _currentStep < _steps.length - 1
                        ? ElevatedButton.icon(
                            onPressed: () {
                              _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                            },
                            icon: const SizedBox.shrink(),
                            label: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [Text("İleri"), SizedBox(width: 5), Icon(Icons.arrow_forward)],
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onComplete();
                            },
                            icon: const Icon(Icons.check_circle),
                            label: const Text("Bitir"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
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