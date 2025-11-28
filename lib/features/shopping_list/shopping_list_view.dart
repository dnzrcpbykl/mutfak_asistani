import 'package:flutter/material.dart';
import 'shopping_service.dart';
import '../../core/models/shopping_item.dart';
import '../../core/models/market_price.dart'; 
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../market/market_service.dart'; 
import '../../core/utils/market_utils.dart'; // MarketUtils Eklendi
import '../../core/utils/pdf_export_service.dart';
import '../profile/profile_service.dart';
import '../profile/premium_screen.dart';

class ShoppingListView extends StatefulWidget {
  const ShoppingListView({super.key});
  @override
  State<ShoppingListView> createState() => _ShoppingListViewState();
}

class _ShoppingListViewState extends State<ShoppingListView> with AutomaticKeepAliveClientMixin {
  final ShoppingService _service = ShoppingService();
  final MarketService _marketService = MarketService(); 
  final TextEditingController _controller = TextEditingController();
  final PdfExportService _pdfService = PdfExportService(); // EKLENDİ
final ProfileService _profileService = ProfileService(); // EKLENDİ

  @override
  bool get wantKeepAlive => true;

  void _urunEkle() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final basarili = await _service.addItem(text);
    if (!mounted) return;

    if (basarili) {
      _controller.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Bu ürün zaten listenizde var!"),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _shareList(List<ShoppingItem> items) async {
  if (items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Liste boş, paylaşılacak bir şey yok.")));
    return;
  }

  // Premium Kontrolü
  final status = await _profileService.checkUsageRights();
  if (!status['isPremium']) {
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumScreen()));
    return;
  }

  // PDF Oluştur ve Paylaş
  await _pdfService.shareShoppingList(items);
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<List<MarketPrice>>(
      future: _marketService.getAllPrices(), 
      builder: (context, priceSnapshot) {
        final allPrices = priceSnapshot.data ?? [];

        return StreamBuilder<List<ShoppingItem>>(
          stream: _service.getShoppingList(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final items = snapshot.data ?? [];
            final bool hasCompletedItems = items.any((item) => item.isCompleted);

            return Column(
              children: [
                // --- HEADER ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${items.length} Ürün",
                        style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold),
                      ),

                      IconButton(
                    icon: const Icon(Icons.share, color: Colors.blue),
                    tooltip: "PDF Olarak Paylaş (Premium)",
                    onPressed: () => _shareList(items),
                        ),
                      TextButton.icon(
                        onPressed: hasCompletedItems 
                            ? () async {
                                await _service.clearCompleted();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Temizlendi.")),
                                );
                              }
                            : null, 
                        icon: const Icon(Icons.delete_sweep),
                        label: const Text("Temizle"),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          disabledForegroundColor: Colors.grey.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- LİSTE ---
                Expanded(
                  child: items.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.shopping_cart_outlined,
                          message: "Sepetin Bomboş!",
                          subMessage: "Aşağıdan ürün ekleyerek fiyatları gör.",
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          padding: const EdgeInsets.only(bottom: 100), 
                          itemBuilder: (context, index) {
                            final item = items[index];
                            
                            // -- FİYAT HESAPLAMA (TÜM LİSTE) --
                            List<Map<String, dynamic>> allPricesForItem = [];
                            if (!item.isCompleted) { 
                              allPricesForItem = _marketService.findAllPricesFor(item.name, allPrices);
                            }
                            // --------------------------------

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              elevation: 2,
                              shadowColor: colorScheme.primary.withOpacity(0.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Checkbox(
                                  value: item.isCompleted,
                                  activeColor: colorScheme.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (bool? value) {
                                    _service.toggleStatus(item.id, item.isCompleted);
                                  },
                                ),
                                title: Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                                    color: item.isCompleted ? Colors.grey : colorScheme.onSurface,
                                  ),
                                ),
                                
                                // --- GÜNCELLENEN SUBTITLE (LOGOLU FİYAT LİSTESİ) ---
                                subtitle: (allPricesForItem.isNotEmpty) 
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: allPricesForItem.asMap().entries.map((entry) {
                                          final int idx = entry.key;
                                          final Map<String, dynamic> priceInfo = entry.value;
                                          final bool isCheapest = idx == 0;
                                          final String marketName = priceInfo['market'];
                                          final String logoPath = MarketUtils.getLogoPath(marketName);

                                          return InkWell(
                                            // LOGOYA TIKLAYINCA LİNKE GİT
                                            onTap: () => MarketUtils.launchMarketLink(marketName),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isCheapest ? Colors.green.withOpacity(0.1) : theme.cardColor,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isCheapest ? Colors.green.withOpacity(0.5) : Colors.grey.withOpacity(0.3)
                                                )
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // LOGO VARSA GÖSTER, YOKSA İKON
                                                  logoPath.isNotEmpty
                                                      ? Image.asset(logoPath, height: 16, width: 40, fit: BoxFit.contain) 
                                                      : Icon(Icons.store, size: 16, color: Colors.grey),
                                                  
                                                  const SizedBox(width: 8),
                                                  
                                                  Text(
                                                    "${priceInfo['price']} TL", 
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: isCheapest ? Colors.green[700] : colorScheme.onSurface
                                                    )
                                                  ),
                                                  
                                                  const SizedBox(width: 4),
                                                  // Dışa aktarım ikonu (Link olduğunu belirtmek için)
                                                  Icon(Icons.open_in_new, size: 10, color: colorScheme.onSurface.withOpacity(0.4))
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    )
                                  : null,
                                // ----------------------------------------------------

                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => _service.deleteItem(item.id),
                                ),
                                onTap: () => _service.toggleStatus(item.id, item.isCompleted),
                              ),
                            )
                            .animate(delay: (index * 50).ms) 
                            .slideX(begin: 1, end: 0, curve: Curves.easeOutQuad) 
                            .fadeIn();
                          },
                        ),
                ),

                // --- HIZLI EKLEME KUTUSU ---
                SafeArea(
                  top: false, 
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color, 
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, -2)),
                      ],
                      border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200))
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            textCapitalization: TextCapitalization.sentences,
                            style: TextStyle(color: colorScheme.onSurface), 
                            decoration: InputDecoration(
                              hintText: "Hızlı ürün ekle (Örn: Ekmek)",
                              hintStyle: const TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              icon: Icon(Icons.add_shopping_cart, color: colorScheme.primary),
                            ),
                            onSubmitted: (_) => _urunEkle(),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.send, color: colorScheme.primary, size: 28),
                          onPressed: _urunEkle,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }
    );
  }
}