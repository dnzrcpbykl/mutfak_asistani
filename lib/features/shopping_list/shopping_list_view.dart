// lib/features/shopping_list/shopping_list_view.dart
import 'package:flutter/material.dart';
import 'shopping_service.dart';
import '../../core/models/shopping_item.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/widgets/empty_state_widget.dart';

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
                  ? const EmptyStateWidget(
                      icon: Icons.shopping_cart_outlined,
                      message: "Sepetin Bomboş!",
                      subMessage: "Hadi alttaki kutuya yazarak ihtiyaçlarını ekle.",
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      // Alt kısımdaki kutunun arkasında kalmasın diye boşluk bırakıyoruz
                      padding: const EdgeInsets.only(bottom: 100), 
                      itemBuilder: (context, index) {
                        final item = items[index];
                        // Animasyon eklenmiş Liste Elemanı
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          elevation: 2,
                          shadowColor: colorScheme.primary.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

            // --- 3. HIZLI EKLEME KUTUSU (SAFE AREA EKLENDİ) ---
            // Bu widget, alt navigasyon çubuğunun (Home/Back tuşları) üzerine binmeyi engeller.
            SafeArea(
              top: false, // Üst tarafı etkilemesin
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
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          icon: Icon(Icons.add_shopping_cart, color: colorScheme.primary),
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
            ),
          ],
        );
      },
    );
  }
}