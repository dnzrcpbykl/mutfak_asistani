import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/shopping_item.dart';

class ShoppingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Kullanıcının alışveriş listesine erişim referansı
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

  // 1. Listeyi Getir (Canlı)
  Stream<List<ShoppingItem>> getShoppingList() {
    // Eklenenler tarihe göre sıralı gelsin
    return _listRef.orderBy('createdAt', descending: true).snapshots().map(
        (snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // 2. Ürün Ekle
  Future<void> addItem(String name) async {
    if (name.trim().isEmpty) return;
    final newItem = ShoppingItem(id: '', name: name.trim(), isCompleted: false);
    await _listRef.add(newItem);
  }

  // 3. İşaretle / İşareti Kaldır (Toggle)
  Future<void> toggleStatus(String id, bool currentStatus) async {
    await _listRef.doc(id).update({'isCompleted': !currentStatus});
  }

  // 4. Sil
  Future<void> deleteItem(String id) async {
    await _listRef.doc(id).delete();
  }

  // 5. Tamamlananları Temizle (Toplu Silme - İsteğe Bağlı)
  Future<void> clearCompleted() async {
    final snapshot = await _listRef.where('isCompleted', isEqualTo: true).get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}