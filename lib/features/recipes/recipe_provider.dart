// lib/features/recipes/recipe_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/recipe.dart';
import '../../core/models/market_price.dart';
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
  List<MarketPrice> _allPrices = [];
  List<Map<String, dynamic>> _recommendations = [];
  
  bool _isLoading = false;
  String? _error;

  // Cache Kontrolü için zaman damgası
  DateTime? _lastPriceFetchTime;

  List<Map<String, dynamic>> get recommendations => _recommendations;
  List<MarketPrice> get allPrices => _allPrices;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchAndCalculateRecommendations({bool forceRefresh = false}) async {
    // Eğer işlem zaten sürüyorsa tekrar başlatma
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners(); // Yükleniyor dairesini göster

    try {
      // 1. ADIM: Önce SADECE Tarifler ve Kileri çek (Hızlıdır)
      final pantryRef = await _pantryService.getPantryCollection();
      
      final results = await Future.wait([
        _recipeService.getRecipes(),
        pantryRef.get(),
      ]);

      _allRecipes = results[0] as List<Recipe>;
      final pantrySnapshot = results[1] as QuerySnapshot<PantryItem>;
      final pantryItems = pantrySnapshot.docs.map((doc) => doc.data()).toList();

      // Fiyatlar olmadan ilk hesaplamayı yap (Kullanıcı beklemesin)
      _recommendations = _recipeService.matchRecipes(pantryItems, _allRecipes);
      
      // İlk görüntüyü kullanıcıya ver
      _isLoading = false;
      notifyListeners(); 

      // 2. ADIM: Fiyatları Arka Planda Kontrol Et (Cache Mantığı)
      // Eğer son 1 saat içinde fiyat çektiysek tekrar çekme.
      if (forceRefresh || _shouldFetchPrices()) {
        debugPrint("🌍 Market fiyatları sunucudan güncelleniyor...");
        _allPrices = await _marketService.getAllPrices();
        _lastPriceFetchTime = DateTime.now();
        
        // Fiyatlar geldikten sonra listeyi tekrar hesapla (Maliyetler görünsün diye)
        if (_allPrices.isNotEmpty) {
           _recommendations = _recipeService.matchRecipes(pantryItems, _allRecipes);
           notifyListeners(); // Sessizce güncelle
        }
      } else {
        debugPrint("⚡ Fiyatlar önbellekten kullanıldı.");
      }

    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        _recommendations = [];
        _error = null;
      } else {
        _error = "Veriler yüklenirken hata: $e";
        debugPrint("RecipeProvider Hatası: $e");
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  // 60 dakikada bir fiyatları yenile
  bool _shouldFetchPrices() {
    if (_allPrices.isEmpty) return true;
    if (_lastPriceFetchTime == null) return true;
    final difference = DateTime.now().difference(_lastPriceFetchTime!);
    return difference.inMinutes > 60;
  }

  void clearData() {
    _allRecipes = [];
    _allPrices = [];
    _recommendations = [];
    _error = null;
    _isLoading = false;
    _lastPriceFetchTime = null; // Çıkış yapınca cache temizle
    notifyListeners();
  }
}