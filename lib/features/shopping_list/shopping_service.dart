import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/shopping_item.dart';

class ShoppingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- TÜRKÇE KARAKTER DÜZELTME YARDIMCISI ---
  String _normalize(String text) {
    return text
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .replaceAll('Ğ', 'ğ')
        .replaceAll('Ü', 'ü')
        .replaceAll('Ş', 'ş')
        .replaceAll('Ö', 'ö')
        .replaceAll('Ç', 'ç')
        .toLowerCase()
        .trim();
  }

  // --- YARDIMCI: EVDEN ATILMA DURUMUNDA PROFİLİ TEMİZLE ---
  Future<void> _handlePermissionDenied() async {
    final user = _auth.currentUser;
    if (user != null) {
      debugPrint("🚨 Erişim reddedildi! Profili temizliyorum...");
      await _firestore.collection('users').doc(user.uid).update({
        'currentHouseholdId': FieldValue.delete(),
      });
    }
  }

  // --- DİNAMİK REFERANS BULUCU ---
  Future<CollectionReference> _getListRef() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Kullanıcı yok");

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    String collectionPath;

    if (userDoc.exists && userDoc.data()!.containsKey('currentHouseholdId')) {
      String householdId = userDoc.data()!['currentHouseholdId'];
      collectionPath = 'households/$householdId/shopping_list';
    } else {
      collectionPath = 'users/${user.uid}/shopping_list';
    }

    // Model dönüşümü yapmadan direkt CollectionReference döndürüyoruz (Map yapısı için)
    return _firestore.collection(collectionPath);
  }

  // --- CANLI TAKİP (YENİ: ZENGİN VERİ İÇİN MAP DÖNDÜRÜR) ---
  // Model yerine Map döndürüyoruz ki resim ve market listesini UI'da işleyebilelim
  Stream<List<Map<String, dynamic>>> getShoppingListStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore.collection('users').doc(user.uid).snapshots().asyncMap((userDoc) async {
      String path;
      if (userDoc.exists && userDoc.data()!.containsKey('currentHouseholdId')) {
        path = 'households/${userDoc.data()!['currentHouseholdId']}/shopping_list';
      } else {
        path = 'users/${user.uid}/shopping_list';
      }

      try {
        return _firestore.collection(path)
            .orderBy('createdAt', descending: true)
            .snapshots()
            .map((snap) => snap.docs.map((d) {
                  final data = d.data();
                  data['id'] = d.id; // Doküman ID'sini veriye ekle
                  return data;
                }).toList())
            .handleError((e) {
               debugPrint("Shopping Stream Hatası: $e");
               return <Map<String, dynamic>>[];
            });
      } catch (e) {
        return const Stream<List<Map<String, dynamic>>>.empty();
      }
    }).asyncExpand((stream) => stream).asBroadcastStream();
  }

  // --- CRUD İŞLEMLERİ (GÜNCELLENDİ: RESİM VE MARKET DESTEĞİ) ---

  // Artık isim haricinde opsiyonel olarak resim ve market listesi de alıyor
  Future<bool> addItem({
    required String name,
    String? imageUrl,
    List<dynamic>? markets
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return false;

    // Eklenen kelimeyi normalize et (Örn: "SÜT" -> "süt")
    final normalizedInput = _normalize(cleanName);

    try {
      final ref = await _getListRef();
      
      // Mevcutları kontrol et (Aynı isimde ürün var mı?)
      final activeItemsSnapshot = await ref.where('isCompleted', isEqualTo: false).get();
      
      for (var doc in activeItemsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // İsim kontrolü
        if (_normalize(data['name'] ?? '') == normalizedInput) {
          return false; // Zaten var, ekleme yapma
        }
      }

      // Veritabanına ZENGİN İÇERİKLE kaydet
      await ref.add({
        'name': cleanName,
        'isCompleted': false,
        'imageUrl': imageUrl ?? '', // Resim URL'i varsa kaydet
        'markets': markets ?? [],   // Market fiyatları listesi varsa kaydet
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;

    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        await _handlePermissionDenied();
        return await addItem(name: name, imageUrl: imageUrl, markets: markets);
      }
      rethrow;
    }
  }

  Future<void> toggleStatus(String id, bool currentStatus) async {
    try {
      final ref = await _getListRef();
      await ref.doc(id).update({'isCompleted': !currentStatus});
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') await _handlePermissionDenied();
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      final ref = await _getListRef();
      await ref.doc(id).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') await _handlePermissionDenied();
    }
  }

  Future<void> clearCompleted() async {
    try {
      final ref = await _getListRef();
      final snapshot = await ref.where('isCompleted', isEqualTo: true).get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') await _handlePermissionDenied();
    }
  }
}