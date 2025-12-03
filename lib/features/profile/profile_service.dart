import 'dart:convert'; // Base64 için gerekli
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  // Kullanıcı Bilgilerini Getir
  Future<Map<String, dynamic>?> getUserData() async {
    if (currentUser == null) return null;
    final doc = await _firestore.collection('users').doc(currentUser!.uid).get();
    return doc.data();
  }

  // GÜNCELLENEN: Profil Bilgilerini ve Fotoğrafı Güncelle
  Future<void> updateProfileInfo({
    required String name, 
    required String surname, 
    File? imageFile
  }) async {
    if (currentUser == null) return;

    Map<String, dynamic> data = {
      'name': name,
      'surname': surname,
    };

    // Eğer yeni bir resim seçildiyse, onu metne çevirip kaydedelim
    if (imageFile != null) {
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      data['profileImage'] = base64Image; // Veritabanına ekle
    }

    await _firestore.collection('users').doc(currentUser!.uid).update(data);
  }

  Future<void> updateEmail(String newEmail, String password) async {
    if (currentUser == null) return;
    AuthCredential credential = EmailAuthProvider.credential(
      email: currentUser!.email!, 
      password: password
    );
    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.verifyBeforeUpdateEmail(newEmail);
    await _firestore.collection('users').doc(currentUser!.uid).update({'email': newEmail});
  }

  Future<void> updatePassword(String currentPassword, String newPassword) async {
    if (currentUser == null) return;
    AuthCredential credential = EmailAuthProvider.credential(
      email: currentUser!.email!, 
      password: currentPassword
    );
    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.updatePassword(newPassword);
  }

  Future<void> deleteAccount(String password) async {
    if (currentUser == null) return;

    try {
      // 1. Güvenlik: İşlem öncesi tekrar şifre iste (Re-authenticate)
      AuthCredential credential = EmailAuthProvider.credential(
        email: currentUser!.email!,
        password: password
      );
      await currentUser!.reauthenticateWithCredential(credential);

      final String uid = currentUser!.uid;

      // 2. Alt Koleksiyonları Temizle (Manuel olarak silinmeli)
      // Firestore'da ana dokümanı silince altındakiler otomatik silinmez, o yüzden tek tek siliyoruz.
      final subCollections = [
        'pantry', 
        'shopping_list', 
        'saved_recipes', 
        'suggestions', 
        'consumption_history'
      ];

      for (var collection in subCollections) {
        final snapshot = await _firestore.collection('users').doc(uid).collection(collection).get();
        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }
      }

      // 3. Kullanıcı Ana Dokümanını Sil
      await _firestore.collection('users').doc(uid).delete();

      // 4. Auth Kaydını Sil (Geri dönüşü yok)
      await currentUser!.delete();

    } catch (e) {
      throw Exception("Hesap silinirken hata: $e");
    }
  }

  // --- KOTA VE PREMİUM YÖNETİMİ ---

  // Kullanıcının Premium olup olmadığını ve bugünkü hakkını kontrol et
  Future<Map<String, dynamic>> checkUsageRights() async {
    if (currentUser == null) return {'canGenerate': false, 'needsAd': false, 'isPremium': false};

    final doc = await _firestore.collection('users').doc(currentUser!.uid).get();
    final data = doc.data() ?? {};

    bool isPremium = data['isPremium'] ?? false;
    
    // Eğer Premium ise sınır yok
    if (isPremium) {
      return {'canGenerate': true, 'needsAd': false, 'isPremium': true};
    }

    // Normal Üyelik Kontrolü
    Timestamp? lastDateTs = data['lastRecipeDate'];
    int dailyCount = data['dailyRecipeCount'] ?? 0;
    
    DateTime now = DateTime.now();
    DateTime lastDate = lastDateTs?.toDate() ?? DateTime(2000);

    // Eğer son istek dünden kalmaysa sayacı sıfırla
    if (lastDate.year != now.year || lastDate.month != now.month || lastDate.day != now.day) {
      dailyCount = 0;
      // Veritabanını da sıfırla (Arka planda)
      _firestore.collection('users').doc(currentUser!.uid).update({'dailyRecipeCount': 0});
    }

    if (dailyCount == 0) {
      // 1. Hak: Ücretsiz
      return {'canGenerate': true, 'needsAd': false, 'isPremium': false};
    } else {
      // 2. ve Sonraki Haklar: Reklam Gerekli
      return {'canGenerate': false, 'needsAd': true, 'isPremium': false};
    }
  }

  // Tarif üretildikten sonra sayacı artır
  Future<void> incrementUsage() async {
    if (currentUser == null) return;
    
    // Sadece Premium DEĞİLSE artır (Premium'a sayaç tutmaya gerek yok)
    final doc = await _firestore.collection('users').doc(currentUser!.uid).get();
    if (doc.data()?['isPremium'] == true) return;

    await _firestore.collection('users').doc(currentUser!.uid).update({
      'dailyRecipeCount': FieldValue.increment(1),
      'lastRecipeDate': FieldValue.serverTimestamp(),
    });
  }

  // Test için kullanıcıyı Premium yapma fonksiyonu (İleride Satın Alma ekranına bağlanacak)
  Future<void> setPremiumStatus(bool status) async {
    if (currentUser == null) return;
    await _firestore.collection('users').doc(currentUser!.uid).update({'isPremium': status});
  }

  // --- ABONELİK YÖNETİMİ ---

  // Premium Satın Al (Simülasyon)
  Future<void> upgradeToPremium(String planType) async {
    if (currentUser == null) return;
    
    // Gerçekte burada Ödeme Servisi devreye girer.
    // Ödeme başarılıysa veritabanı güncellenir.
    
    await _firestore.collection('users').doc(currentUser!.uid).update({
      'isPremium': true,
      'subscriptionType': planType, // 'monthly' veya 'yearly'
      'subscriptionDate': FieldValue.serverTimestamp(),
      'dailyRecipeCount': 0, // Kısıtlamaları kaldır
    });
  }

  // Aboneliği İptal Et
  Future<void> cancelSubscription() async {
    if (currentUser == null) return;

    await _firestore.collection('users').doc(currentUser!.uid).update({
      'isPremium': false,
      'subscriptionType': FieldValue.delete(),
      'subscriptionDate': FieldValue.delete(),
    });
  }
}