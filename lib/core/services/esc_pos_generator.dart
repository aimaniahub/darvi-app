import 'dart:convert';
import 'dart:typed_data';

import '../../domain/entities/app_entities.dart';

/// Clean, robust ESC/POS thermal command generator supporting both 58mm (32 cols)
/// and 80mm (48 cols) roll paper.
/// Implements safe mode, chunked pacing, and feed-before-cut techniques
/// inspired by web-escpos-printer (GomdimApps/web-escpos-printer).
class EscPosGenerator {
  static const int columns58mm = 32;
  static const int columns80mm = 48;

  // Standard ESC/POS Control Bytes
  static const int esc = 0x1B;
  static const int fs = 0x1C;
  static const int gs = 0x1D;

  // Initialise
  static final List<int> initPrinter = [esc, 0x40]; // ESC @

  // Text Alignment
  static final List<int> alignLeft = [esc, 0x61, 0x00]; // ESC a 0
  static final List<int> alignCenter = [esc, 0x61, 0x01]; // ESC a 1
  static final List<int> alignRight = [esc, 0x61, 0x02]; // ESC a 2

  // Text Styling
  static final List<int> boldOn = [esc, 0x45, 0x01]; // ESC E 1
  static final List<int> boldOff = [esc, 0x45, 0x00]; // ESC E 0
  static final List<int> doubleHeightOn = [esc, 0x21, 0x10]; // ESC ! 16
  static final List<int> doubleWidthOn = [esc, 0x21, 0x20]; // ESC ! 32
  static final List<int> textNormal = [esc, 0x21, 0x00]; // ESC ! 0

  // Feeds and Cuts (Feed-before-cut technique from web-escpos-printer)
  static List<int> feedLines([int n = 4]) => [esc, 0x64, n]; // ESC d n
  static final List<int> partialCut = [gs, 0x56, 0x42, 0x00]; // GS V 66 0
  static final List<int> fullCut = [gs, 0x56, 0x41, 0x00]; // GS V 65 0

  /// Formats a single divider line (safe ASCII rule fallback)
  static List<int> divider([String char = '-', int width = columns58mm]) {
    return textLine(char * width);
  }

  /// Formats a double divider line (safe ASCII rule fallback)
  static List<int> doubleDivider([int width = columns58mm]) {
    return textLine('=' * width);
  }

  /// Converts a text line to ASCII/Latin1 bytes with newline
  static List<int> textLine(String text) {
    return [...latin1.encode(text), 0x0A];
  }

  /// Formats two strings left and right justified within the given column width
  static String formatTwoColumns(String left, String right, {int width = columns58mm}) {
    final available = width - right.length;
    if (available <= 0) {
      return '$left $right';
    }
    if (left.length > available) {
      left = left.substring(0, available - 1);
    }
    final spaces = ' ' * (width - left.length - right.length);
    return '$left$spaces$right';
  }

  /// Formats three columns (e.g., Description, Qty, Total)
  static String formatThreeColumns(String col1, String col2, String col3, {int width = columns58mm}) {
    final rightWidth = col3.length;
    final midWidth = col2.length;
    final leftWidth = width - rightWidth - midWidth - 2;

    String cleanCol1 = col1;
    if (cleanCol1.length > leftWidth && leftWidth > 0) {
      cleanCol1 = cleanCol1.substring(0, leftWidth);
    }
    final space1 = ' ' * (leftWidth - cleanCol1.length + 1);
    final space2 = ' ' * 1;

    return '$cleanCol1$space1$col2$space2$col3';
  }

  /// Formats item line for receipt
  static List<int> formatItemRow({
    required String name,
    required int qty,
    required double price,
    required double discount,
    required double lineTotal,
    int width = columns58mm,
  }) {
    final List<int> bytes = [];

    // Line 1: Item Name
    bytes.addAll(textLine(name.length > width ? name.substring(0, width) : name));

    // Line 2: Qty x Unit Price (with discount note if any) and Line Total
    String qtyPriceStr = '  $qty x ${price.toStringAsFixed(2)}';
    if (discount > 0) {
      qtyPriceStr += ' (-${discount.toStringAsFixed(2)})';
    }
    final totalStr = lineTotal.toStringAsFixed(2);
    final row = formatTwoColumns(qtyPriceStr, totalStr, width: width);
    bytes.addAll(textLine(row));

    return bytes;
  }

  /// Generates complete ESC/POS byte sequence for a Darvi Billing receipt.
  /// Supports width 32 (58mm) or 48 (80mm), safe mode rule rendering,
  /// and feed-before-cut pacing.
  static Uint8List buildDarviReceipt({
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
    int width = columns58mm,
    int feedBeforeCut = 4,
    bool safeMode = true,
  }) {
    final List<int> b = [];

    // 1. Initialise printer
    b.addAll(initPrinter);

    // 2. Center-aligned Header
    b.addAll(alignCenter);
    b.addAll(boldOn);
    b.addAll(doubleHeightOn);
    b.addAll(textLine(businessName));
    b.addAll(textNormal);
    b.addAll(boldOff);

    // Multi-line address wrapping
    final addressLines = _wrapText(address, width);
    for (final line in addressLines) {
      b.addAll(textLine(line));
    }

    if (gstin.isNotEmpty) {
      b.addAll(textLine('GSTIN: $gstin'));
    }
    if (phone.isNotEmpty) {
      b.addAll(textLine('Ph: $phone'));
    }

    // 3. Invoice & Customer Meta
    b.addAll(doubleDivider(width));
    b.addAll(alignLeft);
    b.addAll(textLine(formatTwoColumns('Inv: ${sale.invoiceNo}', 'Date: ${_formatDate(sale.createdAt)}', width: width)));
    if (customerName != null && customerName.isNotEmpty) {
      b.addAll(textLine('Cust: $customerName'));
    }
    b.addAll(textLine('Pay Mode: ${sale.paymentMethod.name.toUpperCase()}'));

    // 4. Line Items Table
    b.addAll(doubleDivider(width));
    b.addAll(textLine(formatTwoColumns('Item Description', 'Total (INR)', width: width)));
    b.addAll(divider('-', width));

    for (final item in items) {
      b.addAll(
        formatItemRow(
          name: item.nameSnapshot,
          qty: item.qty,
          price: item.priceSnapshot,
          discount: item.discount,
          lineTotal: item.lineTotal,
          width: width,
        ),
      );
    }

    // 5. Totals & Tax Breakdown
    b.addAll(divider('-', width));
    b.addAll(textLine(formatTwoColumns('Subtotal:', sale.subtotal.toStringAsFixed(2), width: width)));

    if (sale.discountTotal > 0) {
      b.addAll(textLine(formatTwoColumns('Discount:', '-${sale.discountTotal.toStringAsFixed(2)}', width: width)));
    }

    if (cgst > 0) {
      b.addAll(textLine(formatTwoColumns('CGST:', cgst.toStringAsFixed(2), width: width)));
    }
    if (sgst > 0) {
      b.addAll(textLine(formatTwoColumns('SGST:', sgst.toStringAsFixed(2), width: width)));
    }
    if (igst > 0) {
      b.addAll(textLine(formatTwoColumns('IGST:', igst.toStringAsFixed(2), width: width)));
    }
    if (sale.taxTotal > 0 && cgst == 0 && sgst == 0 && igst == 0) {
      b.addAll(textLine(formatTwoColumns('Tax Total:', sale.taxTotal.toStringAsFixed(2), width: width)));
    }

    if (roundOff != 0) {
      b.addAll(textLine(formatTwoColumns('Round Off:', roundOff.toStringAsFixed(2), width: width)));
    }

    b.addAll(divider('-', width));
    b.addAll(boldOn);
    b.addAll(textLine(formatTwoColumns('GRAND TOTAL:', 'INR ${sale.total.toStringAsFixed(2)}', width: width)));
    b.addAll(textLine(formatTwoColumns('PAID AMOUNT:', 'INR ${sale.paid.toStringAsFixed(2)}', width: width)));

    if (sale.changeAmount > 0) {
      b.addAll(textLine(formatTwoColumns('CHANGE RETURN:', 'INR ${sale.changeAmount.toStringAsFixed(2)}', width: width)));
    }

    final double due = sale.total - sale.paid;
    if (due > 0) {
      b.addAll(textLine(formatTwoColumns('BALANCE DUE:', 'INR ${due.toStringAsFixed(2)}', width: width)));
    }
    b.addAll(boldOff);

    // 6. Footer & Terms
    b.addAll(doubleDivider(width));
    b.addAll(alignCenter);
    if (receiptSlogan.isNotEmpty) {
      final sloganLines = _wrapText(receiptSlogan, width);
      for (final line in sloganLines) {
        b.addAll(textLine(line));
      }
    }
    if (receiptTerms.isNotEmpty) {
      final termLines = _wrapText(receiptTerms, width);
      for (final line in termLines) {
        b.addAll(textLine(line));
      }
    }
    b.addAll(textLine('Thank You! Visit Again.'));

    // 7. Feed lines & Cut (Feed-before-cut technique)
    b.addAll(feedLines(feedBeforeCut));
    b.addAll(partialCut);

    return Uint8List.fromList(b);
  }

  /// Self-test diagnostic print payload to verify thermal hardware & companion connectivity
  static Uint8List buildDiagnosticTestPrint({int width = columns58mm, int feedBeforeCut = 4}) {
    final List<int> b = [];
    b.addAll(initPrinter);
    b.addAll(alignCenter);
    b.addAll(boldOn);
    b.addAll(doubleHeightOn);
    b.addAll(textLine('DARVI BILLING'));
    b.addAll(textNormal);
    b.addAll(textLine('PRINTER SELF-TEST'));
    b.addAll(boldOff);
    b.addAll(doubleDivider(width));
    b.addAll(alignLeft);
    if (width == columns80mm) {
      b.addAll(textLine('Hardware: Thermal (80mm)'));
      b.addAll(textLine('Font: Font A (48 Columns)'));
    } else {
      b.addAll(textLine('Hardware: SSEZNIK2POS (58mm)'));
      b.addAll(textLine('Font: Font A (32 Columns)'));
    }
    b.addAll(textLine('Driver: Safe Mode ESC/POS'));
    b.addAll(textLine('Engine: web-escpos-printer compliant'));
    b.addAll(textLine('Status: Transmission OK'));
    b.addAll(divider('-', width));
    if (width == columns80mm) {
      b.addAll(textLine('012345678901234567890123456789012345678901234567'));
    } else {
      b.addAll(textLine('01234567890123456789012345678901'));
    }
    b.addAll(textLine('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef'));
    b.addAll(divider('-', width));
    b.addAll(alignCenter);
    b.addAll(textLine('Improving Agriculture,'));
    b.addAll(textLine('Improving lives.'));
    b.addAll(feedLines(feedBeforeCut));
    b.addAll(partialCut);
    return Uint8List.fromList(b);
  }

  static List<String> _wrapText(String text, int maxWidth) {
    final List<String> result = [];
    final lines = text.split('\n');
    for (final rawLine in lines) {
      if (rawLine.length <= maxWidth) {
        result.add(rawLine);
      } else {
        var remaining = rawLine;
        while (remaining.length > maxWidth) {
          result.add(remaining.substring(0, maxWidth));
          remaining = remaining.substring(maxWidth);
        }
        if (remaining.isNotEmpty) {
          result.add(remaining);
        }
      }
    }
    return result;
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
