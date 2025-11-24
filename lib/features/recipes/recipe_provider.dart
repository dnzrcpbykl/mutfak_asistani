import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Bu import eksik olabilir, ekleyelim
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

  // Hafızada tutacağımız listeler
  List<Recipe> _allRecipes = [];
  List<MarketPrice> _allPrices = [];
  List<Map<String, dynamic>> _recommendations = [];
  
  bool _isLoading = false;
  String? _error;

  // Getter metodları
  List<Map<String, dynamic>> get recommendations => _recommendations;
  List<MarketPrice> get allPrices => _allPrices;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Verileri çekip eşleşmeyi hesaplayan ana fonksiyon
  Future<void> fetchAndCalculateRecommendations() async {
    _isLoading = true;
    _error = null;
    notifyListeners(); 

    try {
      // 1. Tüm verileri paralel olarak çek
      final results = await Future.wait([
        _recipeService.getRecipes(),
        _marketService.getAllPrices(),
        _pantryService.pantryRef.get(), // Kileri anlık çekiyoruz
      ]);

      _allRecipes = results[0] as List<Recipe>;
      _allPrices = results[1] as List<MarketPrice>;
      
      // --- DÜZELTME BURADA YAPILDI ---
      // Servisimizde "withConverter" olduğu için, gelen veri zaten PantryItem nesnesidir.
      // Tekrar çevirmeye çalışmak (Map olarak okumaya çalışmak) hataya sebep oluyordu.
      // Doğrudan .data() diyerek nesneyi alıyoruz.
      
      final pantrySnapshot = results[2] as QuerySnapshot<PantryItem>;
      final pantryItems = pantrySnapshot.docs
          .map((doc) => doc.data()) // doc.data() zaten PantryItem tipindedir
          .toList();
      // -------------------------------

      // 2. Eşleşme mantığını çalıştır
      _recommendations = _recipeService.matchRecipes(pantryItems, _allRecipes);

    } catch (e) {
      _error = "Veriler yüklenirken hata oluştu: $e";
      debugPrint("RecipeProvider Hatası: $e"); // Konsola detaylı hata basar
    } finally {
      _isLoading = false;
      notifyListeners(); 
    }
  }
}