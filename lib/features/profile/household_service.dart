// lib/features/profile/household_service.dart

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HouseholdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Rastgele Davet Kodu Üretici (Örn: X9K2P)
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
      6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  // Kullanıcının şu anki Hane ID'sini getir
  Future<String?> getCurrentHouseholdId() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists && doc.data()!.containsKey('currentHouseholdId')) {
      return doc.data()!['currentHouseholdId'];
    }
    return null;
  }

  // --- 1. AİLE OLUŞTUR (Kurucu) ---
  Future<String> createHousehold(String householdName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Kullanıcı oturumu kapalı.");

    // 1. Yeni bir Hane dokümanı hazırla
    final householdRef = _firestore.collection('households').doc();
    final String inviteCode = _generateInviteCode();

    // 2. Haneyi oluştur
    await householdRef.set({
      'name': householdName,
      'ownerId': user.uid,
      'inviteCode': inviteCode,
      'members': [user.uid], // İlk üye kurucudur
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3. Kullanıcının mevcut verilerini bu yeni eve taşı
    await _migrateUserDataToHousehold(user.uid, householdRef.id);

    // 4. Kullanıcı profilini güncelle (Artık bu eve ait)
    await _firestore.collection('users').doc(user.uid).update({
      'currentHouseholdId': householdRef.id,
    });

    return inviteCode;
  }

  // --- 2. AİLEYE KATIL (Üye) ---
  Future<void> joinHousehold(String inviteCode) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Kullanıcı oturumu kapalı.");

    // 1. Kodu arat
    final query = await _firestore
        .collection('households')
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase().trim())
        .get();

    if (query.docs.isEmpty) {
      throw Exception("Geçersiz davet kodu.");
    }

    final householdDoc = query.docs.first;
    final String householdId = householdDoc.id;

    // Zaten üye mi?
    List<dynamic> members = householdDoc.data()['members'] ?? [];
    if (members.contains(user.uid)) {
      throw Exception("Zaten bu ailenin üyesisiniz.");
    }

    // --- KRİTİK DEĞİŞİKLİK BURADA ---
    // ÖNCE ÜYE YAP (Kapıdan içeri girsin)
    await _firestore.collection('households').doc(householdId).update({
      'members': FieldValue.arrayUnion([user.uid])
    });

    // SONRA VERİLERİ TAŞI (Artık içeride olduğu için izin verilecek)
    await _migrateUserDataToHousehold(user.uid, householdId);

    // EN SON PROFİLİ GÜNCELLE
    await _firestore.collection('users').doc(user.uid).update({
      'currentHouseholdId': householdId,
    });
  }

  // --- 3. EVDEN AYRIL (GÜNCELLENDİ: ZOMBIE DATA TEMİZLİĞİ) ---
  Future<void> leaveHousehold() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final String? householdId = await getCurrentHouseholdId();
    if (householdId == null) return;

    final householdRef = _firestore.collection('households').doc(householdId);
    final householdDoc = await householdRef.get();

    if (!householdDoc.exists) return;

    final List<dynamic> members = householdDoc.data()?['members'] ?? [];

    // SENARYO A: Evde kalan son kişi benim -> Evi tamamen sil
    if (members.length <= 1) {
      // 1. Alt koleksiyonları temizle (Pantry, Shopping List)
      // Not: Firestore'da ana dokümanı silmek, alt koleksiyonları otomatik silmez.
      final subCollections = ['pantry', 'shopping_list'];
      for (var sub in subCollections) {
        final subSnap = await householdRef.collection(sub).get();
        for (var doc in subSnap.docs) {
          await doc.reference.delete();
        }
      }
      // 2. Evi sil
      await householdRef.delete();
      debugPrint("🧹 Son üye ayrıldı, hane ($householdId) ve alt verileri silindi.");
    }
    // SENARYO B: Evde başkaları var -> Sadece beni çıkar
    else {
      // Eğer ben yöneticiysem (owner), çıkmadan önce yetkiyi başkasına devretmeliyim.
      // Basit çözüm: Listede benden sonraki ilk kişiyi (veya 0. indexi) yeni yönetici yap.
      if (householdDoc.data()?['ownerId'] == user.uid) {
        final newOwner = members.firstWhere((id) => id != user.uid, orElse: () => null);
        if (newOwner != null) {
           await householdRef.update({'ownerId': newOwner});
           debugPrint("👑 Yönetici ayrıldı, yeni yönetici atandı: $newOwner");
        }
      }

      await householdRef.update({
        'members': FieldValue.arrayRemove([user.uid])
      });
    }

    // 3. Kendi profilimi güncelle (Bireysele dön)
    // 'currentHouseholdId' alanını siliyoruz.
    await _firestore.collection('users').doc(user.uid).update({
      'currentHouseholdId': FieldValue.delete(),
    });
  }

  // --- 4. ÜYE ÇIKAR (GÜNCELLENDİ: Veri Temizleme Eklendi) ---
  Future<void> removeMember(String householdId, String memberId) async {
    // 1. Hanenin üye listesinden çıkar
    await _firestore.collection('households').doc(householdId).update({
      'members': FieldValue.arrayRemove([memberId])
    });

    // 2. Çıkarılan kullanıcının profilindeki hane bilgisini sil (Bireysele döner)
    await _firestore.collection('users').doc(memberId).update({
      'currentHouseholdId': FieldValue.delete(),
    });

    // 3. Kullanıcının eski "bireysel" verileri duruyorsa temizle (Opsiyonel ama temizlik için iyi)
    await _clearUserPersonalData(memberId);
  }

  // --- YARDIMCI: Kullanıcının Bireysel Verilerini Silme ---
  Future<void> _clearUserPersonalData(String userId) async {
    // A) Bireysel Kileri Sil
    final pantryRef = _firestore.collection('users').doc(userId).collection('pantry');
    final pantrySnap = await pantryRef.get();
    for (var doc in pantrySnap.docs) {
      await doc.reference.delete();
    }

    // B) Bireysel Alışveriş Listesini Sil
    final shoppingRef = _firestore.collection('users').doc(userId).collection('shopping_list');
    final shoppingSnap = await shoppingRef.get();
    for (var doc in shoppingSnap.docs) {
      await doc.reference.delete();
    }
    
    debugPrint("🧹 Kullanıcının ($userId) bireysel verileri temizlendi.");
  }

  // --- 5. YÖNETİCİLİĞİ DEVRET ---
  Future<void> transferOwnership(String householdId, String newOwnerId) async {
    await _firestore.collection('households').doc(householdId).update({
      'ownerId': newOwnerId
    });
  }

  // --- YARDIMCI: VERİ MİGRASYONU (TAŞIMA/BİRLEŞTİRME) ---
  Future<void> _migrateUserDataToHousehold(String userId, String householdId) async {
    // A) KİLERİ TAŞI
    final userPantryRef = _firestore.collection('users').doc(userId).collection('pantry');
    final householdPantryRef = _firestore.collection('households').doc(householdId).collection('pantry');

    final pantrySnapshot = await userPantryRef.get();
    for (var doc in pantrySnapshot.docs) {
      // Yeni eve ekle
      await householdPantryRef.add(doc.data());
      // Eskiyi sil (Taşıma işlemi)
      await doc.reference.delete();
    }

    // B) ALIŞVERİŞ LİSTESİNİ TAŞI
    final userShopRef = _firestore.collection('users').doc(userId).collection('shopping_list');
    final householdShopRef = _firestore.collection('households').doc(householdId).collection('shopping_list');

    final shopSnapshot = await userShopRef.get();
    for (var doc in shopSnapshot.docs) {
      var data = doc.data();
      // Kimin eklediğini belli etmek için ek alanlar (isteğe bağlı)
      // data['addedBy'] = userId;
      await householdShopRef.add(data);
      await doc.reference.delete();
    }
    
    debugPrint("✅ Kullanıcı ($userId) verileri Hane ($householdId) havuzuna taşındı.");
  }
  
  // --- Hane Bilgisini Getir (GÜNCELLENDİ: Daha Akıllı Stream) ---
  Stream<DocumentSnapshot?> getHouseholdStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    // Kullanıcı profilini dinliyoruz...
    return _firestore.collection('users').doc(user.uid).snapshots().asyncExpand((userDoc) {
      // 1. Kullanıcının profilinde hane ID'si var mı?
      if (userDoc.exists && userDoc.data() != null && userDoc.data()!.containsKey('currentHouseholdId')) {
        String householdId = userDoc.data()!['currentHouseholdId'];
        // 2. Varsa o Hane'nin verisini dinlemeye başla
        return _firestore.collection('households').doc(householdId).snapshots();
      } else {
        // 3. Yoksa (veya silindiyse) "null" döndür (Yani: Ev Yok)
        return Stream.value(null);
      }
    });
  }
}