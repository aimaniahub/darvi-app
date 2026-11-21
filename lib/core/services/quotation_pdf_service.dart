import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/local/db/app_database.dart';
import '../../data/local/seed/seed_data.dart';

class QuotationPdfService {
  Future<Uint8List> buildPdfBytes({
    required Quotation quotation,
    required List<QuotationItem> items,
  }) async {
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/darvi_logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (logoImage != null) pw.Image(logoImage, height: 42),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        DarviCorporateInfo.businessName,
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'GSTIN: ${DarviCorporateInfo.gstin}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        DarviCorporateInfo.address,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        'Phone: ${DarviCorporateInfo.phone}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green700,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text(
                          'FORMAL QUOTATION',
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Quote #: ${quotation.quotationNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text('Date: ${quotation.quotationDate.toLocal().toString().substring(0, 10)}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Valid Until: ${quotation.validUntil.toLocal().toString().substring(0, 10)}', style: pw.TextStyle(fontSize: 10, color: PdfColors.red800)),
                      pw.Text('Status: ${quotation.status.toUpperCase()}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1, height: 24),

              // Client details
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('QUOTATION ISSUED TO:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                          pw.SizedBox(height: 4),
                          pw.Text(quotation.customerName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Phone: ${quotation.customerPhone}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Items Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3.5),
                  1: const pw.FlexColumnWidth(1.0),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.0),
                  4: const pw.FlexColumnWidth(1.0),
                  5: const pw.FlexColumnWidth(1.8),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _pCell('Item Description', isHeader: true),
                      _pCell('Qty', isHeader: true, align: pw.TextAlign.center),
                      _pCell('Rate (INR)', isHeader: true, align: pw.TextAlign.right),
                      _pCell('Disc', isHeader: true, align: pw.TextAlign.right),
                      _pCell('GST %', isHeader: true, align: pw.TextAlign.center),
                      _pCell('Total (INR)', isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),
                  ...items.map((item) {
                    return pw.TableRow(
                      children: [
                        _pCell('${item.description} (${item.itemType.toUpperCase()})'),
                        _pCell(item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2), align: pw.TextAlign.center),
                        _pCell(item.unitPrice.toStringAsFixed(2), align: pw.TextAlign.right),
                        _pCell(item.discount > 0 ? item.discount.toStringAsFixed(2) : '-', align: pw.TextAlign.right),
                        _pCell('${item.gstRate.toStringAsFixed(0)}%', align: pw.TextAlign.center),
                        _pCell(item.total.toStringAsFixed(2), align: pw.TextAlign.right),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 16),

              // Summary
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TERMS & CONDITIONS:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          quotation.terms ??
                              '1. Rates valid up to the validity date stated above.\n2. Subject to plot/product availability at the time of confirmation.\n3. Payment to be made via bank transfer or approved channel.\n4. All disputes subject to Hubli jurisdiction.',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      children: [
                        _summaryRow('Subtotal', quotation.subtotal),
                        if (quotation.discountTotal > 0) _summaryRow('Discount', -quotation.discountTotal),
                        if (quotation.cgstTotal > 0) _summaryRow('CGST', quotation.cgstTotal),
                        if (quotation.sgstTotal > 0) _summaryRow('SGST', quotation.sgstTotal),
                        if (quotation.igstTotal > 0) _summaryRow('IGST', quotation.igstTotal),
                        pw.Divider(thickness: 1),
                        _summaryRow('Grand Total (INR)', quotation.totalAmount, isBold: true, fontSize: 13),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Customer Acceptance Signature:', style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 35),
                      pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('For Darvi Group Agri Tech:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 35),
                      pw.Container(width: 150, height: 1, color: PdfColors.grey400),
                      pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _pCell(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 9, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  static pw.Widget _summaryRow(String label, double amount, {bool isBold = false, double fontSize = 10}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text('Rs. ${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  Future<void> shareQuotation({required Quotation quotation, required List<QuotationItem> items}) async {
    final bytes = await buildPdfBytes(quotation: quotation, items: items);
    final output = await getTemporaryDirectory();
    final file = File(p.join(output.path, '${quotation.quotationNumber}.pdf'));
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Quotation ${quotation.quotationNumber} from Darvi Group Agri Tech');
  }

  Future<void> printQuotation({required Quotation quotation, required List<QuotationItem> items}) async {
    final bytes = await buildPdfBytes(quotation: quotation, items: items);
    await Printing.layoutPdf(onLayout: (format) async => bytes);
  }
}

