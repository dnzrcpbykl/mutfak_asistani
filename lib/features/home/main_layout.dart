import 'package:flutter/material.dart';
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

  // Sayfa değiştirme fonksiyonu
  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // Sayfaları buraya tanımlıyoruz
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Sayfaları bir kere oluşturuyoruz
    _pages = [
      DashboardScreen(onTabChange: _changeTab), // 0: Ana Sayfa
      const HomeScreen(),                       // 1: Kiler & Alışveriş
      const RecipeRecommendationScreen(),       // 2: Şef
      const ProfileScreen(),                    // 3: Profil
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ESKİ KOD: body: _pages[_currentIndex],
      // YENİ KOD: IndexedStack (Sayfaları hafızada tutar)
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      
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