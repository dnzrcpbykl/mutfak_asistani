// lib/features/pantry/pantry_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/ingredient.dart';
import '../../core/models/pantry_item.dart';

class PantryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Tüm malzemeler (Ingredients) koleksiyonu
  CollectionReference<Ingredient> get ingredientsRef => 
      _firestore.collection('ingredients').withConverter<Ingredient>(
        fromFirestore: (snapshot, _) => Ingredient.fromFirestore(snapshot),
        toFirestore: (ingredient, _) => ingredient.toFirestore(),
      );

  // Kullanıcının kilerindeki ürünler (PantryItem) koleksiyonu
  CollectionReference<PantryItem> get pantryRef {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception("Kullanıcı girişi yapılmamış.");
    }
    return _firestore.collection('users').doc(userId).collection('pantry').withConverter<PantryItem>(
      fromFirestore: (snapshot, _) => PantryItem.fromFirestore(snapshot),
      toFirestore: (item, _) => item.toFirestore(),
    );
  }

  // Yeni bir malzemeyi (Ingredient) sisteme ekler
  Future<void> addIngredientToSystem(Ingredient ingredient) async {
    await ingredientsRef.add(ingredient);
  }

  // Kullanıcının kilerine ürün ekler
  Future<void> addPantryItem(PantryItem item) async {
    await pantryRef.add(item);
  }

  // Kullanıcının kilerindeki ürünleri listeler
  Stream<List<PantryItem>> getPantryItems() {
    return pantryRef.snapshots().map((snapshot) => 
      snapshot.docs.map((doc) => doc.data()).toList()
    );
  }

  // Belirli bir malzemeyi ismine göre arar
  Future<List<Ingredient>> searchIngredients(String query) async {
    final snapshot = await ingredientsRef
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Kilerdeki bir ürünü siler
  Future<void> deletePantryItem(String itemId) async {
    await pantryRef.doc(itemId).delete();
  }
  
  // --- EKSİK OLAN FONKSİYON 1: Sadece Miktar Güncelleme ---
  Future<void> updatePantryItemQuantity(String itemId, double newQuantity) async {
    await pantryRef.doc(itemId).update({'quantity': newQuantity});
  }

  // --- EKSİK OLAN FONKSİYON 2: Detaylı Düzenleme (Edit Ekranı İçin) ---
  Future<void> updatePantryItemDetails({
    required String itemId,
    required String name,
    required double quantity,
    required String unit,
    required DateTime? expirationDate,
    required String category,
  }) async {
    await pantryRef.doc(itemId).update({
      'ingredientName': name,
      'quantity': quantity,
      'unit': unit,
      'expirationDate': expirationDate != null ? Timestamp.fromDate(expirationDate) : null,
      'category': category,
    });
  }

  // Tarifteki malzemeleri kilerden düşme fonksiyonu
  Future<void> consumeIngredients(List<String> ingredientNames) async {
    // 1. Kilerdeki tüm ürünleri getir
    final pantrySnapshot = await pantryRef.get();
    final pantryItems = pantrySnapshot.docs.map((doc) => doc.data()).toList();

    // 2. Her bir tarif malzemesi için kileri kontrol et
    for (String ingredientName in ingredientNames) {
      try {
        final itemToUpdate = pantryItems.firstWhere(
          (item) => item.ingredientName.trim().toLowerCase() == ingredientName.trim().toLowerCase()
        );
        
        // 3. Miktarı Düşür
        if (itemToUpdate.quantity > 1) {
          // 1'den fazlaysa, 1 azalt
          await updatePantryItemQuantity(itemToUpdate.id, itemToUpdate.quantity - 1);
        } else {
          // 1 veya daha azsa, ürünü tamamen sil
          await deletePantryItem(itemToUpdate.id);
        }
      } catch (e) {
        // Kilerde bu malzeme yoksa pas geç
        continue;
      }
    }
  }
}