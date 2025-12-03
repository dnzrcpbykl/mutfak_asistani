import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../pantry/pantry_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final PantryService _pantryService = PantryService();
  
  // Veriler
  double _totalPantryValue = 0.0;
  Map<String, double> _categoryDistribution = {};
  Map<int, double> _monthlySpending = {}; // AyIndex (1-12) : Tutar

  // Seçili Ay Gösterimi (Tıklama için)
  double? _selectedMonthValue;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  Future<void> _calculateStats() async {
    setState(() => _isLoading = true);
    try {
      // 1. MEVCUT KİLER DEĞERİ VE KATEGORİLER
      // Düzeltme: Artık hangi kileri (Aile/Bireysel) kullanıyorsak oradan çekiyoruz
      final ref = await _pantryService.getPantryCollection();
      final pantrySnapshot = await ref.get();
      
      double totalVal = 0;
      Map<String, double> cats = {};

      for (var doc in pantrySnapshot.docs) {
        final item = doc.data();
        double price = item.price ?? 0;
        totalVal += price;
        
        // Kategori sayımı
        if (!cats.containsKey(item.category)) {
          cats[item.category] = 0;
        }
        cats[item.category] = cats[item.category]! + 1;
      }

      // 2. AYLIK HARCAMA (Geçmiş + Mevcut)
      // Varsayılan olarak tüm ayları 0 ile başlat
      Map<int, double> monthly = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0, 8:0, 9:0, 10:0, 11:0, 12:0};
      
      // Kilerdeki ürünlerin harcama zamanı
      for (var doc in pantrySnapshot.docs) {
        final item = doc.data();
        DateTime date = item.createdAt.toDate();
        // Sadece bu yılın verilerini al
        if (date.year == DateTime.now().year) {
          monthly[date.month] = monthly[date.month]! + (item.price ?? 0);
        }
      }

      // Geçmiş tüketim/silinme verilerini de ekle
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);

      final historySnapshot = await _pantryService.historyRef
          .where('consumedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
          .get();
          
      for (var doc in historySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['price'] != null) {
           Timestamp? ts = data['consumedAt'];
           if (ts != null) {
             DateTime date = ts.toDate();
             if (date.year == DateTime.now().year) {
               monthly[date.month] = monthly[date.month]! + (data['price'] as num).toDouble();
             }
           }
        }
      }

      if (mounted) {
        setState(() {
          _totalPantryValue = totalVal;
          _categoryDistribution = cats;
          _monthlySpending = monthly;
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint("İstatistik hatası: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Mutfak İstatistikleri")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. ÖZET KARTI
                _buildSummaryCard(colorScheme),
                
                const SizedBox(height: 24),
                const Text("📅 Aylık Harcama (Son 5 Ay)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                // 2. BAR CHART (AYLIK)
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _getMaxSpending() * 1.2,
                      // TIKLAMA VE TOOLTIP AYARLARI
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          // Tooltip arka plan rengi
                          tooltipBgColor: Colors.blueGrey,
                          // ÇUBUĞUN ÜSTÜNDE ÇIKAN YAZI AYARI
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              // BURASI DÜZELTİLDİ: toStringAsFixed(2) ile virgülden sonra 2 basamak
                              '${rod.toY.toStringAsFixed(2)} TL', 
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                        // TIKLAMA İŞLEMİ
                        touchCallback: (FlTouchEvent event, barTouchResponse) {
                          if (!event.isInterestedForInteractions || barTouchResponse == null || barTouchResponse.spot == null) {
                            return;
                          }
                          // Tıklanan çubuğun değerini alıp aşağıya yazdıracağız
                          setState(() {
                            final spot = barTouchResponse.spot!;
                            _selectedMonthValue = spot.touchedRodData.toY;
                          });
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              const style = TextStyle(fontSize: 10, fontWeight: FontWeight.bold);
                              String text = _getMonthName(value.toInt());
                              return SideTitleWidget(axisSide: meta.axisSide, child: Text(text, style: style));
                            },
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      // SADECE SON 5 AYI GÖSTEREN GRUPLAR
                      barGroups: _getLast5MonthsGroups(colorScheme), 
                    ),
                  ),
                ),

                // TIKLANAN AY DETAYI
                if (_selectedMonthValue != null)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withAlpha((0.1 * 255).round()),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorScheme.primary)
                      ),
                      child: Text(
                        "Seçilen Ay Harcaması: ${_selectedMonthValue!.toStringAsFixed(2)} TL",
                        style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
                      ),
                    ),
                  ),

                const SizedBox(height: 30),
                const Text("🍩 Kiler Dağılımı", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // 3. PIE CHART (KATEGORİ)
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: _getPieSections(),
                    ),
                  ),
                ),
                
                // LEJAND
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _categoryDistribution.keys.map((cat) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: _getCategoryColor(cat)),
                        ),
                        const SizedBox(width: 4),
                        Text(cat, style: const TextStyle(fontSize: 12)),
                      ],
                    );
                  }).toList(),
                )
              ],
            ),
          ),
    );
  }

  Widget _buildSummaryCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colorScheme.primary, colorScheme.secondary]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: colorScheme.primary.withAlpha((0.3 * 255).round()), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Kiler Değeri", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              // BURADA DA KÜSURAT DÜZELTİLDİ
              Text(
                "${_totalPantryValue.toStringAsFixed(2)} TL", 
                style: const TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold)
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withAlpha((0.3 * 255).round()), shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_wallet, color: Colors.black, size: 30),
          )
        ],
      ),
    );
  }

  // --- YENİ FONKSİYON: SADECE SON 5 AYI GETİRİR ---
  List<BarChartGroupData> _getLast5MonthsGroups(ColorScheme colorScheme) {
    List<BarChartGroupData> groups = [];
    DateTime now = DateTime.now();
    
    // Son 5 ayı döngüye al (i=4 demek, 4 ay öncesinden başla demek)
    for (int i = 4; i >= 0; i--) {
      // Ay hesapla (Örn: Şu an Mart ise -> Kasım, Aralık, Ocak, Şubat, Mart)
      // Basitlik için sadece bu yılın verilerini çekiyoruz demiştik, o yüzden indexleri 1-12 arasında tutalım.
      // Eğer yıl devri yapacaksak map yapısını ona göre kurmak gerekir. 
      // Şimdilik sadece bu yılın aylarını gösterelim:
      int targetMonth = now.month - i;
      
      if (targetMonth > 0) {
        double amount = _monthlySpending[targetMonth] ?? 0.0;
        groups.add(
          BarChartGroupData(
            x: targetMonth,
            barRods: [
              BarChartRodData(
                toY: amount,
                color: colorScheme.primary,
                width: 20, // Çubukları biraz kalınlaştırdım
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: _getMaxSpending() * 1.1, // Arka plan gri çubuk
                  color: Colors.grey.withAlpha((0.1 * 255).round()),
                ),
              )
            ],
          ),
        );
      }
    }
    return groups;
  }

  List<PieChartSectionData> _getPieSections() {
    List<PieChartSectionData> sections = [];
    _categoryDistribution.forEach((cat, itemCount) {
      sections.add(
        PieChartSectionData(
          color: _getCategoryColor(cat),
          value: itemCount,
          title: '${itemCount.toInt()}',
          radius: 50,
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    });
    return sections;
  }

  double _getMaxSpending() {
    double max = 0;
    _monthlySpending.forEach((_, v) {
      if (v > max) max = v;
    });
    return max == 0 ? 100 : max;
  }

  String _getMonthName(int month) {
    const months = ["", "Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];
    if (month >= 1 && month <= 12) return months[month];
    return "";
  }

  // --- RENK DÜZELTMESİ YAPILDI ---
  // İsimler artık veritabanındaki (PantryTab) isimlerle birebir aynı.
  Color _getCategoryColor(String category) {
    // String karşılaştırması yaparken küçük harfe çevirelim ve boşlukları temizleyelim ki hata olmasın
    final catLower = category.toLowerCase().trim();

    if (catLower.contains("meyve") && catLower.contains("sebze")) return Colors.green;
    if (catLower.contains("et") || catLower.contains("tavuk") || catLower.contains("balık")) return Colors.redAccent;
    if (catLower.contains("süt") || catLower.contains("kahvaltı")) return Colors.amber;
    if (catLower.contains("atıştırmalık") || catLower.contains("tatlı")) return Colors.purpleAccent;
    if (catLower.contains("içecek")) return Colors.blue;
    if (catLower.contains("temel") || catLower.contains("bakliyat")) return Colors.brown;
    if (catLower.contains("temizlik") || catLower.contains("bakım")) return Colors.teal;
    
    return Colors.grey;
  }
}