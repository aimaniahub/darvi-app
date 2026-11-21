import 'package:flutter_test/flutter_test.dart';
import 'package:mini_pos_inventory/core/utils/money_calculator.dart';

void main() {
  group('MoneyCalculator', () {
    test('line total applies quantity and item discount', () {
      final total = MoneyCalculator.lineTotal(
        unitPrice: 25,
        qty: 3,
        itemDiscount: 10,
      );

      expect(total, 65);
    });

    test('line total never goes negative', () {
      final total = MoneyCalculator.lineTotal(
        unitPrice: 10,
        qty: 1,
        itemDiscount: 20,
      );

      expect(total, 0);
    });

    test('subtotal sums line totals with rounding', () {
      final subtotal = MoneyCalculator.subtotal([10.105, 20.106, 5.004]);

      expect(subtotal, 35.22);
    });

    test('tax is zero when disabled', () {
      final tax = MoneyCalculator.tax(
        taxableAmount: 100,
        taxEnabled: false,
        taxRate: 0.14,
      );

      expect(tax, 0);
    });

    test('order total applies order discount and tax', () {
      final total = MoneyCalculator.orderTotal(
        subtotal: 200,
        orderDiscount: 15,
        tax: 25.9,
      );

      expect(total, 210.9);
    });

    test('profit for line uses snapshot prices and discount', () {
      final profit = MoneyCalculator.profitForLine(
        priceSnapshot: 40,
        costSnapshot: 25,
        qty: 4,
        discount: 6,
      );

      expect(profit, 54);
    });

    test('grossSubtotal and itemDiscountTotal separate line values', () {
      final gross = MoneyCalculator.grossSubtotal([100.0, 250.5, 49.5]);
      final itemDiscounts = MoneyCalculator.itemDiscountTotal([10.0, 25.5, 0.0]);

      expect(gross, 400.0);
      expect(itemDiscounts, 35.5);
    });

    test('intra-state GST calculates equal CGST and SGST at half rates', () {
      final gst = MoneyCalculator.calculateGst(
        taxableAmount: 1000.0,
        gstRate: 0.18,
        isInterState: false,
      );

      expect(gst.taxableAmount, 1000.0);
      expect(gst.cgstRate, 0.09);
      expect(gst.cgstAmount, 90.0);
      expect(gst.sgstRate, 0.09);
      expect(gst.sgstAmount, 90.0);
      expect(gst.igstRate, 0.0);
      expect(gst.igstAmount, 0.0);
      expect(gst.totalTax, 180.0);
    });

    test('inter-state GST calculates full IGST with zero CGST/SGST', () {
      final gst = MoneyCalculator.calculateGst(
        taxableAmount: 2500.0,
        gstRate: 0.12,
        isInterState: true,
      );

      expect(gst.taxableAmount, 2500.0);
      expect(gst.cgstAmount, 0.0);
      expect(gst.sgstAmount, 0.0);
      expect(gst.igstRate, 0.12);
      expect(gst.igstAmount, 300.0);
      expect(gst.totalTax, 300.0);
    });

    test('roundOffTotal rounds to nearest integer and calculates exact delta', () {
      final roundUp = MoneyCalculator.roundOffTotal(1234.34);
      expect(roundUp.roundedTotal, 1234.0);
      expect(roundUp.roundOff, -0.34);

      final roundDown = MoneyCalculator.roundOffTotal(1234.65);
      expect(roundDown.roundedTotal, 1235.0);
      expect(roundDown.roundOff, 0.35);
    });

    test('computeInvoice maintains double-entry and reconciliation integrity', () {
      // 2 items: 
      // Item 1: 2 x 500 = 1000 gross, 100 discount -> 900 net
      // Item 2: 1 x 400 = 400 gross, 0 discount -> 400 net
      // Total Gross: 1400, Item Discount: 100 -> Net: 1300
      // Order Discount: 100 -> Taxable: 1200
      // GST 18% Intra-State: CGST 108, SGST 108 -> Total Tax: 216
      // Total before roundoff: 1416.00 -> Round-off: 0.0 -> Grand Total: 1416.00
      final totals = MoneyCalculator.computeInvoice(
        lineGrossAmounts: [1000.0, 400.0],
        lineDiscounts: [100.0, 0.0],
        orderDiscount: 100.0,
        gstRate: 0.18,
        isInterState: false,
      );

      expect(totals.grossSubtotal, 1400.0);
      expect(totals.itemDiscountTotal, 100.0);
      expect(totals.netSubtotal, 1300.0);
      expect(totals.orderDiscount, 100.0);
      expect(totals.taxableAmount, 1200.0);
      expect(totals.gst.cgstAmount, 108.0);
      expect(totals.gst.sgstAmount, 108.0);
      expect(totals.gst.totalTax, 216.0);
      expect(totals.grandTotal, 1416.0);

      // Reconciliation Proof:
      // Gross Subtotal - (Item Discounts + Order Discount) + Total Tax + RoundOff == Grand Total
      final totalDiscounts = totals.itemDiscountTotal + totals.orderDiscount;
      final reconciled = totals.grossSubtotal - totalDiscounts + totals.gst.totalTax + totals.roundOff;
      expect(reconciled, totals.grandTotal);
    });
  });
}
