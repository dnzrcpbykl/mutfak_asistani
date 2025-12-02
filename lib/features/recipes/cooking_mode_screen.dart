import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/models/recipe.dart';

class CookingModeScreen extends StatefulWidget {
  final Recipe recipe;
  final VoidCallback onComplete;

  const CookingModeScreen({super.key, required this.recipe, required this.onComplete});

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  late List<String> _steps;
  final PageController _pageController = PageController();
  int _currentStep = 0;
  
  // TTS (Ses)
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  // Timer
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;
  bool _isTimerRunning = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Ekran kapanmasın
    _steps = _parseInstructions(widget.recipe.instructions);
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("tr-TR");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      
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
      debugPrint("TTS Başlatma Hatası: $e");
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
        _speakStep(customText: "Süre doldu şefim! Kontrol etme zamanı.");
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
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _showTimerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: const Text("Zamanlayıcı Kur ⏱️"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTimerOption(1),
                _buildTimerOption(5),
                _buildTimerOption(10),
                _buildTimerOption(15),
                _buildTimerOption(20),
                _buildTimerOption(30),
                _buildTimerOption(45),
                _buildTimerOption(60),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
        ],
      ),
    );
  }

  Widget _buildTimerOption(int minutes) {
    return ActionChip(
      label: Text("$minutes dk"),
      onPressed: () {
        Navigator.pop(context);
        _startTimer(minutes);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$minutes dakikalık sayaç başladı!")));
      },
    );
  }

  void _showTimeIsUpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("⏰ Süre Doldu!"),
        content: const Text("Yemeğini kontrol etmeyi unutma."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tamam")),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _pageController.dispose();
    _flutterTts.stop();
    if (_countdownTimer != null) _countdownTimer!.cancel();
    super.dispose();
  }

  List<String> _parseInstructions(String text) {
    if (text.isEmpty) return ["Tarif adımları bulunamadı."];
    final numberSplit = text.split(RegExp(r'\d+\.\s+'));
    List<String> cleanList = numberSplit.where((s) => s.trim().isNotEmpty).map((s) => s.trim()).toList();
    if (cleanList.length > 1) return cleanList;
    final lineSplit = text.split('\n');
    cleanList = lineSplit.where((s) => s.trim().isNotEmpty).map((s) => s.trim()).toList();
    if (cleanList.length > 1) return cleanList;
    return [text];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Progress hesabı (0'a bölünme hatasını önle)
    double progress = 0.0;
    if (_steps.isNotEmpty) {
      progress = (_currentStep + 1) / _steps.length;
    }

    return Scaffold(
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
          const SizedBox(width: 10),
        ],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      // SafeArea kullanmıyoruz ki alt bar tam otursun, padding'i içeride veririz
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, // Yatayda fulle (Infinite width hatasını çözer)
        children: [
          // --- SAYAÇ ---
          if (_isTimerRunning)
            Container(
              width: double.infinity, // Column stretch olduğu için burası güvenli
              color: Colors.orange.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(_remainingTime),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ),

          // --- PROGRESS BAR ---
          LinearProgressIndicator(
            value: progress,
            backgroundColor: colorScheme.onSurface.withOpacity(0.1),
            color: colorScheme.primary,
            minHeight: 6,
          ),
          
          // --- ADIMLAR (SAYFA) ---
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
                        const SizedBox(height: 40),
                        
                        FilledButton.tonalIcon(
                          onPressed: () => _speakStep(),
                          icon: Icon(_isSpeaking ? Icons.stop : Icons.record_voice_over),
                          label: Text(_isSpeaking ? "Durdur" : "Sesli Oku"),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // --- ALT KONTROLLER ---
          Container(
            color: theme.scaffoldBackgroundColor,
            child: SafeArea( // iPhone home bar için
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
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
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      )
                    else 
                      const SizedBox(width: 80), // Boşluk

                    // İLERİ / TAMAMLA BUTONU
                    if (_currentStep < _steps.length - 1)
                      ElevatedButton.icon(
                        onPressed: () {
                          _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                        },
                        icon: const SizedBox.shrink(),
                        label: const Row(
                          children: [
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
                          Navigator.pop(context); 
                          widget.onComplete(); 
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text("Tamamla!"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}