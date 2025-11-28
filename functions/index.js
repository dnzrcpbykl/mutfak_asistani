const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const logger = require("firebase-functions/logger");

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// GÜVENLİK AYARLARI (Senin orijinal kodundaki ayarlar - Hepsine izin ver)
const safetySettings = [
  { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" },
  { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE" },
  { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
  { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" },
];

// --- 1. FİŞ TARAMA FONKSİYONU ---
exports.analyzeReceipt = onCall({ secrets: ["GEMINI_API_KEY"], timeoutSeconds: 60 }, async (request) => {
  const base64Image = request.data.image;
  
  if (!base64Image) {
    throw new HttpsError('invalid-argument', 'Resim verisi gönderilmedi.');
  }

  try {
    // Modeli güvenlik ayarlarıyla birlikte başlatıyoruz
    const model = genAI.getGenerativeModel({ 
      model: "gemini-1.5-flash",
      safetySettings: safetySettings 
    });

    const prompt = `
      Bu market fişini analiz et ve aşağıdaki katı kurallara göre JSON formatında döndür.
      GÖREV 1: MARKET TESPİTİ
      "BIM", "A101", "SOK", "MIGROS", "CARREFOURSA" veya "DIGER".
      GÖREV 2: SADECE GIDA ÜRÜNLERİNİ AYIKLA
      Listeye SADECE insanın yiyip içebileceği GIDA ürünlerini al.
      ❌ Temizlik, Kişisel Bakım, Kağıt Ürünleri, Mutfak Gereçleri, Hayvan Mamaları, Poşet, İndirim, KDV satırlarını KESİNLİKLE GÖRMEZDEN GEL.
      GÖREV 3: MİKTAR VE BİRİM ANALİZİ (EN ÖNEMLİ KISIM)
      Fişte yazan miktarları ve birimleri şu mantıkla dönüştür:
      
      A) ÇOKLU PAKETLERİ AÇ (Multipacks):
         - Fişte "4x1L Süt" veya "6x200ml Meyve Suyu" yazıyorsa:
           -> amount: 4 (veya 6), unit: "adet".
           -> product_name: "Süt (1L)" veya "Meyve Suyu (200ml)".
           (Yani paketi patlat, içindeki adet sayısını 'amount' olarak ver.)

      B) BOYUTU MİKTAR SANMA (Size Confusion):
         - Fişte "PİRİNÇ 2.5KG" veya "GAZOZ 2.5L" yazıyorsa, buradaki 2.5 ürünün boyutudur, adedi DEĞİLDİR.
           -> amount: 1 (Eğer başında '2 AD' yazmıyorsa 1 kabul et).
           -> unit: "adet".
           -> product_name: "Pirinç (2.5kg)" veya "Gazoz (2.5L)".
      
      C) ADETLİ ÜRÜNLER:
         - Fişte "2 AD X 15.00" şeklinde satır varsa 'amount' 2 olmalıdır.
      GÖREV 4: KATEGORİLENDİRME
      1. "Et & Tavuk & Balık": (Kıyma, Tavuk, Balık, Sucuk, Sosis vb.)
      2. "Süt & Kahvaltılık": (Süt, Peynir, Yoğurt, Yumurta, Tereyağı, Zeytin vb.)
      3. "Meyve & Sebze": (Domates, Biber, Soğan, Meyveler vb.)
      4. "Temel Gıda & Bakliyat": (Un, Şeker, Tuz, Yağ, Pirinç, Makarna, Salça vb.)
      5. "Atıştırmalık": (Çikolata, Cips, Bisküvi, Kuruyemiş, Dondurma vb.)
      6. "İçecekler": (Su, Kola, Gazoz, Çay, Kahve vb.)
      7. "Diğer": (Diğer yenebilir gıdalar)

      VERİ FORMATI (JSON):
      - "product_name": Ürünün adı (Boyut bilgisi parantez içinde olsun. Örn: "Tavuk Baget (1kg)").
      Markayı isme dahil etme, 'brand' alanına yaz.
      - "brand": Marka (Örn: "Torku", "Pınar"). Yoksa null.
      - "price": Son fiyat (Sayı).
      - "amount": Toplam adet (Sayı).
      - "unit": Sadece "adet" kullan.
      (Litre veya Kg olsa bile 'adet' yaz, boyutu isme parantez içine ekle).
      - "days_to_expire": Tahmini raf ömrü (gün).
      CEVAP ÖRNEĞİ:
      {
        "market_name": "MIGROS",
        "items": [
          {"product_name": "Yağlı Süt (1L)", "brand": "Torku", "category": "Süt & Kahvaltılık", "price": 100.00, "days_to_expire": 7, "amount": 4, "unit": "adet"},
          {"product_name": "Baldo Pirinç (2.5kg)", "brand": "Efsane", "category": "Temel Gıda & Bakliyat", "price": 135.00, "days_to_expire": 365, "amount": 1, "unit": "adet"}
        ]
      }
    `;

    const imagePart = {
      inlineData: {
        data: base64Image,
        mimeType: "image/jpeg",
      },
    };

    const result = await model.generateContent([prompt, imagePart]);
    const response = await result.response;
    const text = response.text();

    let cleanJson = text.replace(/```json/g, "").replace(/```/g, "").trim();
    const startIndex = cleanJson.indexOf('{');
    const endIndex = cleanJson.lastIndexOf('}');
    
    if (startIndex !== -1 && endIndex !== -1) {
      cleanJson = cleanJson.substring(startIndex, endIndex + 1);
    }

    return JSON.parse(cleanJson);

  } catch (error) {
    logger.error("Gemini Hatası:", error);
    // Hata detayını istemciye dönelim ki sorunu görebilelim
    throw new HttpsError('internal', `Fiş analiz hatası: ${error.message}`);
  }
});

// --- 2. TARİF ÜRETME FONKSİYONU ---
exports.generateRecipes = onCall({ secrets: ["GEMINI_API_KEY"], timeoutSeconds: 60 }, async (request) => {
  const ingredients = request.data.ingredients;
  const userPreference = request.data.preference || "Fark etmez, genel öneriler ver.";

  if (!ingredients || ingredients.length === 0) {
    throw new HttpsError('invalid-argument', 'Malzeme listesi boş.');
  }

  try {
    // Modeli güvenlik ayarlarıyla birlikte başlatıyoruz
    const model = genAI.getGenerativeModel({ 
      model: "gemini-1.5-flash",
      safetySettings: safetySettings 
    });
    
    const ingredientsText = ingredients.join(", ");

    const prompt = `
      Sen Türk mutfağına hakim, teknik detaylara önem veren profesyonel bir şefsin.
      Elimdeki malzemeler: [${ingredientsText}]
      
      **KULLANICI TERCİHİ (ÇOK ÖNEMLİ):** Kullanıcı şu tarz yemekler istiyor: "${userPreference}".
      Lütfen tarifleri seçerken BU TERCİHE ÖNCELİK VER.
      
      GÖREVİN:
      Bu malzemelerin çoğunluğunu (ve gerekirse her evde bulunan su, tuz, karabiber, sıvı yağ, salça gibi temel malzemeleri de ekleyerek) kullanarak yapılabilecek en iyi 5 tarifi oluştur.
      ÇOK ÖNEMLİ KURALLAR (BUNLARA KESİN UY):
      1. **NET MİKTARLAR:** Malzeme listesinde ASLA belirsiz ifade kullanma.
      "Yumurta" YAZMA, "2 adet Yumurta" YAZ. "Un" YAZMA, "1 su bardağı Un" YAZ. Miktarı olmayan malzeme kabul edilmez.
      2. **NET SÜRELER:** Yapılış adımlarında "pişirin" veya "haşlayın" deyip geçme.
      "Kısık ateşte 15 dakika pişirin", "200 derece fırında 25 dakika bekletin" gibi net SÜRE ve ISI bilgisi ver.
      3. **MARKA YOK:** Marka adı kullanma (Örn: "Pakmaya" değil "Maya" yaz).
      4. **KATEGORİLER:** Çorba, Ana Yemek, Ara Sıcak veya Tatlı olarak belirt.
      İSTENEN JSON FORMATI (Sadece bu JSON'u döndür, yorum yapma):
      [
        {
          "name": "Yemek Adı",
          "description": "Yemeğin kısa, iştah açıcı tanımı",
          "ingredients": [
            "2 adet Yumurta", 
            "1 su bardağı Süt", 
            "500 gr Kıyma", 
            "1 çay kaşığı Tuz"
          ], 
          "instructions": "1. Kıymayı tavaya alın ve suyunu çekene kadar (yaklaşık 10 dk) kavurun.\\n2. Soğanları ekleyip pembeleşinceye kadar 5 dakika daha kavurun.\\n3. ...",
          "prepTime": 30,
          "difficulty": "Orta", 
          "category": "Ana Yemek"
        }
      ]
    `;

    const result = await model.generateContent(prompt);
    const response = await result.response;
    let text = response.text();

    let cleanJson = text.replace(/```json/g, "").replace(/```/g, "").trim();
    const startIndex = cleanJson.indexOf('[');
    const endIndex = cleanJson.lastIndexOf(']');
    
    if (startIndex !== -1 && endIndex !== -1) {
      cleanJson = cleanJson.substring(startIndex, endIndex + 1);
    }

    return JSON.parse(cleanJson);

  } catch (error) {
    logger.error("Tarif Üretme Hatası:", error);
    throw new HttpsError('internal', `Tarif üretilemedi: ${error.message}`);
  }
});