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

      // Geçmişe log at (Tüketim)
      if (diff > 0) {
        await historyRef.add({
          'name': oldItem.ingredientName,
          'category': oldItem.category,
          'quantity': diff,
          'unit': oldItem.unit,
          'price': (oldItem.price ?? 0) * (diff / (oldItem.quantity == 0 ? 1 : oldItem.quantity)), // Sıfıra bölünme hatasını önle
          'consumedAt': FieldValue.serverTimestamp(),
          'type': 'consumed'
        });
      }
      
      // --- DÜZELTME BURADA: Eğer miktar 0 veya altına düştüyse SİL ---
      if (newQuantity <= 0.001) {
        await ref.doc(itemId).delete();
      } else {
        final Map<String, dynamic> data = {'quantity': newQuantity};
        if (newPieceCount != null) {
          data['pieceCount'] = newPieceCount;
        }
        await ref.doc(itemId).update(data);
      }
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

  // --- GÜNCELLENEN AKILLI STOK DÜŞME (Optimizasyonlu) ---
  Future<List<String>> consumeIngredientsSmart(List<String> recipeIngredients) async {
    final ref = await getPantryCollection();
    final pantrySnapshot = await ref.get();
    final pantryItems = pantrySnapshot.docs.map((doc) => doc.data()).toList();
    
    List<String> logs = [];

    // Eş anlamlılar sözlüğü
    final Map<String, List<String>> synonyms = {
      'sıvı yağ': ['ayçiçek', 'mısır özü', 'kanola', 'kızartma yağı', 'zeytinyağı'],
      'ayçiçek yağı': ['sıvı yağ', 'yudum', 'biryağ', 'orkide'],
      'zeytinyağı': ['sıvı yağ', 'sızma', 'riviera'],
      'yoğurt': ['süzme', 'tava', 'kaymaklı'],
      'kıyma': ['dana', 'kuzu', 'köftelik', 'dana döş'],
      'süt': ['yarım yağlı', 'tam yağlı', 'laktozsuz', 'pastörize'],
      'un': ['buğday', 'beyaz', 'tambuğday', 'baklavalık'],
      'şeker': ['toz', 'küp', 'esmer', 'beyaz'],
      'domates salçası': ['salça', 'biber salçası'],
      'biber': ['kapya', 'sivri', 'dolmalık', 'çarliston'],
      'soğan': ['kuru', 'beyaz', 'mor', 'arpacık'],
    };

    for (String recipeLine in recipeIngredients) {
      final parsedRecipe = UnitUtils.parseAmount(recipeLine);
      double neededQty = parsedRecipe['amount'];
      String neededUnit = parsedRecipe['unit'];
      
      // Temizleme ve Tokenize işlemi
      String cleanRecipeName = recipeLine.toLowerCase()
          .replaceAll(RegExp(r'\d+'), '')
          .replaceAll(RegExp(r'(gr|gram|kg|kilogram|lt|litre|ml|mililitre|adet|tane|kaşık|bardak|paket|yemek|çay|tatlı|su)'), '')
          .replaceAll(RegExp(r'[^\w\sğüşıöçĞÜŞİÖÇ]'), '')
          .trim();

      List<String> recipeTokens = cleanRecipeName.split(' ').where((s) => s.length > 2).toList(); 

      bool found = false;
      PantryItem? bestMatchItem;
      int bestScore = 0;

      // Kilerde en iyi eşleşmeyi bul
      for (var item in pantryItems) {
         String pantryName = item.ingredientName.toLowerCase();
         int score = 0;

         for (var token in recipeTokens) {
           if (pantryName.contains(token)) score += 2;
         }

         if (synonyms.containsKey(cleanRecipeName)) {
           for (var synonym in synonyms[cleanRecipeName]!) {
             if (pantryName.contains(synonym)) score += 1;
           }
         }

         if (score > bestScore) {
           bestScore = score;
           bestMatchItem = item;
         }
      }

      if (bestMatchItem != null && bestScore > 0) {
          found = true;
          var itemToUpdate = bestMatchItem;

            // DEDEKTİF MODU (Gizli Miktar Tespiti - Örn: "1 paket makarna" denmiş ama kilerde "500 gr" var)
            if ((['adet', 'paket', 'kutu', 'kavanoz', 'şişe'].contains(itemToUpdate.unit)) && 
                (['lt', 'l', 'ml', 'kg', 'gr', 'g', 'kaşık', 'bardak'].contains(neededUnit))) {
                
                final hiddenQtyMatch = RegExp(r'(\d+[.,]?\d*)\s*(lt|l|kg|gr|g|ml)').firstMatch(itemToUpdate.ingredientName.toLowerCase());
                
                if (hiddenQtyMatch != null) {
                  double hiddenAmount = double.parse(hiddenQtyMatch.group(1)!.replaceAll(',', '.'));
                  String hiddenUnit = hiddenQtyMatch.group(2)!;
                  if (hiddenUnit == 'l') hiddenUnit = 'lt';
                  if (hiddenUnit == 'g') hiddenUnit = 'gr';

                  double totalRealAmount = UnitUtils.convertToBaseUnit(itemToUpdate.quantity * hiddenAmount, hiddenUnit);
                  double neededRealAmount = UnitUtils.convertToBaseUnit(neededQty, neededUnit); 
                  
                  double remainingBase = totalRealAmount - neededRealAmount;

                  if (remainingBase > 0) {
                    double onePackBase = UnitUtils.convertToBaseUnit(hiddenAmount, hiddenUnit);
                    double newAdet = remainingBase / onePackBase;
                    
                    // Burada paket sayısı zaten quantity olduğu için doğrudan güncelliyoruz
                    await updatePantryItemQuantity(itemToUpdate.id, newAdet, newPieceCount: newAdet.ceil());
                    logs.add("📉 ${itemToUpdate.ingredientName}: ${newAdet.toStringAsFixed(2)} adet kaldı.");
                    continue;
                  } else {
                     await deletePantryItem(itemToUpdate.id);
                     logs.add("✅ ${itemToUpdate.ingredientName}: Tükendi.");
                     continue;
                  }
                }
            }
            
            // NORMAL HESAPLAMA VE OPTİMİZASYON
            double? newQuantity = UnitUtils.tryDeduct(
              itemToUpdate.quantity, 
              itemToUpdate.unit, 
              neededQty, 
              neededUnit
            );

            if (newQuantity != null) {
              if (newQuantity <= 0.01) {
                await deletePantryItem(itemToUpdate.id);
                logs.add("✅ ${itemToUpdate.ingredientName}: Tükendi.");
              } else {
                // --- OPTİMİZASYON BAŞLANGICI ---
                // Miktar düştükçe paket sayısını da orantılı düşür (Yukarı yuvarla)
                int newPieceCount = itemToUpdate.pieceCount;
                
                if (itemToUpdate.pieceCount > 1 && itemToUpdate.quantity > 0) {
                  // Oran: Yeni Miktar / Eski Miktar
                  double ratio = newQuantity / itemToUpdate.quantity;
                  // Yeni Paket Sayısı = Eski Paket * Oran (Yukarı yuvarla, çünkü yarım paket de olsa 1 pakettir)
                  newPieceCount = (itemToUpdate.pieceCount * ratio).ceil();
                  
                  // Ürün bitmediyse en az 1 paket kalsın
                  if (newPieceCount < 1) newPieceCount = 1;
                }
                // --- OPTİMİZASYON SONU ---

                await updatePantryItemQuantity(itemToUpdate.id, newQuantity, newPieceCount: newPieceCount);
                logs.add("📉 ${itemToUpdate.ingredientName}: ${newQuantity.toStringAsFixed(2)} ${itemToUpdate.unit} kaldı.");
              }
            } else {
               // Birim dönüştürülemediyse (örn: Adet vs Kg), basitçe 1 adet düş
               if(itemToUpdate.quantity >= 1) {
                  int newPiece = itemToUpdate.pieceCount > 1 ? itemToUpdate.pieceCount - 1 : 1;
                  await updatePantryItemQuantity(itemToUpdate.id, itemToUpdate.quantity - 1, newPieceCount: newPiece);
                  logs.add("⚠️ ${itemToUpdate.ingredientName}: Birim farklı, 1 adet düşüldü.");
               } else {
                  logs.add("❌ ${itemToUpdate.ingredientName}: Stok yetersiz veya birim hatası (${itemToUpdate.unit} vs $neededUnit).");
               }
            }
      }
      
      if (!found) {
         logs.add("❌ '$cleanRecipeName' kilerde bulunamadı.");
      }
    }
    
    if (logs.isEmpty) {
      logs.add("İşlem tamamlandı ancak rapor oluşturulacak detay bulunamadı.");
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