class UnitUtils {
  // Metinden miktar ve birimi ayıklar (Örn: "2 yemek kaşığı salça")
  static Map<String, dynamic> parseAmount(String ingredientText) {
    // 1. Sayıyı bul
    final numberRegExp = RegExp(r'(\d+[.,]?\d*)');
    final matchNumber = numberRegExp.firstMatch(ingredientText);
    double amount = 1.0; 
    
    if (matchNumber != null) {
      amount = double.tryParse(matchNumber.group(0)!.replaceAll(',', '.')) ?? 1.0;
    }

    // 2. Birimi bul (Standartlaştırma)
    String unit = 'adet'; // Varsayılan
    String lowerText = ingredientText.toLowerCase();

    if (lowerText.contains('kg') || lowerText.contains('kilogram')) {
      unit = 'kg';
    } else if (lowerText.contains('gr') || lowerText.contains('gram')) {
      unit = 'gr';
    } else if (lowerText.contains('lt') || lowerText.contains('litre')) {
      unit = 'lt';
    } else if (lowerText.contains('ml') || lowerText.contains('mililitre')) {
      unit = 'ml';
    } else if (lowerText.contains('su bardağı') || lowerText.contains('bardak')) {
      unit = 'bardak';
    } else if (lowerText.contains('yemek kaşığı') || lowerText.contains('kaşık')) {
      unit = 'kaşık';
    } else if (lowerText.contains('çay kaşığı') || lowerText.contains('tatlı kaşığı')) {
      unit = 'çay kaşığı';
    } else if (lowerText.contains('paket')) {
      unit = 'paket';
    } else if (lowerText.contains('diş')) {
      unit = 'diş';
    } else if (lowerText.contains('demet') || lowerText.contains('bağ')) {
      unit = 'demet';
    }

    return {'amount': amount, 'unit': unit};
  }

  // --- MASTER SEVİYE DÖNÜŞTÜRÜCÜ ---
  // Tüm birimleri en küçük yapı taşına (Gram veya Mililitre) çevirir.
  static double convertToBaseUnit(double amount, String unit) {
    String u = unit.toLowerCase();
    
    // AĞIRLIK (Baz: Gram)
    if (u == 'kg') return amount * 1000;
    if (u == 'gr' || u == 'g') return amount;
    
    // HACİM (Baz: Mililitre)
    if (u == 'lt' || u == 'l') return amount * 1000;
    if (u == 'ml') return amount;
    
    // MUTFAK ÖLÇÜLERİ (Tahmini Dönüşümler)
    if (u == 'bardak' || u == 'su bardağı') return amount * 200; // ~200 ml/gr
    if (u == 'kaşık' || u == 'yemek kaşığı') return amount * 15; // ~15 ml/gr
    if (u == 'çay kaşığı' || u == 'tatlı kaşığı') return amount * 5; 
    if (u == 'diş') return amount * 5; // 1 diş sarımsak ~5gr
    if (u == 'çay bardağı') return amount * 100;
    
    // Sayılabilir (Adet, Paket) - Bunlar dönüşmez, olduğu gibi kalır.
    return amount; 
  }

  // Akıllı Çıkarma İşlemi (4 Parametre - Basitleştirildi)
  static double? tryDeduct(double currentQty, String currentUnit, double deductQty, String deductUnit) {
    // 1. Birimler aynıysa direkt çıkar
    if (currentUnit == deductUnit) return currentQty - deductQty;

    // 2. Birimler farklıysa, dönüşülebilir mi kontrol et
    // Listeye "l", "g" gibi kısaltmaları da ekledik
    const validUnits = ['kg', 'gr', 'g', 'lt', 'l', 'ml', 'bardak', 'kaşık', 'çay kaşığı', 'su bardağı', 'yemek kaşığı'];
    bool isCurrentConvertible = validUnits.contains(currentUnit);
    bool isDeductConvertible = validUnits.contains(deductUnit);

    // Biri adet/paket iken diğeri kilo/litre ise çıkarma yapamayız (Dedektif Modu PantryService'de halledecek)
    if (!isCurrentConvertible || !isDeductConvertible) {
      return null; 
    }

    // 3. Her şeyi baz birime (gr/ml) çevir
    double currentBase = convertToBaseUnit(currentQty, currentUnit);
    double deductBase = convertToBaseUnit(deductQty, deductUnit);

    double remainingBase = currentBase - deductBase;

    // 4. Sonucu kilerdeki orijinal birime geri çevir
    if (currentUnit == 'kg' || currentUnit == 'lt' || currentUnit == 'l') {
      return remainingBase / 1000;
    }
    if (currentUnit == 'bardak' || currentUnit == 'su bardağı') {
      return remainingBase / 200;
    }
    
    return remainingBase; // gr, ml, kaşık vb.
  }
}