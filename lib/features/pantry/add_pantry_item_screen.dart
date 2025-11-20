import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:intl/intl.dart'; 

import '../../core/models/ingredient.dart';
import '../../core/models/pantry_item.dart';
import 'pantry_service.dart';
import '../ocr/ocr_service.dart'; // OCR Servisi

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

  // Malzeme arama
  void _searchIngredients(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    final results = await _pantryService.searchIngredients(query);
    setState(() {
      _searchResults = results;
    });
  }

  // Tarih seçici
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpirationDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedExpirationDate) {
      setState(() {
        _selectedExpirationDate = picked;
      });
    }
  }

  // Kiler'e ürün ekleme
  Future<void> _addItemToPantry() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedIngredient == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lütfen bir malzeme seçin.")),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) throw Exception("Kullanıcı oturumu açmamış.");

        final newItem = PantryItem(
          id: '', 
          userId: currentUser.uid,
          ingredientId: _selectedIngredient!.id,
          ingredientName: _selectedIngredient!.name,
          quantity: double.parse(_quantityController.text),
          unit: _selectedIngredient!.unit, 
          expirationDate: _selectedExpirationDate,
          createdAt: Timestamp.now(),
        );

        await _pantryService.addPantryItem(newItem);

        if (!context.mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ürün kiler'e başarıyla eklendi!")),
        );
        Navigator.of(context).pop(); 

      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: ${e.toString()}")),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // --- YENİ: LİSTE GÖSTERME PENCERESİ (Ortak Kullanım İçin) ---
  void _showSelectionDialog(List<String> items) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Algılanan Ürünler"),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: items.isEmpty 
              ? const Center(child: Text("Liste boş."))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(items[index], style: const TextStyle(fontWeight: FontWeight.bold)),
                        leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                        onTap: () {
                          _ingredientNameController.text = items[index];
                          _searchIngredients(items[index]);
                          Navigator.pop(context); 
                        },
                      ),
                    );
                  },
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Kapat"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ürün Ekle")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _ingredientNameController,
                      decoration: InputDecoration(
                        labelText: "Malzeme Adı",
                        hintText: "Örn: Domates, Un",
                        border: const OutlineInputBorder(),
                        suffixIcon: _selectedIngredient != null
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
                        if (_selectedIngredient == null || _selectedIngredient!.name != value) {
                           return "Lütfen listeden bir malzeme seçin.";
                        }
                        return null;
                      },
                    ),
                    
                    if (_searchResults.isNotEmpty && _selectedIngredient == null)
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final ingredient = _searchResults[index];
                            return ListTile(
                              title: Text(ingredient.name),
                              subtitle: Text("${ingredient.category} (${ingredient.unit})"),
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
                              final newIngredient = Ingredient(
                                id: '', 
                                name: newIngredientName, 
                                category: 'Diğer', 
                                unit: 'adet'
                              );
                              await _pantryService.addIngredientToSystem(newIngredient);
                              if (!context.mounted) return;
                              setState(() {
                                _selectedIngredient = newIngredient; 
                                _searchResults = []; 
                              });
                               ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Yeni malzeme eklendi.")),
                              );
                            }
                          },
                          icon: const Icon(Icons.add_box),
                          label: Text("Yeni Malzeme Ekle: '${_ingredientNameController.text}'"),
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Miktar (${_selectedIngredient?.unit ?? 'adet'})",
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return "Lütfen miktarı girin.";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(
                        _selectedExpirationDate == null
                            ? "Son Kullanma Tarihi Seç"
                            : "Son Kullanma Tarihi: ${DateFormat('dd/MM/yyyy').format(_selectedExpirationDate!)}",
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectDate(context),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _addItemToPantry,
                      icon: const Icon(Icons.save),
                      label: const Text("Kilerime Ekle"),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    
                    // --- MAVİ BUTON: SON TARAMAYI GÖSTER ---
                    if (OCRService.lastScannedList.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Hafızadaki listeyi aç
                            _showSelectionDialog(OCRService.lastScannedList);
                          }, 
                          icon: const Icon(Icons.history),
                          label: const Text("📋 Son Taranan Listeyi Aç"),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.blue.shade100,
                            foregroundColor: Colors.blue.shade900,
                          ),
                        ),
                      ),

                    // --- YEŞİL BUTON: YENİ FİŞ TARA ---
                    ElevatedButton.icon(
                      onPressed: () async {
                        final imagePath = await _ocrService.pickImageFromCamera();
                        
                        if (imagePath != null && context.mounted) {
                          showDialog(
                            context: context,
                            barrierDismissible: false, 
                            builder: (_) => const Dialog(
                              backgroundColor: Colors.white,
                              child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min, 
                                  children: [
                                    CircularProgressIndicator(color: Colors.orange),
                                    SizedBox(height: 20),
                                    Text("Yapay Zeka Fişi Okuyor...", style: TextStyle(fontWeight: FontWeight.bold)),
                                    SizedBox(height: 8),
                                    Text("Lütfen bekleyin...", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          );

                          try {
                            final lines = await _ocrService.textToIngredients(imagePath);

                            if (context.mounted) Navigator.of(context).pop(); 
                            if (!context.mounted) return;

                            // Yeni listeyi göster
                            _showSelectionDialog(lines);

                          } catch (e) {
                            if (context.mounted) Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Hata: $e")),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Yeni Fiş Tara"),
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