import 'dart:math';

import 'formatters.dart';

class GstBreakdown {
  const GstBreakdown({
    required this.taxableAmount,
    required this.cgstRate,
    required this.cgstAmount,
    required this.sgstRate,
    required this.sgstAmount,
    required this.igstRate,
    required this.igstAmount,
    required this.totalTax,
  });

  final double taxableAmount;
  final double cgstRate;
  final double cgstAmount;
  final double sgstRate;
  final double sgstAmount;
  final double igstRate;
  final double igstAmount;
  final double totalTax;

  double get cgst => cgstAmount;
  double get sgst => sgstAmount;
  double get igst => igstAmount;

  static const zero = GstBreakdown(
    taxableAmount: 0,
    cgstRate: 0,
    cgstAmount: 0,
    sgstRate: 0,
    sgstAmount: 0,
    igstRate: 0,
    igstAmount: 0,
    totalTax: 0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GstBreakdown &&
          runtimeType == other.runtimeType &&
          taxableAmount == other.taxableAmount &&
          cgstRate == other.cgstRate &&
          cgstAmount == other.cgstAmount &&
          sgstRate == other.sgstRate &&
          sgstAmount == other.sgstAmount &&
          igstRate == other.igstRate &&
          igstAmount == other.igstAmount &&
          totalTax == other.totalTax;

  @override
  int get hashCode => Object.hash(
        taxableAmount,
        cgstRate,
        cgstAmount,
        sgstRate,
        sgstAmount,
        igstRate,
        igstAmount,
        totalTax,
      );

  @override
  String toString() =>
      'GstBreakdown(taxable: $taxableAmount, cgst: $cgstAmount ($cgstRate), sgst: $sgstAmount ($sgstRate), igst: $igstAmount ($igstRate), totalTax: $totalTax)';
}

class InvoiceTotals {
  const InvoiceTotals({
    required this.grossSubtotal,
    required this.itemDiscountTotal,
    required this.netSubtotal,
    required this.orderDiscount,
    required this.taxableAmount,
    required this.gst,
    required this.totalBeforeRoundOff,
    required this.roundOff,
    required this.grandTotal,
  });

  final double grossSubtotal;
  final double itemDiscountTotal;
  final double netSubtotal;
  final double orderDiscount;
  final double taxableAmount;
  final GstBreakdown gst;
  final double totalBeforeRoundOff;
  final double roundOff;
  final double grandTotal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceTotals &&
          runtimeType == other.runtimeType &&
          grossSubtotal == other.grossSubtotal &&
          itemDiscountTotal == other.itemDiscountTotal &&
          netSubtotal == other.netSubtotal &&
          orderDiscount == other.orderDiscount &&
          taxableAmount == other.taxableAmount &&
          gst == other.gst &&
          totalBeforeRoundOff == other.totalBeforeRoundOff &&
          roundOff == other.roundOff &&
          grandTotal == other.grandTotal;

  @override
  int get hashCode => Object.hash(
        grossSubtotal,
        itemDiscountTotal,
        netSubtotal,
        orderDiscount,
        taxableAmount,
        gst,
        totalBeforeRoundOff,
        roundOff,
        grandTotal,
      );

  @override
  String toString() =>
      'InvoiceTotals(gross: $grossSubtotal, itemDisc: $itemDiscountTotal, net: $netSubtotal, orderDisc: $orderDiscount, taxable: $taxableAmount, tax: ${gst.totalTax}, unrounded: $totalBeforeRoundOff, roundOff: $roundOff, grandTotal: $grandTotal)';
}

class MoneyCalculator {
  const MoneyCalculator._();

  static double round2(double value) => (value * 100).roundToDouble() / 100;

  static double lineTotal({
    required double unitPrice,
    required int qty,
    required double itemDiscount,
  }) {
    final raw = (unitPrice * qty) - itemDiscount;
    return round2(max(0, raw));
  }

  static double subtotal(List<double> lineTotals) {
    return round2(lineTotals.fold(0, (sum, line) => sum + line));
  }

  static double grossSubtotal(List<double> grossLineAmounts) {
    return round2(grossLineAmounts.fold(0, (sum, line) => sum + line));
  }

  static double itemDiscountTotal(List<double> lineDiscounts) {
    return round2(lineDiscounts.fold(0, (sum, line) => sum + line));
  }

  static double tax({
    required double taxableAmount,
    required bool taxEnabled,
    required double taxRate,
  }) {
    if (!taxEnabled) {
      return 0;
    }
    return round2(max(0, taxableAmount) * taxRate);
  }

  static GstBreakdown calculateGst({
    required double taxableAmount,
    required double gstRate,
    required bool isInterState,
    bool taxEnabled = true,
  }) {
    if (!taxEnabled || gstRate <= 0 || taxableAmount <= 0) {
      return GstBreakdown(
        taxableAmount: max(0, taxableAmount),
        cgstRate: 0,
        cgstAmount: 0,
        sgstRate: 0,
        sgstAmount: 0,
        igstRate: 0,
        igstAmount: 0,
        totalTax: 0,
      );
    }

    final safeTaxable = max(0.0, taxableAmount);
    if (isInterState) {
      final igst = round2(safeTaxable * gstRate);
      return GstBreakdown(
        taxableAmount: safeTaxable,
        cgstRate: 0,
        cgstAmount: 0,
        sgstRate: 0,
        sgstAmount: 0,
        igstRate: gstRate,
        igstAmount: igst,
        totalTax: igst,
      );
    } else {
      final halfRate = round2(gstRate / 2.0);
      final cgst = round2(safeTaxable * halfRate);
      final sgst = round2(safeTaxable * halfRate);
      return GstBreakdown(
        taxableAmount: safeTaxable,
        cgstRate: halfRate,
        cgstAmount: cgst,
        sgstRate: halfRate,
        sgstAmount: sgst,
        igstRate: 0,
        igstAmount: 0,
        totalTax: round2(cgst + sgst),
      );
    }
  }

  static double orderTotal({
    required double subtotal,
    required double orderDiscount,
    required double tax,
  }) {
    final raw = subtotal - orderDiscount + tax;
    return round2(max(0, raw));
  }

  static ({double roundedTotal, double roundOff}) roundOffTotal(double total) {
    final rounded = total.roundToDouble();
    final diff = round2(rounded - total);
    return (roundedTotal: rounded, roundOff: diff);
  }

  static InvoiceTotals computeInvoice({
    required List<double> lineGrossAmounts,
    required List<double> lineDiscounts,
    required double orderDiscount,
    required double gstRate,
    required bool isInterState,
    bool taxEnabled = true,
    bool applyRoundOff = true,
  }) {
    final gross = grossSubtotal(lineGrossAmounts);
    final itemDisc = itemDiscountTotal(lineDiscounts);
    final net = round2(max(0, gross - itemDisc));
    final safeOrderDisc = round2(min(orderDiscount, net));
    final taxable = round2(max(0, net - safeOrderDisc));

    final gst = calculateGst(
      taxableAmount: taxable,
      gstRate: gstRate,
      isInterState: isInterState,
      taxEnabled: taxEnabled,
    );

    final rawGrand = round2(taxable + gst.totalTax);

    if (applyRoundOff) {
      final r = roundOffTotal(rawGrand);
      return InvoiceTotals(
        grossSubtotal: gross,
        itemDiscountTotal: itemDisc,
        netSubtotal: net,
        orderDiscount: safeOrderDisc,
        taxableAmount: taxable,
        gst: gst,
        totalBeforeRoundOff: rawGrand,
        roundOff: r.roundOff,
        grandTotal: r.roundedTotal,
      );
    }

    return InvoiceTotals(
      grossSubtotal: gross,
      itemDiscountTotal: itemDisc,
      netSubtotal: net,
      orderDiscount: safeOrderDisc,
      taxableAmount: taxable,
      gst: gst,
      totalBeforeRoundOff: rawGrand,
      roundOff: 0.0,
      grandTotal: rawGrand,
    );
  }

  static double profitForLine({
    required double priceSnapshot,
    required double costSnapshot,
    required int qty,
    required double discount,
  }) {
    final gross = (priceSnapshot - costSnapshot) * qty;
    return round2(gross - discount);
  }

  static String formatCurrency(double value) => AppFormatters.money(value);
}
