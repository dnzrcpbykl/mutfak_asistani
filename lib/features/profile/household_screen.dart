// lib/features/profile/household_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Panoya kopyalamak için
import 'package:cloud_firestore/cloud_firestore.dart';
import 'household_service.dart';
import 'dart:convert';
// En üste ekleyin

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  final HouseholdService _householdService = HouseholdService();
  bool _isLoading = false;

  // --- AİLE OLUŞTURMA DİYALOGU ---
  void _showCreateDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yeni Bir Hane Oluştur 🏠"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: "Örn: Yılmaz Ailesi",
            labelText: "Hane Adı"
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(context);
              
              setState(() => _isLoading = true);
              try {
                await _householdService.createHousehold(nameController.text.trim());
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hane oluşturuldu!")));
                }
              } catch (e) {
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text("Oluştur"),
          )
        ],
      ),
    );
  }

  // --- AİLEYE KATILMA DİYALOGU ---
  void _showJoinDialog() {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Bir Haneye Katıl 🔑"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Aile bireyinden aldığın 6 haneli davet kodunu gir."),
            const SizedBox(height: 10),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: "Örn: X9K2P",
                labelText: "Davet Kodu",
                border: OutlineInputBorder()
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) return;
              
              // Önce pencereyi kapat, sonra işleme başla (Context güvenliği için)
              Navigator.pop(context);

              setState(() => _isLoading = true);
              
              try {
                await _householdService.joinHousehold(code);
                
                // İşlem bittiğinde widget hala ekranda mı kontrol et
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Aileye katıldın! 🎉"), backgroundColor: Colors.green)
                  );
                }
              } catch (e) {
                // Hata olduğunda widget hala ekranda mı kontrol et
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Hata: ${e.toString().replaceAll('Exception:', '')}"), backgroundColor: Colors.red)
                  );
                }
              } finally {
                // Yükleniyor durumunu kapatırken de kontrol et
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text("Katıl"),
          )
        ],
      ),
    );
  }

  // --- EVDEN AYRILMA (GÜVENLİ FİX) ---
  void _leaveHousehold() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Haneden Ayrıl?"),
        content: const Text("Ortak kiler ve listeye erişimini kaybedeceksin."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          TextButton(
            onPressed: () async {
              // 1. Messenger'ı işlemden önce yakala (Context kaybolmadan)
              final messenger = ScaffoldMessenger.of(context);
              
              // 2. Diyaloğu kapat
              Navigator.pop(context);
              
              // 3. Yükleniyor...
              setState(() => _isLoading = true);

              try {
                // 4. Servis çağrısı (Burada PERMISSION_DENIED yiyordun)
                await _householdService.leaveHousehold();
                
                // 5. Başarılı mesajı (Artık messenger değişkenini kullanıyoruz)
                messenger.showSnackBar(
                  const SnackBar(content: Text("Haneden başarıyla ayrıldın."), backgroundColor: Colors.green)
                );
                
              } catch (e) {
                // 6. Hata mesajı (Firebase hatası dönerse buraya düşer)
                messenger.showSnackBar(
                  SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red)
                );
              } finally {
                // 7. Yükleniyor'u kapat (Eğer ekran hala açıksa)
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text("Ayrıl", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Ailem & Evim")),
      // Stream tipi artık Nullable (DocumentSnapshot?)
      body: StreamBuilder<DocumentSnapshot?>(
        stream: _householdService.getHouseholdStream(),
        builder: (context, snapshot) {
          
          // 1. Yükleniyor...
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Hata veya Veri Yok (Ev Yok Demektir)
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
            return _buildNoHouseholdView();
          }

          // 3. Veri Geldi (Ev Var Gibi Görünüyor)
          // EKSTRA GÜVENLİK: Gerçekten üye miyim?
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> members = data['members'] ?? [];
          final currentUser = FirebaseAuth.instance.currentUser;

          // Eğer evin üye listesinde benim ID'm yoksa (Atıldıysam), evi gösterme!
          if (!members.contains(currentUser?.uid)) {
             return _buildNoHouseholdView();
          }

          // 4. Her şey yolunda -> Ev Ekranını Göster
          return _buildHouseholdView(snapshot.data!);
        },
      ),
    );
  }

  // --- SENARYO A: EVİ OLMAYAN KULLANICI ---
  Widget _buildNoHouseholdView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.family_restroom, size: 80, color: Theme.of(context).primaryColor.withAlpha((0.5 * 255).round())),
            const SizedBox(height: 24),
            const Text(
              "Henüz bir ailen yok mu?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Mutfak yönetimini eşinle veya ev arkadaşlarınla birleştirmek için bir hane oluştur veya katıl.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            
            // OLUŞTUR BUTONU
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add_home),
                label: const Text("Yeni Hane Oluştur"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // KATIL BUTONU
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _showJoinDialog,
                icon: const Icon(Icons.group_add),
                label: const Text("Davet Kodu ile Katıl"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SENARYO B: EVİ OLAN KULLANICI ---
  Widget _buildHouseholdView(DocumentSnapshot doc) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final data = doc.data() as Map<String, dynamic>;
    
    final String householdId = doc.id;
    final String name = data['name'] ?? 'Evim';
    final String inviteCode = data['inviteCode'] ?? '---';
    final String ownerId = data['ownerId'] ?? '';
    final List<dynamic> members = data['members'] ?? [];

    final bool amIOwner = currentUser?.uid == ownerId;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // KART: Ev Bilgisi
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Icon(Icons.home, size: 50, color: Colors.orange),
                  const SizedBox(height: 10),
                  Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  const Text("DAVET KODU", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
                  const SizedBox(height: 5),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kod kopyalandı!")));
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.withAlpha((0.3 * 255).round()))
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(inviteCode, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2)),
                          const SizedBox(width: 10),
                          const Icon(Icons.copy, size: 20, color: Colors.grey)
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text("Bu kodu ailenle paylaşarak aynı kileri yönetebilirsiniz.", style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          
          // LİSTE: Üyeler
          Align(
            alignment: Alignment.centerLeft,
            child: Text("Hane Üyeleri (${members.length})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
          ),
          const SizedBox(height: 10),
          
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final memberId = members[index];
              
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(memberId).get(),
                builder: (context, snapshot) {
                  String memberName = "Yükleniyor...";
                  ImageProvider? profileImage; // Resim Değişkeni

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final userData = snapshot.data!.data() as Map<String, dynamic>;
                    memberName = "${userData['name']} ${userData['surname'] ?? ''}";
                    
                    // Base64 Resim Çözme
                    if (userData['profileImage'] != null && userData['profileImage'].toString().isNotEmpty) {
                      try {
                        profileImage = MemoryImage(base64Decode(userData['profileImage']));
                      } catch (e) {
                        debugPrint("Resim hatası: $e");
                      }
                    }
                  }
                  
                  final bool isOwner = memberId == ownerId;
                  final bool isMe = memberId == currentUser?.uid;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      // --- PROFİL FOTOĞRAFI ---
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor.withAlpha((0.2 * 255).round()),
                        backgroundImage: profileImage, // Varsa resmi göster
                        child: profileImage == null 
                            ? Text(memberName.isNotEmpty ? memberName[0].toUpperCase() : "?") // Yoksa baş harf
                            : null,
                      ),
                      title: Text(memberName, style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text(isOwner ? "Yönetici 👑" : "Üye"),
                      trailing: (amIOwner && !isMe) 
                          ? const Icon(Icons.more_vert) // Yönetici başkasına bakıyorsa menü ikonu
                          : null,
                      
                      // --- YÖNETİCİ MENÜSÜ ---
                      onTap: (amIOwner && !isMe) ? () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.star, color: Colors.orange),
                                title: const Text("Yöneticiliği Devret"),
                                subtitle: const Text("Tüm yetkileri bu kişiye verirsin."),
                                onTap: () async {
                                  Navigator.pop(context);
                                  await _householdService.transferOwnership(householdId, memberId);
                                  if (mounted) {
                                    // ignore: use_build_context_synchronously
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yöneticilik devredildi.")));
                                  }
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.person_remove, color: Colors.red),
                                title: const Text("Haneden Çıkar"),
                                subtitle: const Text("Bu kişinin erişimi kesilir."),
                                onTap: () async {
                                  Navigator.pop(context);
                                  await _householdService.removeMember(householdId, memberId);
                                  if (mounted) {
                                    // ignore: use_build_context_synchronously
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Üye çıkarıldı."), backgroundColor: Colors.red));
                                  }
                                },
                              ),
                              const SizedBox(height: 20),
                            ],
                          )
                        );
                      } : null,
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 30),
          
          // EVDEN AYRIL BUTONU
          TextButton.icon(
            onPressed: _leaveHousehold,
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text("Bu Haneden Ayrıl", style: TextStyle(color: Colors.red)),
          ),
          SizedBox(height: 20 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

//4T0R7L