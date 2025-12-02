// lib/features/recipes/recipe_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/recipe.dart';
import '../../core/models/market_price.dart'; // Yeni model
import '../../core/models/pantry_item.dart';
import 'recipe_service.dart';
import '../market/market_service.dart';
import '../pantry/pantry_service.dart';

class RecipeProvider extends ChangeNotifier {
  final RecipeService _recipeService = RecipeService();
  final MarketService _marketService = MarketService();
  final PantryService _pantryService = PantryService();
  final Set<String> _completedRecipeNames = {};

  bool isRecipeCompleted(String name) => _completedRecipeNames.contains(name);

  void markRecipeAsCompleted(String name) {
    _completedRecipeNames.add(name);
    notifyListeners();
  }

  List<Recipe> _allRecipes = [];
  List<MarketPrice> _allPrices = []; // Tipi güncelledik
  List<Map<String, dynamic>> _recommendations = [];
  
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get recommendations => _recommendations;
  List<MarketPrice> get allPrices => _allPrices;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // CACHING DESTEKLİ FONKSİYON
  Future<void> fetchAndCalculateRecommendations({bool forceRefresh = false}) async {
    // Eğer veri zaten varsa ve zorla yenileme istenmiyorsa, çıkış yap (HIZ KAZANDIRIR)
    if (!forceRefresh && _recommendations.isNotEmpty && _allRecipes.isNotEmpty) {
      return; 
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final pantryCollectionRef = await _pantryService.getPantryCollection();

      final results = await Future.wait([
        _recipeService.getRecipes(),
        _marketService.getAllPrices(), // Yeni yapıyı çekecek
        pantryCollectionRef.get(), 
      ]);

      _allRecipes = results[0] as List<Recipe>;
      _allPrices = results[1] as List<MarketPrice>; // Yeni liste

      final pantrySnapshot = results[2] as QuerySnapshot<PantryItem>;
      final pantryItems = pantrySnapshot.docs
          .map((doc) => doc.data()) 
          .toList();

      // Eşleşme hesaplama
      _recommendations = _recipeService.matchRecipes(pantryItems, _allRecipes);

    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        _recommendations = [];
        _error = null;
      } else {
        _error = "Veriler yüklenirken hata oluştu: $e";
        debugPrint("RecipeProvider Hatası: $e");
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearData() {
    _allRecipes = [];
    _allPrices = [];
    _recommendations = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}