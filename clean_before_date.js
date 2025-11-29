const admin = require("firebase-admin");
// Firebase Konsolundan indirdiğin anahtar dosyasının yolu
var serviceAccount = require("./serviceAccountKey.json"); 

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function deleteRecordsBeforeDate() {
  // Hedef Tarih: 28 Kasım 2025, 19:23:41 (UTC+3)
  // JavaScript Date objesi UTC+3'ü otomatik algılamaz, o yüzden ISO formatında yazıyoruz.
  // 19:23:41 (UTC+3) -> 16:23:41 (UTC) demektir.
  const targetDateStr = "2025-11-28T16:23:41Z"; 
  const cutoffDate = new Date(targetDateStr);

  console.log(`🎯 Hedef Tarih (UTC): ${cutoffDate.toISOString()}`);
  console.log("🔍 Bu tarihten eski kayıtlar aranıyor...");

  // Sorgu: updatedAt <= cutoffDate
  const snapshot = await db.collection('market_prices')
      .where('updatedAt', '<=', cutoffDate)
      .get();

  if (snapshot.empty) {
    console.log("✅ Belirtilen tarihten önceye ait silinecek kayıt bulunamadı.");
    return;
  }

  console.log(`⚠️ Toplam ${snapshot.size} adet kayıt bulundu. Silme işlemi başlıyor...`);

  const batch = db.batch();
  let count = 0;
  let batchCount = 0;

  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    count++;
    batchCount++;

    // Firestore batch limiti 500'dür. Dolunca gönderip sıfırlıyoruz.
    if (batchCount >= 400) {
      await batch.commit();
      console.log(`🧹 ${count} kayıt silindi, devam ediliyor...`);
      batchCount = 0;
    }
  }

  // Kalanları sil
  if (batchCount > 0) {
    await batch.commit();
  }

  console.log(`🏁 İŞLEM TAMAMLANDI! Toplam ${count} adet eski kayıt başarıyla silindi.`);
}

deleteRecordsBeforeDate();