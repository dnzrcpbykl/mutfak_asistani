// lib/features/profile/saved_recipes_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SavedRecipesScreen extends StatelessWidget {
  const SavedRecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Oturum açmalısınız.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Favori Tariflerim"),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Sadece bu kullanıcının kaydettiği tarifleri getir
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('saved_recipes')
            .orderBy('savedAt', descending: true) // En son eklenen en üstte
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    "Henüz favori tarifin yok.",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ExpansionTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.red,
                    child: Icon(Icons.restaurant, color: Colors.white),
                  ),
                  title: Text(
                    data['name'] ?? 'İsimsiz Tarif', 
                    style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                  subtitle: Text("${data['category'] ?? 'Genel'} • ${data['difficulty'] ?? 'Orta'}"),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Malzemeler:", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text((data['ingredients'] as List<dynamic>).join(", ")),
                          const SizedBox(height: 10),
                          const Text("Yapılışı:", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(data['instructions'] ?? ''),
                          const SizedBox(height: 10),
                          // SİLME BUTONU
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .collection('saved_recipes')
                                    .doc(docId)
                                    .delete();
                                
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Favorilerden kaldırıldı.")),
                                );
                              },
                              icon: const Icon(Icons.delete, color: Colors.red),
                              label: const Text("Favorilerden Sil", style: TextStyle(color: Colors.red)),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}