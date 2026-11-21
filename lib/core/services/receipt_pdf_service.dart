import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/app_entities.dart';
import '../../domain/repositories/repositories.dart';
import 'esc_pos_generator.dart';
import 'thermal_printer_service.dart';

class ReceiptPdfService {
  ReceiptPdfService({
    required PrinterService printerService,
    ThermalPrinterService? thermalPrinterService,
  })  : _printerService = printerService,
        _thermalPrinterService = thermalPrinterService ?? ThermalPrinterService();

  final PrinterService _printerService;
  final ThermalPrinterService _thermalPrinterService;

  ThermalPrinterService get thermalPrinterService => _thermalPrinterService;

  /// Generates a PDF receipt for fallback / standard printing or sharing
  Future<File> generateReceipt({
    required SaleView sale,
    required List<SaleItemView> items,
    required String storeName,
    required String header,
    required String footer,
    required String currency,
    ReceiptPaperWidth paperWidth = ReceiptPaperWidth.mm58,
  }) async {
    final bytes = await generateReceiptBytes(
      sale: sale,
      items: items,
      storeName: storeName,
      header: header,
      footer: footer,
      currency: currency,
      paperWidth: paperWidth,
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, '${sale.invoiceNo}.pdf'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Generates Uint8List PDF bytes formatted for roll printers (58mm or 80mm) or A4
  Future<Uint8List> generateReceiptBytes({
    required SaleView sale,
    required List<SaleItemView> items,
    required String storeName,
    required String header,
    required String footer,
    required String currency,
    ReceiptPaperWidth paperWidth = ReceiptPaperWidth.mm58,
  }) async {
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/darvi_logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final PdfPageFormat format;
    switch (paperWidth) {
      case ReceiptPaperWidth.mm80:
        format = PdfPageFormat.roll80;
        break;
      case ReceiptPaperWidth.a4:
        format = PdfPageFormat.a4;
        break;
      case ReceiptPaperWidth.mm58:
        format = const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm);
        break;
    }

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoImage != null) ...[
                pw.Center(child: pw.Image(logoImage, height: 32)),
                pw.SizedBox(height: 4),
              ],
              pw.Center(
                child: pw.Text(
                  storeName,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ),
              if (header.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Center(child: pw.Text(header, style: const pw.TextStyle(fontSize: 9))),
              ],
              pw.SizedBox(height: 6),
              pw.Text('Invoice: ${sale.invoiceNo}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Date: ${sale.createdAt.day.toString().padLeft(2, '0')}/${sale.createdAt.month.toString().padLeft(2, '0')}/${sale.createdAt.year}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Pay Mode: ${sale.paymentMethod.name.toUpperCase()}', style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(thickness: 0.5),
              ...items.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text('${item.nameSnapshot} x${item.qty}', style: const pw.TextStyle(fontSize: 9)),
                      ),
                      pw.Text('${item.lineTotal.toStringAsFixed(2)} $currency', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ),
              pw.Divider(thickness: 0.5),
              _buildRow('Subtotal', '${sale.subtotal.toStringAsFixed(2)} $currency'),
              if (sale.discountTotal > 0)
                _buildRow('Discount', '-${sale.discountTotal.toStringAsFixed(2)} $currency'),
              if (sale.taxTotal > 0)
                _buildRow('Tax', '${sale.taxTotal.toStringAsFixed(2)} $currency'),
              pw.Divider(thickness: 0.8),
              _buildRow('TOTAL', '${sale.total.toStringAsFixed(2)} $currency', isBold: true, fontSize: 11),
              _buildRow('Paid', '${sale.paid.toStringAsFixed(2)} $currency'),
              if (sale.changeAmount > 0)
                _buildRow('Change', '${sale.changeAmount.toStringAsFixed(2)} $currency'),
              finalDue(sale, currency),
              pw.SizedBox(height: 8),
              if (footer.isNotEmpty)
                pw.Center(child: pw.Text(footer, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text('Thank You! Visit Again.', style: const pw.TextStyle(fontSize: 8))),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _buildRow(String label, String value, {bool isBold = false, double fontSize = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  pw.Widget finalDue(SaleView sale, String currency) {
    final due = sale.total - sale.paid;
    if (due <= 0) return pw.SizedBox();
    return _buildRow('Balance Due', '${due.toStringAsFixed(2)} $currency', isBold: true);
  }

  /// Print directly through OS System Spooler / Print Service (Universal on any device)
  Future<bool> printThermalViaSystemSpooler({
    required SaleView sale,
    required List<SaleItemView> items,
    required String storeName,
    required String header,
    required String footer,
    required String currency,
    ReceiptPaperWidth paperWidth = ReceiptPaperWidth.mm58,
  }) async {
    final pdfBytes = await generateReceiptBytes(
      sale: sale,
      items: items,
      storeName: storeName,
      header: header,
      footer: footer,
      currency: currency,
      paperWidth: paperWidth,
    );

    return Printing.layoutPdf(
      name: 'Receipt_${sale.invoiceNo}',
      onLayout: (format) async => pdfBytes,
    );
  }

  /// Print to hardware thermal printer via ESC/POS command stream (Bluetooth or Clenter App)
  Future<bool> printThermalReceipt({
    required SaleView sale,
    required List<SaleItemView> items,
    required String businessName,
    required String gstin,
    required String address,
    required String phone,
    required String receiptSlogan,
    required String receiptTerms,
    String? customerName,
    double cgst = 0.0,
    double sgst = 0.0,
    double igst = 0.0,
    double roundOff = 0.0,
    ReceiptPaperWidth paperWidth = ReceiptPaperWidth.mm58,
  }) async {
    final int width = paperWidth == ReceiptPaperWidth.mm80 ? 48 : 32;
    final Uint8List receiptBytes = EscPosGenerator.buildDarviReceipt(
      sale: sale,
      items: items,
      businessName: businessName,
      gstin: gstin,
      address: address,
      phone: phone,
      receiptSlogan: receiptSlogan,
      receiptTerms: receiptTerms,
      customerName: customerName,
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      roundOff: roundOff,
      width: width,
    );

    if (_thermalPrinterService.isClenterConnected) {
      return _thermalPrinterService.sendBytesToClenter(receiptBytes);
    }

    if (_thermalPrinterService.status == BluetoothPrinterStatus.connected) {
      return _thermalPrinterService.sendBytes(receiptBytes);
    }

    // If neither is directly connected, fallback to Clenter attempt
    final clenterSuccess = await _thermalPrinterService.sendBytesToClenter(receiptBytes);
    if (clenterSuccess) return true;

    return false;
  }

  /// Run hardware self-test diagnostic print
  Future<bool> printDiagnosticSelfTest({ReceiptPaperWidth paperWidth = ReceiptPaperWidth.mm58}) async {
    final int width = paperWidth == ReceiptPaperWidth.mm80 ? 48 : 32;
    final Uint8List testBytes = EscPosGenerator.buildDiagnosticTestPrint(width: width);

    if (_thermalPrinterService.isClenterConnected) {
      return _thermalPrinterService.sendBytesToClenter(testBytes);
    }
    return _thermalPrinterService.sendBytes(testBytes);
  }

  Future<void> sharePdf(File file) {
    return Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> printPdf(File file) {
    return Printing.layoutPdf(onLayout: (_) => file.readAsBytes());
  }

  Future<void> printThroughStub(File file) async {
    final bytes = await file.readAsBytes();
    await _printerService.printReceiptPdfBytes(bytes);
  }
}
