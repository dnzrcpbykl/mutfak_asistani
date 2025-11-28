import 'package:flutter/material.dart'; // Debug print için
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/shopping_item.dart';

class ShoppingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
  Future<CollectionReference<ShoppingItem>> _getListRef() async {
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

    return _firestore.collection(collectionPath).withConverter<ShoppingItem>(
      fromFirestore: (snapshot, _) => ShoppingItem.fromFirestore(snapshot),
      toFirestore: (item, _) => item.toFirestore(),
    );
  }

  // --- CANLI TAKİP ---
  Stream<List<ShoppingItem>> getShoppingList() {
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
            .withConverter<ShoppingItem>(
              fromFirestore: (s, _) => ShoppingItem.fromFirestore(s),
              toFirestore: (i, _) => i.toFirestore())
            .orderBy('createdAt', descending: true)
            .snapshots()
            .map((snap) => snap.docs.map((d) => d.data()).toList())
            .handleError((e) {
               debugPrint("Shopping Stream Hatası: $e");
               return <ShoppingItem>[];
            });
      } catch (e) {
        return const Stream<List<ShoppingItem>>.empty();
      }
    }).asyncExpand((stream) => stream).asBroadcastStream();
  }

  // --- CRUD İŞLEMLERİ (GÜNCELLENDİ: Hata Korumalı) ---

  Future<bool> addItem(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return false;

    try {
      final ref = await _getListRef();
      
      // Mevcutları kontrol et
      final activeItemsSnapshot = await ref.where('isCompleted', isEqualTo: false).get();
      for (var doc in activeItemsSnapshot.docs) {
        if (doc.data().name.toLowerCase() == cleanName.toLowerCase()) {
          return false;
        }
      }

      await ref.add(ShoppingItem(id: '', name: cleanName, isCompleted: false));
      return true;

    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        await _handlePermissionDenied(); // Profili düzelt
        return await addItem(name); // İşlemi tekrar dene (Bireysele ekler)
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