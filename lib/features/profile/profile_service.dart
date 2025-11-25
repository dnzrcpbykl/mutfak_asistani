// lib/features/profile/profile_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Resim yükleme işlemi için (Firebase Storage kullanmıyorsak yerel tutamayız,
// o yüzden şimdilik sadece base64 string veya URL mantığı düşünebiliriz. 
// Ancak Storage kurulumu uzun süreceği için şimdilik sadece Ad/Soyad/Email odaklı gidelim
// Veya Firestore'a base64 string olarak kaydedebiliriz - küçük resimler için uygundur).

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

  // Profil Bilgilerini Güncelle (Ad, Soyad)
  Future<void> updateProfileInfo(String name, String surname) async {
    if (currentUser == null) return;
    await _firestore.collection('users').doc(currentUser!.uid).update({
      'name': name,
      'surname': surname,
    });
  }

  // E-posta Güncelle
  Future<void> updateEmail(String newEmail, String password) async {
    if (currentUser == null) return;
    
    // Hassas işlem olduğu için önce şifre ile doğrulama şart
    AuthCredential credential = EmailAuthProvider.credential(
      email: currentUser!.email!, 
      password: password
    );

    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.updateEmail(newEmail);
    // Firestore'daki email bilgisini de güncelleyelim
    await _firestore.collection('users').doc(currentUser!.uid).update({'email': newEmail});
  }

  // Şifre Güncelle
  Future<void> updatePassword(String currentPassword, String newPassword) async {
    if (currentUser == null) return;

    // Önce eski şifreyle doğrulama
    AuthCredential credential = EmailAuthProvider.credential(
      email: currentUser!.email!, 
      password: currentPassword
    );

    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.updatePassword(newPassword);
  }
}