import 'dart:async';
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
    // Klavye odağını temizle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });

    WakelockPlus.enable(); 
    _steps = _parseInstructions(widget.recipe.instructions);
    _initTts();
  }

  // --- PARSER ---
  List<String> _parseInstructions(String text) {
    if (text.trim().isEmpty) return ["Tarif adımları yüklenemedi."];
    String cleanText = text.replaceAll('**', '').trim();
    
    final stepSplit = cleanText.split(RegExp(r'(^|\n)\s*\d+[\.\)\:]\s+'));
    List<String> cleanList = stepSplit
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 3) 
        .toList();

    if (cleanList.length < 2) {
      cleanList = cleanText.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    if (cleanList.length < 2) {
       cleanList = cleanText.split('. ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return cleanList.isNotEmpty ? cleanList : [cleanText];
  }

  // --- TTS ---
  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("tr-TR");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.awaitSpeakCompletion(true);
      
      _flutterTts.setStartHandler(() {
        if (mounted) setState(() => _isSpeaking = true);
      });
      _flutterTts.setCompletionHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });
      _flutterTts.setErrorHandler((msg) {
        if (mounted) setState(() => _isSpeaking = false);
      });
    } catch (e) {
      debugPrint("TTS Hatası: $e");
    }
  }

  Future<void> _speakStep({String? customText}) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    } else {
      String textToSpeak = customText ?? (_steps.isNotEmpty ? _steps[_currentStep] : "");
      if (textToSpeak.isNotEmpty) {
        await _flutterTts.speak(textToSpeak);
      }
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

    // Scaffold içinde güvenli alan yönetimi
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
      
      // --- YAPISAL DÜZELTME: Column + Expanded ---
      // Stack yerine bu yapıyı kullanıyoruz. Bu yapı widgetların üst üste binmesini engeller.
      body: SafeArea(
        child: Column(
          children: [
            // 1. ZAMANLAYICI (Varsa)
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

            // 3. ORTA ALAN (Expanded PageView)
            // Expanded, kalan tüm boşluğu doldurur. Hata vermez.
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
                  // İçeriği ortalamak için Container Alignment kullanıyoruz
                  return Container(
                    alignment: Alignment.center, // Dikey ve yatay ortala
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
                              fontSize: 18
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
                          
                          const SizedBox(height: 50),
                          
                          // SESLİ OKU BUTONU (Burada olması tıklanabilirliği garantiler)
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

            // 4. ALT BUTONLAR (Sabit)
            Container(
              padding: const EdgeInsets.all(24),
              color: theme.scaffoldBackgroundColor, // Arkası şeffaf olmasın
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // GERİ
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
                    const SizedBox(width: 80),

                  // İLERİ / BİTİR
                  if (_currentStep < _steps.length - 1)
                    ElevatedButton.icon(
                      onPressed: () {
                        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      },
                      icon: const SizedBox.shrink(),
                      label: const Row(children: [Text("İleri"), SizedBox(width: 5), Icon(Icons.arrow_forward)]),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                    )
                  else
                    ElevatedButton.icon(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}