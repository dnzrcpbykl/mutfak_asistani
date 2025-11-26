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
    await currentUser!.updateEmail(newEmail);
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
}