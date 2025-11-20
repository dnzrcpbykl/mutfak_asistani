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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. LİSTE KISMI
        Expanded(
          child: StreamBuilder<List<ShoppingItem>>(
            stream: _service.getShoppingList(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("Hata oluştu"));
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final items = snapshot.data ?? [];

              if (items.isEmpty) {
                return const Center(
                  child: Text(
                    "Listeniz boş.\nAlttaki kutucuğa yazıp ekleyebilirsiniz.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Dismissible(
                    key: Key(item.id),
                    background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                    onDismissed: (direction) => _service.deleteItem(item.id),
                    child: CheckboxListTile(
                      title: Text(
                        item.name,
                        style: TextStyle(
                          decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                          color: item.isCompleted ? Colors.grey : null,
                        ),
                      ),
                      value: item.isCompleted,
                      onChanged: (bool? value) {
                        _service.toggleStatus(item.id, item.isCompleted);
                      },
                      activeColor: Colors.orange,
                    ),
                  );
                },
              );
            },
          ),
        ),

        // 2. HIZLI EKLEME KISMI (EN ALTTA)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 5, offset: const Offset(0, -2)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: "Hızlı ürün ekle (Örn: Ekmek)",
                    border: InputBorder.none,
                  ),
                  onSubmitted: (value) { // Klavyeden Enter'a basınca
                    if (value.isNotEmpty) {
                      _service.addItem(value);
                      _controller.clear();
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.orange),
                onPressed: () {
                  if (_controller.text.isNotEmpty) {
                    _service.addItem(_controller.text);
                    _controller.clear();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}