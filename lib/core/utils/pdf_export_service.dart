import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
// import '../models/shopping_item.dart'; // Artık modele gerek yok, map kullanıyoruz
import '../models/recipe.dart';

class PdfExportService {
  
  // Font yükleme
  Future<pw.Font> _getFont() async {
    return pw.Font.helvetica(); 
  }

  // --- 1. ALIŞVERİŞ LİSTESİ PDF'İ ---
  // GÜNCELLEME: items parametresi artık Map listesi
  Future<void> shareShoppingList(List<Map<String, dynamic>> items) async {
    final pdf = pw.Document();
    final font = await _getFont();
    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Mutfak Asistani", style: pw.TextStyle(font: font, fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Alisveris Listesi", style: pw.TextStyle(font: font, fontSize: 18)),
                ]
              )
            ),
            pw.SizedBox(height: 20),
            pw.Text("Tarih: ${now.day}.${now.month}.${now.year}", style: pw.TextStyle(font: font)),
            pw.Divider(),
            pw.SizedBox(height: 10),
            ...items.map((item) {
              // Map'ten verileri alıyoruz
              final name = item['name'] as String;
              final isCompleted = item['isCompleted'] == true;

              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 10, height: 10,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(),
                        color: isCompleted ? PdfColors.grey300 : null
                      )
                    ),
                    pw.SizedBox(width: 10),
                    pw.Text(
                      name, 
                      style: pw.TextStyle(
                        font: font, 
                        fontSize: 14,
                        decoration: isCompleted ? pw.TextDecoration.lineThrough : null
                      )
                    ),
                  ]
                )
              );
            }),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text("Mutfak Asistani ile olusturulmustur.", style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey))
            )
          ];
        },
      ),
    );
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'alisveris_listesi.pdf');
  }

  // --- 2. TARİF PDF'İ (DEĞİŞMEDİ) ---
  Future<void> shareRecipe(Recipe recipe) async {
    final pdf = pw.Document();
    final font = await _getFont();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text("Mutfak Asistani - Ozel Tarif", style: pw.TextStyle(font: font, fontSize: 20, color: PdfColors.grey))
            ),
            pw.SizedBox(height: 20),
            pw.Text(recipe.name, style: pw.TextStyle(font: font, fontSize: 26, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("${recipe.category} | ${recipe.difficulty}", style: pw.TextStyle(font: font)),
                pw.Text("Sure: ${recipe.prepTime} dk", style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
              ]
            ),
            pw.Divider(),
            
            // Besin Değerleri
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfMacroItem(font, "Kalori", recipe.calories),
                  _buildPdfMacroItem(font, "Protein", recipe.protein),
                  _buildPdfMacroItem(font, "Karb.", recipe.carbs),
                  _buildPdfMacroItem(font, "Yag", recipe.fat),
                ]
              )
            ),
            pw.SizedBox(height: 20),

            pw.Text("Malzemeler", style: pw.TextStyle(font: font, fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            ...recipe.ingredients.map((e) => pw.Bullet(text: e, style: pw.TextStyle(font: font))),
            
            pw.SizedBox(height: 20),
            pw.Text("Yapilisi", style: pw.TextStyle(font: font, fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text(recipe.instructions, style: pw.TextStyle(font: font, height: 1.5)),

            pw.Spacer(),
            pw.Divider(),
            pw.Center(child: pw.Text("Afiyet Olsun! - Mutfak Asistani", style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey))),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: '${recipe.name}.pdf');
  }

  pw.Widget _buildPdfMacroItem(pw.Font font, String label, String value) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
      ]
    );
  }
}