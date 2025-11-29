import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Tarih formatı için
import 'package:mutfak_asistani/features/home/home_screen.dart';
import 'package:mutfak_asistani/features/profile/statistics_screen.dart';
// RecipeProvider erişimi için
import '../pantry/pantry_service.dart';
import '../../core/models/pantry_item.dart';
import 'weather_service.dart';
// Sayfa geçişleri için (Tab değişimi)
import '../pantry/add_pantry_item_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onTabChange; // Sayfa değiştirmek için callback

  const DashboardScreen({super.key, required this.onTabChange});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final WeatherService _weatherService = WeatherService();
  final PantryService _pantryService = PantryService();
  
  Map<String, dynamic>? _weatherData;
  bool _loadingWeather = true;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    final data = await _weatherService.getWeather();
    if (mounted) {
      setState(() {
        _weatherData = data;
        _loadingWeather = false;
      });
    }
  }

  // Günün Tüyosu (Güne göre sabit değişir)
  String _getDailyTip() {
    final tips = [
      "Muzların sapını streç filmle sararsan daha geç kararır. 🍌",
      "Yemeğin tuzu fazla kaçarsa içine bir patates at, tuzu çeker. 🥔",
      "Bayat ekmekleri hafif ıslatıp fırınlayarak tazeleyebilirsin. 🥖",
      "Soğan doğrarken sakız çiğnemek göz yaşarmasını azaltır. 🧅",
      "Yumurtanın taze olup olmadığını anlamak için suya koy, batarsa tazedir. 🥚",
      "Limonları mikrodalgada 15 saniye ısıtırsan daha çok su verir. 🍋",
    ];
    // Yılın kaçıncı günü olduğuna göre mod alarak seç (Her gün değişir)
    final dayOfYear = int.parse(DateFormat("D").format(DateTime.now()));
    return tips[dayOfYear % tips.length];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER (SELAMLAMA & HAVA DURUMU)
              _buildHeader(colorScheme),
              
              const SizedBox(height: 24),
              
              // 2. ACİL DURUM PANOSU (SKT UYARILARI)
              const Text("⚠️ SKT Tarihi Bitmek Üzere Olanlar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildExpiryAlerts(colorScheme),

              const SizedBox(height: 24),

              // 3. HIZLI ERİŞİM (GRID)
              const Text("🚀 Hızlı Erişim", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildQuickActions(colorScheme),

              const SizedBox(height: 24),

              // 4. GÜNÜN TÜYOSU
              _buildDailyTip(colorScheme),
              
               const SizedBox(height: 80), // Alt navigasyon payı
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    String greeting = "Merhaba Şef! 👋";
    int hour = DateTime.now().hour;
    if (hour < 12) {
      greeting = "Günaydın Şef! 🍳";
    } else if (hour < 18) greeting = "İyi Günler Şef! ☀️";
    else greeting = "İyi Akşamlar Şef! 🌙";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                if (_loadingWeather)
                  const Text("Hava durumu alınıyor...", style: TextStyle(color: Colors.black54, fontSize: 12))
                else if (_weatherData != null && _weatherData!['success'] == true)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${_weatherData!['city']}: ${_weatherData!['temp']}°C, ${_weatherData!['description']}", 
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _weatherService.getSuggestion(_weatherData!['main'], _weatherData!['temp']),
                        style: const TextStyle(color: Colors.black54, fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                    ],
                  )
                else
                  const Text("Hava durumu bilgisine ulaşılamadı.", style: TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          // Hava Durumu İkonu (Basit)
          if (!_loadingWeather && _weatherData != null)
            Icon(
              _weatherData!['main'].toString().toLowerCase().contains('rain') ? Icons.thunderstorm : Icons.wb_sunny,
              size: 40,
              color: Colors.black87,
            )
        ],
      ),
    );
  }

  Widget _buildExpiryAlerts(ColorScheme colorScheme) {
    return StreamBuilder<List<PantryItem>>(
      stream: _pantryService.getPantryItems(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final now = DateTime.now();
        // 3 gün veya daha az kalanları filtrele
        final expiringItems = snapshot.data!.where((item) {
          if (item.expirationDate == null) return false;
          final diff = item.expirationDate!.difference(now).inDays;
          return diff <= 3 && diff >= -5; // Son 3 gün ve tarihi 5 gün geçmiş olanlar
        }).toList();

        if (expiringItems.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.3))
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 10),
                Expanded(child: Text("Süper! Bozulmak üzere olan ürünün yok.", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
              ],
            ),
          );
        }

        return SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: expiringItems.length,
            itemBuilder: (context, index) {
              final item = expiringItems[index];
              final daysLeft = item.expirationDate!.difference(now).inDays;
              final isExpired = daysLeft < 0;

              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isExpired ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isExpired ? Colors.red : Colors.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: isExpired ? Colors.red : Colors.orange),
                    const Spacer(),
                    Text(item.ingredientName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      isExpired ? "${daysLeft.abs()} gün geçti" : "$daysLeft gün kaldı",
                      style: TextStyle(color: isExpired ? Colors.red : Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      height: 30,
                      child: ElevatedButton(
                        onPressed: () {
                           // Direkt Şef sayfasına yönlendir ve bu malzemeyi seçtirt (Gelişmiş özellik)
                           // Şimdilik basitçe Şef sayfasına atalım
                           widget.onTabChange(2); // 2 = Şef Sayfası indexi
                        }, 
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: isExpired ? Colors.red : Colors.orange,
                          foregroundColor: Colors.white
                        ),
                        child: const Text("Değerlendir", style: TextStyle(fontSize: 11)),
                      ),
                    )
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(ColorScheme colorScheme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildActionCard(
          colorScheme, 
          "Fiş Tara", 
          Icons.camera_alt, 
          Colors.purple, 
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddPantryItemScreen()))
        ),
        _buildActionCard(
          colorScheme, 
          "Ne Pişirsem?", 
          Icons.restaurant_menu, 
          Colors.orange, 
          () => widget.onTabChange(2) // Şef sekmesi
        ),
        _buildActionCard(
          colorScheme, 
          "Alışveriş Listesi", 
          Icons.shopping_cart, 
          Colors.blue, 
          () {
            // 1. Önce Kilerim Sayfasını Aç (Index 1)
            widget.onTabChange(1);
            // 2. Sonra o sayfaya "Alışveriş Listesi sekmesine (Index 1) geç" sinyali gönder
            HomeScreen.tabChangeNotifier.value = 1; 
          }
        ),
        _buildActionCard(
          colorScheme, 
          "Mutfak Karnesi", 
          Icons.bar_chart, 
          Colors.green, 
          // DİREKT İSTATİSTİK EKRANINA GİT (Profil içine değil)
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StatisticsScreen())) 
        ),
      ],
    );
  }

  Widget _buildActionCard(ColorScheme colorScheme, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTip(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, color: Colors.amber, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Günün Tüyosu", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                const SizedBox(height: 4),
                Text(_getDailyTip(), style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withOpacity(0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}