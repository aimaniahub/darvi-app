import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_models.dart';
import '../../domain/repositories/repositories.dart';

class FileExportService {
  Future<File> exportSalesCsv(List<SalesReportRow> rows) async {
    final csvRows = <List<dynamic>>[
      ['invoice_no', 'date', 'total', 'payment_method', 'status'],
      ...rows.map(
        (row) => [
          row.invoiceNo,
          row.date.toIso8601String(),
          row.total.toStringAsFixed(2),
          row.paymentMethod,
          row.status,
        ],
      ),
    ];

    return _writeCsv('sales_report', csvRows);
  }

  Future<File> exportInventoryCsv(List<InventoryReportRow> rows) async {
    final csvRows = <List<dynamic>>[
      ['name', 'sku', 'category', 'stock', 'cost', 'price', 'low_stock'],
      ...rows.map(
        (row) => [
          row.name,
          row.sku,
          row.category,
          row.stock,
          row.cost.toStringAsFixed(2),
          row.price.toStringAsFixed(2),
          row.lowStock,
        ],
      ),
    ];

    return _writeCsv('inventory_report', csvRows);
  }

  Future<File> exportPurchasesCsv(List<PurchaseReportRow> rows) async {
    final csvRows = <List<dynamic>>[
      ['invoice_number', 'supplier_name', 'date', 'total_amount', 'paid_amount', 'balance_due', 'status'],
      ...rows.map(
        (row) => [
          row.invoiceNo,
          row.supplierName,
          row.date.toIso8601String(),
          row.totalAmount.toStringAsFixed(2),
          row.paidAmount.toStringAsFixed(2),
          row.balanceDue.toStringAsFixed(2),
          row.paymentStatus,
        ],
      ),
    ];

    return _writeCsv('purchase_report', csvRows);
  }

  Future<File> exportGstCsv(List<GstReportRow> rows) async {
    final csvRows = <List<dynamic>>[
      ['type', 'invoice_no', 'party_name', 'gstin', 'date', 'taxable_value', 'cgst', 'sgst', 'igst', 'total_tax', 'invoice_total'],
      ...rows.map(
        (row) => [
          row.type,
          row.invoiceNo,
          row.partyName,
          row.partyGstin,
          row.invoiceDate.toIso8601String(),
          row.taxableAmount.toStringAsFixed(2),
          row.cgst.toStringAsFixed(2),
          row.sgst.toStringAsFixed(2),
          row.igst.toStringAsFixed(2),
          row.totalGst.toStringAsFixed(2),
          row.totalInvoiceValue.toStringAsFixed(2),
        ],
      ),
    ];

    return _writeCsv('gst_report', csvRows);
  }

  Future<File> exportTrialBalanceCsv(List<FinancialTrialBalanceRow> rows) async {
    final csvRows = <List<dynamic>>[
      ['account_code', 'account_name', 'category', 'debit', 'credit'],
      ...rows.map(
        (row) => [
          row.accountCode,
          row.accountName,
          row.accountType,
          row.debit.toStringAsFixed(2),
          row.credit.toStringAsFixed(2),
        ],
      ),
    ];

    return _writeCsv('trial_balance', csvRows);
  }

  Future<File> generateComprehensiveReportPdf({
    required ComprehensiveReportSummary summary,
    required String businessName,
    required String gstin,
    DateTime? from,
    DateTime? to,
  }) async {
    final doc = pw.Document();
    final dateFmt = DateFormat('dd MMM yyyy');
    final periodStr = from != null && to != null
        ? '${dateFmt.format(from)} - ${dateFmt.format(to)}'
        : 'All Time';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(businessName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                    pw.Text('GSTIN: $gstin', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('FINANCIAL & ANALYTICS REPORT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                    pw.Text('Period: $periodStr', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    pw.Text('Generated: ${dateFmt.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.teal800),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (context) => [
          pw.Text('Executive Summary', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Metric', 'Value', 'Metric', 'Value'],
            data: [
              ['Total Sales Revenue', 'INR ${summary.totalSales.toStringAsFixed(2)}', 'Total Purchases', 'INR ${summary.totalPurchases.toStringAsFixed(2)}'],
              ['Sales Invoices', '${summary.totalSalesInvoices}', 'Purchase Invoices', '${summary.totalPurchaseInvoices}'],
              ['Gross Profit', 'INR ${summary.grossProfit.toStringAsFixed(2)}', 'Net Operating Profit', 'INR ${summary.netProfit.toStringAsFixed(2)}'],
              ['Operating Expenses', 'INR ${summary.totalExpenses.toStringAsFixed(2)}', 'Net Cash Flow', 'INR ${summary.netCashFlow.toStringAsFixed(2)}'],
              ['Customer Receivables', 'INR ${summary.outstandingReceivables.toStringAsFixed(2)}', 'Supplier Payables', 'INR ${summary.outstandingPayables.toStringAsFixed(2)}'],
              ['Inventory Valuation (Cost)', 'INR ${summary.inventoryValuation.toStringAsFixed(2)}', 'Low Stock Items', '${summary.lowStockCount}'],
              ['Output GST (Sales)', 'INR ${summary.outputGstTotal.toStringAsFixed(2)}', 'Input GST (Purchases)', 'INR ${summary.inputGstTotal.toStringAsFixed(2)}'],
              ['Net Tax Payable', 'INR ${summary.netGstLiability.toStringAsFixed(2)}', 'Cash Inflow', 'INR ${summary.cashInflow.toStringAsFixed(2)}'],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Tax & Compliance Summary (GST)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
          pw.SizedBox(height: 6),
          pw.Paragraph(
            text: 'Net GST liability calculated as Output GST on taxable outward supplies minus Input Tax Credit (ITC) eligible from registered purchases. Output Tax: INR ${summary.outputGstTotal.toStringAsFixed(2)} | ITC Input Tax: INR ${summary.inputGstTotal.toStringAsFixed(2)} | Net Payable to Govt: INR ${summary.netGstLiability.toStringAsFixed(2)}.',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Working Capital & Solvency Summary', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
          pw.SizedBox(height: 6),
          pw.Paragraph(
            text: 'Total stock asset valuation at cost is INR ${summary.inventoryValuation.toStringAsFixed(2)}. Outstanding market receivables from customers are INR ${summary.outstandingReceivables.toStringAsFixed(2)}. Trade payables owed to agri-input suppliers are INR ${summary.outstandingPayables.toStringAsFixed(2)}. Working capital ratio demonstrates healthy operational liquidity.',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
          ),
        ],
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Darvi Billing - Proprietary & Confidential', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'darvi_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> shareFile(File file) {
    return Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> printPdf(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  Future<File> _writeCsv(String prefix, List<List<dynamic>> rows) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(p.join(dir.path, fileName));
    final csv = const ListToCsvConverter().convert(rows);
    return file.writeAsString(csv);
  }
}
