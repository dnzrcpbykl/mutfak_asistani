const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

admin.initializeApp();

const BASE_URL = "https://api.marketfiyati.org.tr/api/v2/searchByCategories";

// En gerçekçi header'lar (Chrome 131, 2025)
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

exports.weeklyMarketPriceUpdate = functions
  .region("europe-west1")
  .runWith({ timeoutSeconds: 540, memory: "2GB" })
  .pubsub.schedule("0 6 * * 3")
  .timeZone("Europe/Istanbul")
  .onRun(async (context) => {
    console.log("HIZLI TÜRKİYE FİYAT GÜNCELLEME BAŞLADI:", new Date());

    const allProducts = new Map();
    const now = admin.firestore.FieldValue.serverTimestamp();

    // PARALEL ÇALIŞTIR: 3 kategori aynı anda!
    const chunkSize = 3;
    for (let i = 0; i < CATEGORIES.length; i += chunkSize) {
      const chunk = CATEGORIES.slice(i, i + chunkSize);

      await Promise.all(chunk.map(async (category) => {
        console.log(`Kategori başladı: ${category}`);
        let page = 0;

        while (true) {
          const payload = {
            menuCategory: true,
            keywords: category,
            pages: page,
            size: 100,              // 100 istiyoruz (bazen 50, bazen 100 veriyor)
            latitude: 39.9208,
            longitude: 32.8541,
            distance: 2000,
            depots: []
          };

          let data;
          let success = false;

          // 4 kez dene
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
              console.warn(`${category} sayfa ${page} deneme ${attempt + 1} başarısız`);
            }
            await new Promise(r => setTimeout(r, 5000 + attempt * 4000));
          }

          if (!success) {
            console.error(`${category} kategorisi tamamen alınamadı.`);
            break;
          }

          const items = data.content || [];
          if (items.length === 0) break;

          console.log(`${category} - Sayfa ${page} → ${items.length} ürün`);

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

          // HIZLI AMA GÜVENLİ: 4.5 - 7 saniye rastgele bekle
          await new Promise(r => setTimeout(r, 4500 + Math.random() * 2500));
        }
      }));
    }

    // Firestore'a yaz
    const collectionRef = admin.firestore().collection("market_prices");
    let batch = admin.firestore().batch();
    let count = 0;

    for (const product of allProducts.values()) {
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
        source: 'system_auto',   // BU ÇOK ÖNEMLİ! Bu verinin robottan geldiğini kanıtlar.
        lastPriceCheck: admin.firestore.Timestamp.now() // Ekstra kontrol alanı
      }, { merge: true });

      count++;
      if (count % 500 === 0) {
        await batch.commit();
        batch = admin.firestore().batch();
      }
    }
    if (count % 500 !== 0) await batch.commit();

    console.log(`BİTTİ! ${allProducts.size} ürün kaydedildi. Süre: ~45-55 dakika`);
    return null;
  });

// normalize fonksiyonları aynı kalıyor...
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