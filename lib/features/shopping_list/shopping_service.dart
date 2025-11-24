// lib/features/shopping_list/shopping_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/shopping_item.dart';

class ShoppingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<ShoppingItem> get _listRef {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception("Kullanıcı yok");
    
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('shopping_list')
        .withConverter<ShoppingItem>(
          fromFirestore: (snapshot, _) => ShoppingItem.fromFirestore(snapshot),
          toFirestore: (item, _) => item.toFirestore(),
        );
  }

  Stream<List<ShoppingItem>> getShoppingList() {
    return _listRef.orderBy('createdAt', descending: true).snapshots().map(
        (snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // --- GÜNCELLENEN KISIM: BÜYÜK/KÜÇÜK HARF DUYARSIZ KONTROL ---
  Future<bool> addItem(String name) async {
    final cleanName = name.trim(); // Baştaki/sondaki boşlukları al
    if (cleanName.isEmpty) return false;

    // 1. Veritabanından henüz "alınmamış" (isCompleted: false) tüm ürünleri çek
    final activeItemsSnapshot = await _listRef
        .where('isCompleted', isEqualTo: false) 
        .get();

    // 2. Dart tarafında döngüyle kontrol et (En güvenli yöntem)
    // "Ekmek", "ekmek", "EKMEK" -> hepsi "ekmek" olur ve eşleşir.
    for (var doc in activeItemsSnapshot.docs) {
      final existingName = doc.data().name;
      
      if (existingName.toLowerCase() == cleanName.toLowerCase()) {
        // Zaten listede var (Büyük/küçük harf farketmeksizin)
        return false; 
      }
    }

    // 3. Eşleşme yoksa ekle (Kullanıcının yazdığı orijinal haliyle)
    final newItem = ShoppingItem(id: '', name: cleanName, isCompleted: false);
    await _listRef.add(newItem);
    return true;
  }
  // -------------------------------------------------------------

  Future<void> toggleStatus(String id, bool currentStatus) async {
    await _listRef.doc(id).update({'isCompleted': !currentStatus});
  }

  Future<void> deleteItem(String id) async {
    await _listRef.doc(id).delete();
  }

  Future<void> clearCompleted() async {
    final snapshot = await _listRef.where('isCompleted', isEqualTo: true).get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}