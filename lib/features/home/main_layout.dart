import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // EKLENDİ
import '../../core/utils/ad_service.dart'; // EKLENDİ
import 'home_screen.dart';
import '../recipes/recipe_recommendation_screen.dart';
import '../profile/profile_screen.dart';
import 'dashboard_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  
  // --- REKLAM DEĞİŞKENLERİ ---
  BannerAd? _bottomBannerAd;
  bool _isBannerAdReady = false;
  final AdService _adService = AdService();

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardScreen(onTabChange: _changeTab), 
      const HomeScreen(),                       
      const RecipeRecommendationScreen(),       
      const ProfileScreen(),                    
    ];

    // Reklamı yükle
    _bottomBannerAd = _adService.createBannerAd(
      onAdLoaded: () {
        if (mounted) setState(() => _isBannerAdReady = true);
      }
    )..load();
  }

  @override
  void dispose() {
    _bottomBannerAd?.dispose(); // Hafıza sızıntısını önle
    super.dispose();
  }

  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Body'i Column içine aldık ki reklamı en alta sıkıştıralım
      body: Column(
        children: [
          // Sayfa İçeriği (Geri kalan alanı kaplar)
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
          
          // SABİT REKLAM ALANI
          if (_isBannerAdReady && _bottomBannerAd != null)
            SizedBox(
              width: _bottomBannerAd!.size.width.toDouble(),
              height: _bottomBannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bottomBannerAd!),
            ),
        ],
      ),
      
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _changeTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Ana Sayfa'),
          NavigationDestination(icon: Icon(Icons.kitchen_outlined), selectedIcon: Icon(Icons.kitchen), label: 'Kilerim'),
          NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: 'Şef'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}