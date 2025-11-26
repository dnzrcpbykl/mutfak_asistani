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
      final pantrySnapshot = await _pantryService.pantryRef.get();
      double totalVal = 0;
      Map<String, double> cats = {};

      for (var doc in pantrySnapshot.docs) {
        final item = doc.data();
        double price = item.price ?? 0;
        // Fiyat 0 ise varsayılan bir değer atamıyoruz, sadece girilenleri topluyoruz
        totalVal += price;

        // Kategori sayımı
        if (!cats.containsKey(item.category)) {
          cats[item.category] = 0;
        }
        cats[item.category] = cats[item.category]! + 1;
      }

      // 2. AYLIK HARCAMA (Geçmiş + Mevcut)
      // Not: Tam bir "Harcama" analizi için hem şu an kilerde olanların ne zaman eklendiğine
      // hem de silinenlerin ne zaman eklendiğine bakmak gerekir.
      // Basitlik adına: Kilerdeki ürünlerin 'createdAt' tarihine göre aylık dökümünü alalım.
      // (Daha ileri seviyede 'receipts' koleksiyonu tutulabilir)
      
      Map<int, double> monthly = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0, 8:0, 9:0, 10:0, 11:0, 12:0};
      
      for (var doc in pantrySnapshot.docs) {
        final item = doc.data();
        DateTime date = item.createdAt.toDate();
        if (date.year == DateTime.now().year) { // Sadece bu yıl
          monthly[date.month] = monthly[date.month]! + (item.price ?? 0);
        }
      }

      // Geçmiş tüketim verilerini de ekleyelim (Logladıklarımız)
      final historySnapshot = await _pantryService.historyRef.get();
      for (var doc in historySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Eğer fiyat verisi varsa
        if (data['price'] != null) {
           // consumedAt tarihini al
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
                const Text("📅 Aylık Harcama (Bu Yıl)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                // 2. BAR CHART (AYLIK)
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _getMaxSpending() * 1.2, // Tepede boşluk olsun
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBgColor: Colors.blueGrey,
                        ),
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
                      barGroups: _getBarGroups(colorScheme),
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
                
                // Lejand (Pie Chart Altına)
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
        boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Kiler Değeri", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(
                "${_totalPantryValue.toStringAsFixed(2)} TL", 
                style: const TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold)
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_wallet, color: Colors.black, size: 30),
          )
        ],
      ),
    );
  }

  List<BarChartGroupData> _getBarGroups(ColorScheme colorScheme) {
    List<BarChartGroupData> groups = [];
    _monthlySpending.forEach((month, amount) {
      // Sadece harcama olan ayları veya hepsini gösterebilirsin
      if (amount > 0 || (month >= DateTime.now().month - 2 && month <= DateTime.now().month)) {
        groups.add(
          BarChartGroupData(
            x: month,
            barRods: [
              BarChartRodData(
                toY: amount,
                color: colorScheme.primary,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              )
            ],
          ),
        );
      }
    });
    return groups;
  }

  List<PieChartSectionData> _getPieSections() {
    List<PieChartSectionData> sections = [];
    _categoryDistribution.forEach((cat, count) {
      sections.add(
        PieChartSectionData(
          color: _getCategoryColor(cat),
          value: count,
          title: '${count.toInt()}',
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

  Color _getCategoryColor(String category) {
    switch (category) {
      case "Meyve & Sebze": return Colors.green;
      case "Et & Tavuk & Balık": return Colors.redAccent;
      case "Süt & Kahvaltılık": return Colors.amber;
      case "Atıştırmalık": return Colors.purpleAccent;
      case "İçecekler": return Colors.blue;
      case "Temel Gıda & Bakliyat": return Colors.brown;
      default: return Colors.grey;
    }
  }
}