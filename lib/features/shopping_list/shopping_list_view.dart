import 'package:flutter/material.dart';
import 'shopping_service.dart';
import '../../core/models/shopping_item.dart';

class ShoppingListView extends StatefulWidget {
  const ShoppingListView({super.key});

  @override
  State<ShoppingListView> createState() => _ShoppingListViewState();
}

class _ShoppingListViewState extends State<ShoppingListView> {
  final ShoppingService _service = ShoppingService();
  final TextEditingController _controller = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    // Tema verilerini en başta alıyoruz
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

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
            
            // --- 1. HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${items.length} Ürün",
                    style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold),
                  ),
                  
                  TextButton.icon(
                    onPressed: hasCompletedItems 
                        ? () async {
                            await _service.clearCompleted();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Tamamlananlar temizlendi.")),
                            );
                          }
                        : null, 
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text("Seçilenleri Temizle"),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      disabledForegroundColor: Colors.grey.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),

            // --- 2. LİSTE ---
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        "Listeniz boş.\nAlttaki kutucuğa yazıp ekleyebilirsiniz.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      padding: const EdgeInsets.only(bottom: 80),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          // Rengi ve gölgesi AppTheme'den otomatik gelir
                          child: ListTile(
                            leading: Checkbox(
                              value: item.isCompleted,
                              activeColor: colorScheme.primary, // Tik rengi (Neon/Turkuaz)
                              checkColor: colorScheme.onPrimary, // Tik işareti rengi
                              side: BorderSide(color: Colors.grey.shade400),
                              onChanged: (bool? value) {
                                _service.toggleStatus(item.id, item.isCompleted);
                              },
                            ),
                            title: Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                                // Tamamlandıysa gri, değilse temanın yazı rengi (Siyah/Beyaz)
                                color: item.isCompleted 
                                    ? Colors.grey 
                                    : colorScheme.onSurface,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              tooltip: "Listeden Sil",
                              onPressed: () {
                                _service.deleteItem(item.id);
                              },
                            ),
                            onTap: () {
                              _service.toggleStatus(item.id, item.isCompleted);
                            },
                          ),
                        );
                      },
                    ),
            ),

            // --- 3. HIZLI EKLEME KUTUSU ---
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              decoration: BoxDecoration(
                // KUTU RENGİ ÖNEMLİ: Light'ta Beyaz, Dark'ta Koyu Gri
                color: theme.cardTheme.color, 
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, -2)),
                ],
                // Sadece üstte ince bir çizgi olsun
                border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200))
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      // YAZI RENGİ: Light'ta Siyah, Dark'ta Beyaz
                      style: TextStyle(color: colorScheme.onSurface), 
                      decoration: InputDecoration(
                        hintText: "Hızlı ürün ekle (Örn: Ekmek)",
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        icon: Icon(Icons.add_shopping_cart, color: colorScheme.primary),
                        // AppTheme'de inputlara fill vermiştik, burada istemiyoruz çünkü zaten kutunun içindeyiz
                        filled: false, 
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
          ],
        );
      },
    );
  }
}