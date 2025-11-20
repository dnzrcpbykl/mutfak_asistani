import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../recipes/recipe_recommendation_screen.dart';
import '../profile/profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  // Sayfaların Listesi
  final List<Widget> _pages = [
    const HomeScreen(),                // 0: Kiler
    const RecipeRecommendationScreen(), // 1: Şef/Tarifler
    const ProfileScreen(),             // 2: Profil
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Seçili sayfayı göster
      body: _pages[_currentIndex],
      
      // Alt Menü
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
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