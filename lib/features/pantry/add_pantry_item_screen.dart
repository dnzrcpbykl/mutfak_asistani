import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/models/ingredient.dart';
import '../../core/models/pantry_item.dart';
import 'pantry_service.dart';
import 'barcode_service.dart'; 
import '../ocr/ocr_service.dart';
import '../ocr/scanned_products_screen.dart';

class AddPantryItemScreen extends StatefulWidget {
  const AddPantryItemScreen({super.key});
  @override
  State<AddPantryItemScreen> createState() => _AddPantryItemScreenState();
}

class _AddPantryItemScreenState extends State<AddPantryItemScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Kontrolcüler
  final _ingredientNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _pieceCountController = TextEditingController(text: "1"); // Varsayılan 1 Paket
  final _priceController = TextEditingController(); // Fiyat için yeni kontrolcü

  // Değişkenler
  DateTime? _selectedExpirationDate;
  String _selectedUnit = 'adet'; // Varsayılan birim
  
  // Standart Birim Listesi
  final List<String> _unitList = [
    'adet', 'kg', 'gr', 'lt', 'ml', 'paket', 'kavanoz', 'bardak', 'demet', 'dilim', 'kaşık', 'kutu'
  ];

  List<Ingredient> _searchResults = [];
  Ingredient? _selectedIngredient;

  final PantryService _pantryService = PantryService();
  final OCRService _ocrService = OCRService();
  // ignore: unused_field
  final BarcodeService _barcodeService = BarcodeService(); 
  
  bool _isLoading = false;

  @override
  void dispose() {
    _ingredientNameController.dispose();
    _quantityController.dispose();
    _pieceCountController.dispose();
    _priceController.dispose();
    super.dispose();
  }

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
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      String ingredientId = _selectedIngredient?.id ?? '';
      String ingredientName = _ingredientNameController.text.trim();
      String unit = _selectedUnit; 

      if (ingredientName.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir malzeme ismi girin.")));
         return;
      }

      setState(() => _isLoading = true);
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) throw Exception("Kullanıcı oturumu açmamış.");

        String category = _selectedIngredient?.category ?? 'Diğer';
        
        // Sayısal Dönüşümler
        double quantity = double.parse(_quantityController.text.replaceAll(',', '.'));
        int pieces = int.tryParse(_pieceCountController.text) ?? 1;
        double price = 0.0;
        
        if (_priceController.text.isNotEmpty) {
          price = double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0.0;
        }

        final newItem = PantryItem(
          id: '',
          userId: currentUser.uid,
          ingredientId: ingredientId,
          ingredientName: ingredientName,
          quantity: quantity,
          unit: unit,
          expirationDate: _selectedExpirationDate,
          createdAt: Timestamp.now(),
          category: category,
          pieceCount: pieces, // Girilen paket sayısı
          price: price, // Girilen fiyat (Harcamalara yansıyacak)
        );

        await _pantryService.addPantryItem(newItem);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ürün kaydedildi ve harcamalara eklendi! ✅"), 
            backgroundColor: Colors.green
          )
        );
        Navigator.of(context).pop();

      } catch (e) {
        if (mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: ${e.toString()}")));
      } finally {
        if (context.mounted) setState(() => _isLoading = false);
      }
    }
  }

  // --- Resim Kaynağı Seçimi (Kamera/Galeri) ---
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
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text("Kamera"),
                onTap: () { 
                  Navigator.pop(context); 
                  _processImage(ImageSource.camera); 
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.purple),
                title: const Text("Galeri"),
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

  Future<void> _processImage(ImageSource source) async {
    final imagePath = await _ocrService.pickImage(source);
    if (imagePath != null && mounted) {
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
              ],
            ),
          ),
        ),
      );
      try {
        final scannedData = await _ocrService.textToIngredients(imagePath);
        if (mounted) Navigator.of(context).pop();
        if (!mounted) return;
        if (scannedData.isNotEmpty && scannedData['items'] != null && (scannedData['items'] as List).isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ScannedProductsScreen(scannedData: scannedData),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text("Gıda ürünü bulunamadı."), backgroundColor: Theme.of(context).colorScheme.error),
          );
        }
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Ürün Ekle")),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // --- ÜST BUTONLAR ---
                    Row(
                      children: [
                          Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _showImageSourceSheet,
                            icon: const Icon(Icons.receipt_long),
                            label: const Text("Fiş Tara"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade100,
                              foregroundColor: Colors.purple.shade900,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Türkiye barkod altyapısı hazırlanıyor. Çok yakında! 🚧"),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 2),
                                )
                              );
                            },
                            icon: const Icon(Icons.qr_code_2),
                            label: const Text("Barkod"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade300, 
                              foregroundColor: Colors.grey.shade700, 
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // --- İSİM GİRİŞİ ---
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
                                    _selectedUnit = 'adet';
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: _searchIngredients,
                      validator: (value) => value!.isEmpty ? "Lütfen malzeme adını girin." : null,
                    ),

                    // Arama Sonuçları Listesi
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
                              subtitle: Text("${ingredient.category} (${ingredient.unit})", style: TextStyle(color: colorScheme.onSurface.withAlpha((0.6 * 255).round()))),
                              onTap: () {
                                setState(() {
                                  _selectedIngredient = ingredient;
                                  _ingredientNameController.text = ingredient.name;
                                  _searchResults = [];
                                  
                                  if (_unitList.contains(ingredient.unit)) {
                                    _selectedUnit = ingredient.unit;
                                  } else {
                                    _selectedUnit = 'adet';
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    
                    // Yeni Malzeme Ekle Butonu
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

                    // --- SATIR 1: MİKTAR VE BİRİM ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // MİKTAR
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _quantityController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: colorScheme.onSurface),
                            decoration: const InputDecoration(
                              labelText: "Miktar",
                              hintText: "1.5",
                              prefixIcon: Icon(Icons.numbers),
                            ),
                            validator: (value) => value!.isEmpty ? "Giriniz" : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // BİRİM
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedUnit,
                            decoration: const InputDecoration(
                              labelText: "Birim",
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                              border: OutlineInputBorder(),
                            ),
                            items: _unitList.map((String unit) {
                              return DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedUnit = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // --- SATIR 2: PAKET SAYISI VE FİYAT (YENİ) ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PAKET SAYISI
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _pieceCountController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: colorScheme.onSurface),
                            decoration: const InputDecoration(
                              labelText: "Paket Sayısı",
                              hintText: "1",
                              prefixIcon: Icon(Icons.layers),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // FİYAT
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: colorScheme.onSurface),
                            decoration: const InputDecoration(
                              labelText: "Fiyat (TL)",
                              hintText: "0.0",
                              prefixIcon: Icon(Icons.currency_lira),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                
                    // TARİH SEÇİMİ
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
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                  ],
                ),
              ),
            ),
      )
    );
  }
}