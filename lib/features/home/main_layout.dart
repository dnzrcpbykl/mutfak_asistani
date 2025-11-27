import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../recipes/recipe_recommendation_screen.dart';
import '../profile/profile_screen.dart';
import 'dashboard_screen.dart'; // EKLENDİ

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  // Sayfa değiştirme fonksiyonu (Dashboard'dan erişmek için)
  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sayfaları build metodunun içinde tanımlıyoruz ki context ve fonksiyonlara erişebilsinler
    final List<Widget> pages = [
      DashboardScreen(onTabChange: _changeTab), // 0: Ana Sayfa
      const HomeScreen(),                       // 1: Kiler & Alışveriş
      const RecipeRecommendationScreen(),       // 2: Şef
      const ProfileScreen(),                    // 3: Profil
    ];

    return Scaffold(
      body: pages[_currentIndex],
      
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _changeTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            selectedIcon: Icon(Icons.kitchen),
            label: 'Kilerim',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Şef',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}