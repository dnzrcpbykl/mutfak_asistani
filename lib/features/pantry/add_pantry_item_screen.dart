import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:intl/intl.dart'; 
import 'package:image_picker/image_picker.dart'; 

import '../../core/models/ingredient.dart';
import '../../core/models/pantry_item.dart';
import 'pantry_service.dart';
import '../ocr/ocr_service.dart'; 
import '../ocr/scanned_products_screen.dart';

class AddPantryItemScreen extends StatefulWidget {
  const AddPantryItemScreen({super.key});

  @override
  State<AddPantryItemScreen> createState() => _AddPantryItemScreenState();
}

class _AddPantryItemScreenState extends State<AddPantryItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _ingredientNameController = TextEditingController();
  DateTime? _selectedExpirationDate;

  List<Ingredient> _searchResults = []; 
  Ingredient? _selectedIngredient; 

  final PantryService _pantryService = PantryService();
  final OCRService _ocrService = OCRService();
  bool _isLoading = false;

  // ... (Manuel Ekleme Fonksiyonları Aynen Kalıyor - _searchIngredients, _selectDate, _addItemToPantry) ...
  
  void _searchIngredients(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = await _pantryService.searchIngredients(query);
    setState(() => _searchResults = results);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpirationDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedExpirationDate) {
      setState(() => _selectedExpirationDate = picked);
    }
  }

  Future<void> _addItemToPantry() async {
    if (_formKey.currentState!.validate()) {
      String ingredientId = _selectedIngredient?.id ?? '';
      String ingredientName = _ingredientNameController.text.trim();
      String unit = _selectedIngredient?.unit ?? 'adet';

      if (ingredientName.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir malzeme ismi girin.")));
        return;
      }

      setState(() => _isLoading = true);

      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) throw Exception("Kullanıcı oturumu açmamış.");

        String category = _selectedIngredient?.category ?? 'Diğer';

        final newItem = PantryItem(
          id: '', 
          userId: currentUser.uid,
          ingredientId: ingredientId, 
          ingredientName: ingredientName,
          quantity: double.parse(_quantityController.text),
          unit: unit, 
          expirationDate: _selectedExpirationDate,
          createdAt: Timestamp.now(),
          category: category
        );

        await _pantryService.addPantryItem(newItem);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ürün kiler'e başarıyla eklendi!")));
        Navigator.of(context).pop(); 

      } catch (e) {
        if (mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: ${e.toString()}")));
      } finally {
        if (context.mounted) setState(() => _isLoading = false);
      }
    }
  }

  // --- GÜNCELLENMİŞ GÖRÜNTÜ İŞLEME ---
  Future<void> _processImage(ImageSource source) async {
    // 1. Resmi Seç
    final imagePath = await _ocrService.pickImage(source);
    
    if (imagePath != null && mounted) {
      // 2. Yükleniyor Dialogu
      showDialog(
        context: context,
        barrierDismissible: false, 
        builder: (_) => Dialog(
          backgroundColor: Theme.of(context).cardTheme.color,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 20),
                Text("Cyber Chef Fişi Okuyor...", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 8),
                Text("Gıda ürünleri ayıklanıyor...", style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              ],
            ),
          ),
        ),
      );

      try {
        // 3. HİBRİT OCR SERVİSİNE GÖNDER
        final scannedData = await _ocrService.textToIngredients(imagePath);

  if (mounted) Navigator.of(context).pop(); 
  if (!mounted) return;

  // Kontrol değişti: scannedData boş mu diye bakıyoruz, items var mı diye bakıyoruz
  if (scannedData.isNotEmpty && scannedData['items'] != null && (scannedData['items'] as List).isNotEmpty) {
    
    Navigator.of(context).push(
      MaterialPageRoute(
        // Parametre adı değişti: scannedData
        builder: (context) => ScannedProductsScreen(scannedData: scannedData),
      ),
    );
  } else {
          // 5. Başarısızsa Uyarı Ver
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Fiş okunamadı veya gıda ürünü bulunamadı. Lütfen daha net bir fotoğraf çekin."), 
              backgroundColor: Theme.of(context).colorScheme.error
            ),
          );
        }
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("İşlem Hatası: $e"), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  // --- SEÇİM MENÜSÜ (BOTTOM SHEET) ---
  void _showImageSourceSheet() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Fiş Yükleme Yöntemi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.camera_alt, color: colorScheme.primary),
                ),
                title: Text("Kamerayı Aç", style: TextStyle(color: colorScheme.onSurface)),
                onTap: () {
                  Navigator.pop(context); 
                  _processImage(ImageSource.camera); 
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library, color: Colors.purpleAccent),
                ),
                title: Text("Galeriden Seç", style: TextStyle(color: colorScheme.onSurface)),
                onTap: () {
                  Navigator.pop(context); 
                  _processImage(ImageSource.gallery); 
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Ürün Ekle")),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // ... (Manuel Ekleme Kısımları Aynı) ...
                    TextFormField(
                      controller: _ingredientNameController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: "Malzeme Adı",
                        hintText: "Örn: Domates, Un",
                        suffixIcon: _ingredientNameController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _ingredientNameController.clear();
                                    _selectedIngredient = null;
                                    _searchResults = [];
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: _searchIngredients,
                      validator: (value) {
                        if (value == null || value.isEmpty) return "Lütfen malzeme adını girin.";
                        return null;
                      },
                    ),
                    
                    if (_searchResults.isNotEmpty && _selectedIngredient == null)
                      Container(
                        height: 150,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(5),
                          color: Theme.of(context).cardColor,
                        ),
                        child: ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final ingredient = _searchResults[index];
                            return ListTile(
                              title: Text(ingredient.name, style: TextStyle(color: colorScheme.onSurface)),
                              subtitle: Text("${ingredient.category} (${ingredient.unit})", style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6))),
                              onTap: () {
                                setState(() {
                                  _selectedIngredient = ingredient;
                                  _ingredientNameController.text = ingredient.name;
                                  _searchResults = []; 
                                });
                              },
                            );
                          },
                        ),
                      ),
                    
                    if (_ingredientNameController.text.isNotEmpty && _selectedIngredient == null && _searchResults.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final newIngredientName = _ingredientNameController.text.trim();
                            if (newIngredientName.isNotEmpty) {
                              final newIngredient = Ingredient(id: '', name: newIngredientName, category: 'Diğer', unit: 'adet');
                              await _pantryService.addIngredientToSystem(newIngredient);
                              if (!context.mounted) return;
                              setState(() {
                                _selectedIngredient = newIngredient; 
                                _searchResults = []; 
                              });
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yeni malzeme veritabanına eklendi.")));
                            }
                          },
                          icon: const Icon(Icons.add_box),
                          label: Text("Yeni Malzeme Ekle: '${_ingredientNameController.text}'"),
                          style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondary, foregroundColor: Colors.black),
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: "Miktar (${_selectedIngredient?.unit ?? 'adet'})",
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return "Lütfen miktarı girin.";
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _selectedExpirationDate == null
                            ? "Son Kullanma Tarihi Seç (İsteğe Bağlı)"
                            : "Son Kullanma Tarihi: ${DateFormat('dd/MM/yyyy').format(_selectedExpirationDate!)}",
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                      trailing: Icon(Icons.calendar_today, color: colorScheme.primary),
                      onTap: () => _selectDate(context),
                    ),
                    
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _addItemToPantry,
                      icon: const Icon(Icons.save),
                      label: const Text("Kilerime Ekle"),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
                    ),
                    
                    const SizedBox(height: 30),
                    const Divider(),
                    
                    const SizedBox(height: 10),
                    const Text("Toplu Ekleme Seçenekleri", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                    const SizedBox(height: 10),

                    // --- FİŞ TARA BUTONU (MENÜ AÇAR) ---
                    ElevatedButton.icon(
                      onPressed: _showImageSourceSheet, 
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text("Fiş Tara (Kamera / Galeri)"),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.lightGreen, 
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}