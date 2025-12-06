import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  // TEST ID'leri (Sabit)
  final String _rewardedAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917' 
      : 'ca-app-pub-3940256099942544/1712485313';

  final String _bannerAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111' // Android Test Banner
      : 'ca-app-pub-3940256099942544/2934735716'; // iOS Test Banner

  // --- MEVCUT REWARDED AD KODLARI (AYNEN KALIYOR) ---
  void loadRewardedAd() {
    // ... (Eski kodlarınız burada duracak) ...
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint("✅ Ödüllü Reklam Yüklendi!");
          _rewardedAd = ad;
          _isAdLoaded = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint("❌ Ödüllü Reklam Yüklenemedi: $error");
          _isAdLoaded = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  void showRewardedAd({required VoidCallback onRewardEarned}) {
     // ... (Eski kodlarınız burada duracak) ...
     if (_rewardedAd != null && _isAdLoaded) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          loadRewardedAd(); 
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          onRewardEarned(); 
          loadRewardedAd();
        },
      );
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          onRewardEarned();
        },
      );
    } else {
      debugPrint("⚠️ Reklam hazır değil, direkt geçiş veriliyor.");
      onRewardEarned();
      loadRewardedAd();
    }
  }

  // --- YENİ EKLENEN: BANNER REKLAM ÜRETİCİ ---
  // Bu fonksiyon her çağrıldığında yeni bir Banner nesnesi yaratır.
  BannerAd createBannerAd({required Function() onAdLoaded}) {
    return BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner, // Standart boyut (320x50)
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint("Banner reklam yüklendi.");
          onAdLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint("Banner reklam hatası: $error");
          ad.dispose();
        },
      ),
    );
  }
  
  // Liste içi için "Medium Rectangle" (Kareye yakın) reklam daha iyi durur
  BannerAd createInlineAd({required Function() onAdLoaded}) {
    return BannerAd(
      adUnitId: _bannerAdUnitId, // Test için aynı ID kullanılır
      size: AdSize.mediumRectangle, // 300x250 boyutunda büyük kart reklam
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onAdLoaded(),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
  }
}