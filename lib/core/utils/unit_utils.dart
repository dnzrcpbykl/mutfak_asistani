class UnitUtils {
  // Metinden miktar ve birimi ayıklar (Örn: "500 gr kıyma" -> {amount: 500, unit: 'gr'})
  static Map<String, dynamic> parseAmount(String ingredientText) {
    // 1. Sayıyı bul (Ondalıklı da olabilir: 2.5 veya 2,5)
    final numberRegExp = RegExp(r'(\d+[.,]?\d*)');
    final matchNumber = numberRegExp.firstMatch(ingredientText);
    
    double amount = 1.0; // Varsayılan
    if (matchNumber != null) {
      amount = double.tryParse(matchNumber.group(0)!.replaceAll(',', '.')) ?? 1.0;
    }

    // 2. Birimi bul
    String unit = 'adet'; // Varsayılan
    String lowerText = ingredientText.toLowerCase();

    if (lowerText.contains('kg') || lowerText.contains('kilogram')) unit = 'kg';
    else if (lowerText.contains('gr') || lowerText.contains('gram')) unit = 'gr';
    else if (lowerText.contains('lt') || lowerText.contains('litre')) unit = 'lt';
    else if (lowerText.contains('ml') || lowerText.contains('mililitre')) unit = 'ml';
    else if (lowerText.contains('bardak')) unit = 'bardak';
    else if (lowerText.contains('kaşık')) unit = 'kaşık';
    else if (lowerText.contains('paket')) unit = 'paket';

    return {'amount': amount, 'unit': unit};
  }

  // Miktarları aynı birime çevirip çıkarma işlemi yapar
  // Dönüş: Kalan Miktar (Kendi biriminde). Eğer dönüşüm yapılamazsa null döner.
  static double? tryDeduct(double currentQty, String currentUnit, double deductQty, String deductUnit) {
    // A) Birimler Aynıysa
    if (currentUnit == deductUnit) {
      return currentQty - deductQty;
    }

    // B) KG -> GR Dönüşümü
    if (currentUnit == 'kg' && deductUnit == 'gr') {
      return currentQty - (deductQty / 1000);
    }
    // C) GR -> KG Dönüşümü
    if (currentUnit == 'gr' && deductUnit == 'kg') {
      return currentQty - (deductQty * 1000);
    }

    // D) LT -> ML Dönüşümü
    if (currentUnit == 'lt' && deductUnit == 'ml') {
      return currentQty - (deductQty / 1000);
    }
    // E) ML -> LT Dönüşümü
    if (currentUnit == 'ml' && deductUnit == 'lt') {
      return currentQty - (deductQty * 1000);
    }

    // Dönüşüm yapılamadı (Örn: Adet'ten Kg çıkarılamaz)
    return null; 
  }
}