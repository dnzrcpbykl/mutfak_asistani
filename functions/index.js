const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

admin.initializeApp();

const BASE_URL = "https://api.marketfiyati.org.tr/api/v2/searchByCategories";

const HEADERS = {
  'accept': 'application/json, text/plain, */*',
  'accept-language': 'tr-TR,tr;q=0.9,en;q=0.8',
  'content-type': 'application/json',
  'origin': 'https://marketfiyati.org.tr',
  'referer': 'https://marketfiyati.org.tr/',
  'sec-ch-ua': '"Google Chrome";v="131", "Chromium";v="131", "Not_A Brand";v="24"',
  'sec-ch-ua-mobile': '?0',
  'sec-ch-ua-platform': '"Windows"',
  'sec-fetch-dest': 'empty',
  'sec-fetch-mode': 'cors',
  'sec-fetch-site': 'same-site',
  'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  'x-requested-with': 'XMLHttpRequest'
};

const CATEGORIES = [
  "Meyve ve Sebze",
  "Et, Tavuk ve Balık",
  "Süt Ürünleri ve Kahvaltılık",
  "Temel Gıda",
  "İçecek",
  "Atıştırmalık ve Tatlı",
  "Temizlik ve Kişisel Bakım Ürünleri"
];

// ==========================================
// 1. FONKSİYON: HAFTALIK GÜNCELLEME ROBOTU
// ==========================================
exports.marketFiyatGuncelleyiciV2 = onSchedule({
  schedule: "0 6 * * 3",
  timeZone: "Europe/Istanbul",
  region: "europe-west1",
  timeoutSeconds: 3600, // 1 Saat
  memory: "2GiB",
  retryCount: 0,
}, async (event) => {
  
  console.log("DETAYLI RAPORLU FİYAT GÜNCELLEME (V2) BAŞLADI:", new Date());

  // ADIM 1: MEVCUT ID'LERİ ÇEK
  const existingProductIds = new Set();
  try {
    const snapshot = await admin.firestore().collection('market_prices').select().get();
    snapshot.forEach(doc => {
      existingProductIds.add(doc.id);
    });
    console.log(`Veritabanında şu an ${existingProductIds.size} adet kayıtlı ürün var.`);
  } catch (error) {
    console.error("Mevcut ID'ler çekilemedi:", error);
  }

  const allProducts = new Map();
  const now = admin.firestore.FieldValue.serverTimestamp();

  // ADIM 2: API TARAMA
  const chunkSize = 3;
  for (let i = 0; i < CATEGORIES.length; i += chunkSize) {
    const chunk = CATEGORIES.slice(i, i + chunkSize);

    await Promise.all(chunk.map(async (category) => {
      console.log(`Kategori taranıyor: ${category}`);
      let page = 0;

      while (true) {
        const payload = {
          menuCategory: true,
          keywords: category,
          pages: page,
          size: 100,
          latitude: 39.9208,
          longitude: 32.8541,
          distance: 2000,
          depots: []
        };

        let data;
        let success = false;

        for (let attempt = 0; attempt < 4; attempt++) {
          try {
            const res = await fetch(BASE_URL, {
              method: "POST",
              headers: HEADERS,
              body: JSON.stringify(payload),
              timeout: 25000
            });

            if (res.ok) {
              data = await res.json();
              success = true;
              break;
            }
          } catch (e) {
            console.warn(`${category} s:${page} deneme:${attempt + 1} başarısız`);
          }
          await new Promise(r => setTimeout(r, 5000 + attempt * 4000));
        }

        if (!success) {
          console.error(`${category} tamamen alınamadı.`);
          break;
        }

        const items = data.content || [];
        if (items.length === 0) break;

        for (const item of items) {
          const markets = (item.productDepotInfoList || [])
            .map(m => ({
              marketName: normalizeMarket(m.marketAdi || ""),
              branchName: m.depotName || "",
              price: parseFloat(m.price) || 0,
              unitPriceText: m.unitPrice || ""
            }))
            .filter(m => m.price > 0);

          if (markets.length > 0) {
            const key = item.id;
            if (!allProducts.has(key)) {
              allProducts.set(key, {
                id: item.id,
                title: item.title?.trim() || "İsimsiz",
                brand: item.brand || "Markasız",
                imageUrl: item.imageUrl || "",
                category: category,
                normalizedTitle: normalizeTitle(item.title || ""),
                markets: []
              });
            }
            allProducts.get(key).markets.push(...markets);
          }
        }
        page++;
        await new Promise(r => setTimeout(r, 4500 + Math.random() * 2500));
      }
    }));
  }

  // ADIM 3: KAYIT
  const collectionRef = admin.firestore().collection("market_prices");
  let batch = admin.firestore().batch();
  
  let totalProcessed = 0;
  let newProductsCount = 0;
  let updatedProductsCount = 0;

  for (const product of allProducts.values()) {
    if (existingProductIds.has(product.id)) {
        updatedProductsCount++;
    } else {
        newProductsCount++;
    }

    const seen = new Set();
    const unique = product.markets.filter(m => {
      const k = `${m.marketName}-${m.branchName}-${m.price}`;
      if (seen.has(k)) return false;
      seen.add(k);
      return true;
    });

    batch.set(collectionRef.doc(product.id), {
      title: product.title,
      brand: product.brand,
      imageUrl: product.imageUrl,
      category: product.category,
      normalizedTitle: product.normalizedTitle,
      markets: unique,
      updatedAt: now,
      source: 'system_auto',
      lastPriceCheck: admin.firestore.Timestamp.now()
    }, { merge: true });

    totalProcessed++;
    if (totalProcessed % 500 === 0) {
      await batch.commit();
      batch = admin.firestore().batch();
      console.log(`${totalProcessed} ürün işlendi...`);
    }
  }
  
  if (totalProcessed % 500 !== 0) await batch.commit();

  console.log("------------------------------------------------");
  console.log("📊 GÜNCELLEME RAPORU (GEN 2):");
  console.log(`Toplam İşlenen: ${totalProcessed}`);
  console.log(`✅ Yeni Eklenen: ${newProductsCount}`);
  console.log(`🔄 Güncellenen: ${updatedProductsCount}`);
  console.log("------------------------------------------------");
});

// ==========================================
// 2. FONKSİYON: ÜRÜN SAYISI GETİR (HTTP)
// ==========================================
exports.urunSayisiGetir = onRequest(async (req, res) => {
  try {
    // Hızlı sayım yöntemi (Aggregation)
    const coll = admin.firestore().collection("market_prices");
    const snapshot = await coll.count().get();
    
    res.json({
      durum: "Başarılı",
      toplamUrunSayisi: snapshot.data().count,
      zaman: new Date().toLocaleString("tr-TR")
    });
  } catch (error) {
    res.status(500).send("Hata oluştu: " + error.toString());
  }
});

// YARDIMCI FONKSİYONLAR
function normalizeTitle(t) {
  return t.toLowerCase()
    .replace(/[ıİ]/g,'i').replace(/[ğĞ]/g,'g')
    .replace(/[üÜ]/g,'u').replace(/[şŞ]/g,'s')
    .replace(/[öÖ]/g,'o').replace(/[çÇ]/g,'c')
    .replace(/[^a-z0-9]/g,'');
}

function normalizeMarket(n) {
  const u = (n || "").toUpperCase();
  if (u.includes("MİGROS")) return "MIGROS";
  if (u.includes("A101")) return "A101";
  if (u.includes("ŞOK")) return "SOK";
  if (u.includes("BİM") || u.includes("BIM")) return "BIM";
  if (u.includes("CARREFOUR")) return "CARREFOUR";
  if (u.includes("TARIM KREDİ")) return "TARIM_KREDİ";
  return u;
}