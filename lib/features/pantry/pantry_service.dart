import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/models/ingredient.dart';
import '../../core/models/pantry_item.dart';
import '../../core/utils/unit_utils.dart';

class PantryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Malzemeler genel bir havuzdur, değişmez.
  CollectionReference<Ingredient> get ingredientsRef => 
      _firestore.collection('ingredients').withConverter<Ingredient>(
        fromFirestore: (snapshot, _) => Ingredient.fromFirestore(snapshot),
        toFirestore: (ingredient, _) => ingredient.toFirestore(),
      );

  // --- DİNAMİK REFERANS BULUCU (KALP) ---
  // Kullanıcı bir haneye üyeyse Hanenin koleksiyonunu, değilse Kendi koleksiyonunu döndürür.
  Future<CollectionReference<PantryItem>> getPantryCollection() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Kullanıcı girişi yapılmamış.");

    // 1. Kullanıcının profilini kontrol et: Bir haneye üye mi?
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    
    String collectionPath;
    if (userDoc.exists && userDoc.data()!.containsKey('currentHouseholdId')) {
      // EVET: Hanenin kilerine bağlan
      String householdId = userDoc.data()!['currentHouseholdId'];
      collectionPath = 'households/$householdId/pantry';
    } else {
      // HAYIR: Bireysel kilere bağlan (Eski yöntem)
      collectionPath = 'users/${user.uid}/pantry';
    }

    return _firestore.collection(collectionPath).withConverter<PantryItem>(
      fromFirestore: (snapshot, _) => PantryItem.fromFirestore(snapshot),
      toFirestore: (item, _) => item.toFirestore(),
    );
  }

  // Tüketim Geçmişi (Şimdilik bireysel kalabilir veya haneye taşınabilir, bireysel daha mantıklı)
  CollectionReference get historyRef {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception("Kullanıcı girişi yapılmamış.");
    return _firestore.collection('users').doc(userId).collection('consumption_history');
  }

  // --- CRUD İŞLEMLERİ (Artık Dinamik) ---

  Future<void> addIngredientToSystem(Ingredient ingredient) async {
    await ingredientsRef.add(ingredient);
  }

  Future<void> addPantryItem(PantryItem item) async {
    try {
      final ref = await getPantryCollection(); // Nereye ekleyeceğini sor
      await ref.add(item);
    } on FirebaseException catch (e) {
      // EĞER İZİN HATASI ALIRSAK (Evden atılmışız demektir)
      if (e.code == 'permission-denied') {
        debugPrint("🚨 Erişim reddedildi! Haneden atılmış olabilirim. Bireysele dönülüyor...");
        
        final user = _auth.currentUser;
        if (user != null) {
          // Kendi profilimdeki 'currentHouseholdId' alanını siliyorum
          await _firestore.collection('users').doc(user.uid).update({
            'currentHouseholdId': FieldValue.delete(),
          });
          
          // İşlemi tekrar dene (Artık bireysele ekleyecek)
          // Bu sefer bireysel koleksiyonu alıp oraya ekliyoruz
          final personalRef = _firestore.collection('users/${user.uid}/pantry').withConverter<PantryItem>(
            fromFirestore: (s, _) => PantryItem.fromFirestore(s),
            toFirestore: (i, _) => i.toFirestore()
          );
          await personalRef.add(item);
        }
      } else {
        rethrow; // Başka bir hataysa (internet vs.) fırlat
      }
    }
  }

  // Dinamik Stream (Kullanıcı profili değişirse algılaması için StreamSwitch kullanılabilir ama MVP için bu yeterli)
  // Dinamik Stream (GÜNCELLENDİ: Hata Yönetimi ve Broadcast Eklendi)
  Stream<List<PantryItem>> getPantryItems() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore.collection('users').doc(user.uid).snapshots().asyncMap((userDoc) async {
      String path;
      // Kullanıcının evi var mı kontrol et
      if (userDoc.exists && userDoc.data()!.containsKey('currentHouseholdId')) {
        path = 'households/${userDoc.data()!['currentHouseholdId']}/pantry';
      } else {
        // Yoksa bireysel yol
        path = 'users/${user.uid}/pantry';
      }
      
      // HATA YÖNETİMİ: Eğer erişim reddedilirse (Permission Denied) boş liste dön
      // Bu sayede kırmızı ekran yerine boş ekran görünür.
      try {
        return _firestore.collection(path)
            .withConverter<PantryItem>(
              fromFirestore: (s, _) => PantryItem.fromFirestore(s),
              toFirestore: (i, _) => i.toFirestore())
            .snapshots()
            .map((snap) => snap.docs.map((d) => d.data()).toList())
            // Hata yakalama (Permission Denied burada yakalanır)
            .handleError((e) {
              debugPrint("Pantry Stream Hatası (Normal olabilir): $e");
              return <PantryItem>[]; 
            });
      } catch (e) {
        return const Stream<List<PantryItem>>.empty();
      }
    }).asyncExpand((stream) => stream).asBroadcastStream(); // <-- ÖNEMLİ: Broadcast eklendi
  }

  Future<List<Ingredient>> searchIngredients(String query) async {
    final snapshot = await ingredientsRef
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> deletePantryItem(String itemId) async {
    final ref = await getPantryCollection();
    final doc = await ref.doc(itemId).get();
    
    if (doc.exists) {
      final item = doc.data()!;
      await historyRef.add({
        'name': item.ingredientName,
        'category': item.category,
        'quantity': item.quantity,
        'unit': item.unit,
        'price': item.price,
        'consumedAt': FieldValue.serverTimestamp(),
        'type': 'deleted'
      });
      await ref.doc(itemId).delete();
    }
  }
  
  Future<void> updatePantryItemQuantity(String itemId, double newQuantity, {int? newPieceCount}) async {
    final ref = await getPantryCollection();
    final doc = await ref.doc(itemId).get();

    if (doc.exists) {
      final oldItem = doc.data()!;
      double diff = oldItem.quantity - newQuantity;

      if (diff > 0) {
        await historyRef.add({
          'name': oldItem.ingredientName,
          'category': oldItem.category,
          'quantity': diff,
          'unit': oldItem.unit,
          'price': (oldItem.price ?? 0) * (diff / oldItem.quantity),
          'consumedAt': FieldValue.serverTimestamp(),
          'type': 'consumed'
        });
      }
      
      final Map<String, dynamic> data = {'quantity': newQuantity};
      if (newPieceCount != null) {
        data['pieceCount'] = newPieceCount;
      }
      await ref.doc(itemId).update(data);
    }
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
    final ref = await getPantryCollection();
    await ref.doc(itemId).update({
      'ingredientName': name,
      'quantity': quantity,
      'unit': unit,
      'expirationDate': expirationDate != null ? Timestamp.fromDate(expirationDate) : null,
      'category': category,
      'pieceCount': pieceCount,
    });
  }

  // --- GÜNCELLENEN STOK DÜŞME MANTIĞI ---
  Future<List<String>> consumeIngredientsSmart(List<String> recipeIngredients) async {
    final ref = await getPantryCollection();
    final pantrySnapshot = await ref.get();
    final pantryItems = pantrySnapshot.docs.map((doc) => doc.data()).toList();
    
    List<String> logs = []; // Kullanıcıya ne yaptığımızı raporlamak için

    for (String recipeLine in recipeIngredients) {
      // 1. Tarif satırını analiz et (Örn: "500 gr Kıyma")
      final parsedRecipe = UnitUtils.parseAmount(recipeLine);
      double neededQty = parsedRecipe['amount'];
      String neededUnit = parsedRecipe['unit'];
      
      // Temizlenmiş isim (RecipeService'deki temizleyiciye benzer basit bir temizlik)
      // Detaylı eşleşme için RecipeService'in _cleanName mantığı burada da kullanılabilir
      // Şimdilik basit tutalım:
      String cleanName = recipeLine.toLowerCase()
          .replaceAll(RegExp(r'\d+'), '') // Sayıları sil
          .replaceAll('gr', '').replaceAll('kg', '').replaceAll('lt', '').replaceAll('ml', '')
          .replaceAll('adet', '').replaceAll('tane', '')
          .trim();

      try {
        // 2. Kilerde bu ürünü bul
        final itemToUpdate = pantryItems.firstWhere(
          (item) => item.ingredientName.toLowerCase().contains(cleanName) || 
                    cleanName.contains(item.ingredientName.toLowerCase())
        );

        // 3. Hesaplama Yap
        double? newQuantity = UnitUtils.tryDeduct(
          itemToUpdate.quantity, 
          itemToUpdate.unit, 
          neededQty, 
          neededUnit
        );

        if (newQuantity != null) {
          // Mantıklı bir sonuç çıktıysa güncelle
          if (newQuantity <= 0) {
            await deletePantryItem(itemToUpdate.id);
            logs.add("✅ ${itemToUpdate.ingredientName}: Tükendi ve silindi.");
          } else {
            await updatePantryItemQuantity(itemToUpdate.id, newQuantity);
            logs.add("📉 ${itemToUpdate.ingredientName}: ${itemToUpdate.quantity} -> ${newQuantity.toStringAsFixed(2)} ${itemToUpdate.unit} güncellendi.");
          }
        } else {
          // Birim uyuşmazlığı varsa (Örn: Kilerde "Adet", Tarifte "Bardak")
          // Varsayılan olarak 1 birim düşelim ama loglayalım
          if (itemToUpdate.quantity > 1) {
             await updatePantryItemQuantity(itemToUpdate.id, itemToUpdate.quantity - 1);
             logs.add("⚠️ ${itemToUpdate.ingredientName}: Birim uyuşmazlığı. 1 adet düşüldü.");
          } else {
             await deletePantryItem(itemToUpdate.id);
             logs.add("⚠️ ${itemToUpdate.ingredientName}: Tükendi.");
          }
        }

      } catch (e) {
        // Kilerde bulunamadıysa pas geç
        continue;
      }
    }
    return logs;
  }
  
  // Eski kodlarınızın kırılmaması için (Legacy Getter) - Ama içi boşaltıldı
  // Dikkat: Bunu kullanan yerleri (StatisticsScreen ve RecipeProvider) düzeltmemiz gerekecek.
  // Şimdilik hata vermemesi için "throw" yerine kullanıcı kilerini döndürüyoruz ama 
  // DOĞRU OLAN: getPantryCollection() metodunu kullanmaktır.
  CollectionReference<PantryItem> get pantryRef {
     final user = _auth.currentUser;
     if (user == null) throw Exception("User null");
     return _firestore.collection('users').doc(user.uid).collection('pantry').withConverter<PantryItem>(
        fromFirestore: (s, _) => PantryItem.fromFirestore(s),
        toFirestore: (i, _) => i.toFirestore(),
     );
  }

  Future<void> consumeIngredients(List<String> ingredients) async {}
}