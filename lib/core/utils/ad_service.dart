import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  // Test Reklam Kimlikleri (Google'ın verdiği test ID'leri)
  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917' // Android Test ID
      : 'ca-app-pub-3940256099942544/1712485313'; // iOS Test ID

  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint("✅ Reklam Yüklendi!");
          _rewardedAd = ad;
          _isAdLoaded = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint("❌ Reklam Yüklenemedi: $error");
          _isAdLoaded = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  void showRewardedAd({required VoidCallback onRewardEarned}) {
    if (_rewardedAd != null && _isAdLoaded) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          loadRewardedAd(); // Bir sonraki için yenisini yükle
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          // Reklam gösterilemediyse de kullanıcıyı mağdur etme, ödülü ver
          onRewardEarned(); 
          loadRewardedAd();
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          // Kullanıcı reklamı sonuna kadar izledi!
          onRewardEarned();
        },
      );
    } else {
      debugPrint("⚠️ Reklam hazır değil, direkt geçiş veriliyor.");
      onRewardEarned(); // Reklam yüklenmediyse beklemesin, geçsin
      loadRewardedAd();
    }
  }
}