import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; 

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
  final _quantityController = TextEditingController();
  final _ingredientNameController = TextEditingController();
  DateTime? _selectedExpirationDate;

  List<Ingredient> _searchResults = [];
  Ingredient? _selectedIngredient;

  final PantryService _pantryService = PantryService();
  final OCRService _ocrService = OCRService();
  final BarcodeService _barcodeService = BarcodeService(); 
  
  bool _isLoading = false;

  Future<void> _scanBarcode() async {
    final String? scannedCode = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text("Barkodu Okut"), backgroundColor: Colors.black),
          body: MobileScanner(
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.noDuplicates,
              returnImage: false,
            ),
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                Navigator.pop(context, barcodes.first.rawValue);
              }
            },
          ),
        ),
      ),
    );

    if (scannedCode != null) {
      setState(() => _isLoading = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ürün aranıyor...")));
      
      final productName = await _barcodeService.findProduct(scannedCode);
      setState(() => _isLoading = false);

      if (productName != null && productName.isNotEmpty) {
        setState(() {
           _ingredientNameController.text = productName;
        });
        _searchIngredients(productName); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bulundu: $productName"), backgroundColor: Colors.green));
      } else {
        _showAddProductDialog(scannedCode);
      }
    }
  }

  void _showAddProductDialog(String barcode) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ürün Bulunamadı 😔"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Bu ürünü veritabanımızda ilk gören sensin!"),
            const SizedBox(height: 8),
            const Text("Adını yazıp kaydedersen, bu barkod veritabanımıza eklenecek.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: "Örn: Eti Burçak",
                labelText: "Ürün Adı Giriniz",
                border: OutlineInputBorder()
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await _barcodeService.contributeToPool(barcode, name);
                
                setState(() {
                  _ingredientNameController.text = name;
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Harika! Ürün veritabanımıza kaydedildi."),
                      backgroundColor: Colors.green,
                    )
                  );
                }
              }
            },
            child: const Text("Kaydet ve Paylaş"),
          ),
        ],
      ),
    );
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
    // KLAVYEYİ KAPAT (UX İyileştirmesi)
    FocusScope.of(context).unfocus(); 

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
                onTap: () { Navigator.pop(context); _processImage(ImageSource.camera); },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.purple),
                title: const Text("Galeri"),
                onTap: () { Navigator.pop(context); _processImage(ImageSource.gallery); },
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
                            onPressed: _scanBarcode,
                            icon: const Icon(Icons.qr_code_2),
                            label: const Text("Barkod"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade100,
                              foregroundColor: Colors.blue.shade900,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

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
                      validator: (value) => value!.isEmpty ? "Lütfen malzeme adını girin." : null,
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
                      validator: (value) => value!.isEmpty ? "Lütfen miktarı girin." : null,
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
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                  ],
                ),
              ),
            ),
      )
    );
  }
}