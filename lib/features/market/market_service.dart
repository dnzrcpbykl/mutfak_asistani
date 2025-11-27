import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/market_price.dart';

class MarketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Tüm market fiyatlarını getirir
  Future<List<MarketPrice>> getAllPrices() async {
    final snapshot = await _firestore.collection('market_prices').get();
    return snapshot.docs.map((doc) => MarketPrice.fromFirestore(doc)).toList();
  }

  // --- YENİ: FİYAT KAYDETME FONKSİYONU ---
  // Fişten okunan fiyatı, diğer kullanıcıların da faydalanabileceği (veya senin referans alacağın) havuza atar.
  Future<void> addPriceInfo(String ingredientName, String marketName, double price) async {
    // Önce bu ürün ve market kombinasyonu var mı bakalım
    final query = await _firestore.collection('market_prices')
        .where('ingredientName', isEqualTo: ingredientName)
        .where('marketName', isEqualTo: marketName)
        .get();

    if (query.docs.isNotEmpty) {
      // Varsa fiyatı güncelle
      await query.docs.first.reference.update({
        'price': price,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Yoksa yeni ekle
      await _firestore.collection('market_prices').add({
        'ingredientName': ingredientName,
        'marketName': marketName,
        'price': price,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
  // ---------------------------------------

  // Eksik maliyeti hesapla
  double calculateMissingCost(List<String> missingIngredients, List<MarketPrice> allPrices) {
    double totalCost = 0;
    
    for (var missingItem in missingIngredients) {
      // 1. Aranacak kelimeyi temizle (Örn: "Yarım Yağlı Süt" -> "yarım yağlı süt")
      String searchKey = missingItem.trim().toLowerCase();
      
      // Fiyat listesinden uygun olanları filtrele
      final pricesForThis = allPrices.where((p) {
        String marketItemName = p.ingredientName.toLowerCase().trim();

        // A) Tam Eşleşme (En Güvenli): "süt" == "süt"
        if (marketItemName == searchKey) return true;

        // B) Kelime Bazlı Kontrol (Daha Akıllı):
        // "Torku Süt" ismini kelimelere böl: ["torku", "süt"]
        // Listede "süt" kelimesi bağımsız olarak var mı? EVET.
        // "Sütlaç" kelimesi "süt" içerir mi? HAYIR (Kelime bütünlüğü bozulmaz).
        List<String> marketWords = marketItemName.split(' ');
        if (marketWords.contains(searchKey)) return true;
        
        // C) Tersine Kontrol: Kullanıcı "Torku Süt" yazdıysa, marketteki "Süt" fiyatını da kabul et
        List<String> searchWords = searchKey.split(' ');
        if (searchWords.contains(marketItemName)) return true;

        return false;
      }).toList();

      if (pricesForThis.isNotEmpty) {
        // Bulunanlar arasından en ucuz fiyatı baz al
        pricesForThis.sort((a, b) => a.price.compareTo(b.price));
        totalCost += pricesForThis.first.price;
      }
    }
    return totalCost;
  }
}