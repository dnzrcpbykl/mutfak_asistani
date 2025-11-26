import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/ingredient.dart';
import '../../core/models/pantry_item.dart';

class PantryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Ingredient> get ingredientsRef => 
      _firestore.collection('ingredients').withConverter<Ingredient>(
        fromFirestore: (snapshot, _) => Ingredient.fromFirestore(snapshot),
        toFirestore: (ingredient, _) => ingredient.toFirestore(),
      );

  CollectionReference<PantryItem> get pantryRef {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception("Kullanıcı girişi yapılmamış.");
    return _firestore.collection('users').doc(userId).collection('pantry').withConverter<PantryItem>(
      fromFirestore: (snapshot, _) => PantryItem.fromFirestore(snapshot),
      toFirestore: (item, _) => item.toFirestore(),
    );
  }

  // --- YENİ: TÜKETİM GEÇMİŞİ KOLEKSİYONU ---
  CollectionReference get historyRef {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception("Kullanıcı girişi yapılmamış.");
    return _firestore.collection('users').doc(userId).collection('consumption_history');
  }

  Future<void> addIngredientToSystem(Ingredient ingredient) async {
    await ingredientsRef.add(ingredient);
  }

  Future<void> addPantryItem(PantryItem item) async {
    await pantryRef.add(item);
  }

  Stream<List<PantryItem>> getPantryItems() {
    return pantryRef.snapshots().map((snapshot) => 
      snapshot.docs.map((doc) => doc.data()).toList()
    );
  }

  Future<List<Ingredient>> searchIngredients(String query) async {
    final snapshot = await ingredientsRef
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // --- GÜNCELLENEN: SİLERKEN GEÇMİŞE KAYDET ---
  Future<void> deletePantryItem(String itemId) async {
    // 1. Önce silinecek öğenin verisini al
    final doc = await pantryRef.doc(itemId).get();
    if (doc.exists) {
      final item = doc.data()!;
      // 2. Geçmişe (History) kaydet
      await historyRef.add({
        'name': item.ingredientName,
        'category': item.category,
        'quantity': item.quantity,
        'unit': item.unit,
        'price': item.price,
        'consumedAt': FieldValue.serverTimestamp(), // Tüketilme tarihi
        'type': 'deleted' // Tamamen bitti/silindi
      });
    }
    // 3. Kilerden sil
    await pantryRef.doc(itemId).delete();
  }
  
  // --- GÜNCELLENEN: MİKTAR DÜŞERKEN GEÇMİŞE KAYDET ---
  Future<void> updatePantryItemQuantity(String itemId, double newQuantity, {int? newPieceCount}) async {
    // Eskiyi alıp ne kadar düştüğünü hesaplayalım
    final doc = await pantryRef.doc(itemId).get();
    if (doc.exists) {
      final oldItem = doc.data()!;
      double diff = oldItem.quantity - newQuantity;
      
      // Eğer miktar azaldıysa (Tüketim varsa)
      if (diff > 0) {
        await historyRef.add({
          'name': oldItem.ingredientName,
          'category': oldItem.category,
          'quantity': diff, // Tüketilen miktar
          'unit': oldItem.unit,
          'price': (oldItem.price ?? 0) * (diff / oldItem.quantity), // Tüketilen kısmın maliyeti
          'consumedAt': FieldValue.serverTimestamp(),
          'type': 'consumed' // Kısmen kullanıldı
        });
      }
    }

    final Map<String, dynamic> data = {'quantity': newQuantity};
    if (newPieceCount != null) {
      data['pieceCount'] = newPieceCount;
    }
    await pantryRef.doc(itemId).update(data);
  }

  Future<void> updatePantryItemDetails({
    required String itemId,
    required String name,
    required double quantity,
    required String unit,
    required DateTime? expirationDate,
    required String category,
    required int pieceCount,
  }) async {
    await pantryRef.doc(itemId).update({
      'ingredientName': name,
      'quantity': quantity,
      'unit': unit,
      'expirationDate': expirationDate != null ? Timestamp.fromDate(expirationDate) : null,
      'category': category,
      'pieceCount': pieceCount,
    });
  }

  Future<void> consumeIngredients(List<String> ingredientNames) async {
    final pantrySnapshot = await pantryRef.get();
    final pantryItems = pantrySnapshot.docs.map((doc) => doc.data()).toList();

    for (String ingredientName in ingredientNames) {
      try {
        final itemToUpdate = pantryItems.firstWhere(
          (item) => item.ingredientName.trim().toLowerCase() == ingredientName.trim().toLowerCase()
        );
        
        if (itemToUpdate.quantity > 1) {
          await updatePantryItemQuantity(itemToUpdate.id, itemToUpdate.quantity - 1);
        } else {
          await deletePantryItem(itemToUpdate.id);
        }
      } catch (e) {
        continue;
      }
    }
  }
}