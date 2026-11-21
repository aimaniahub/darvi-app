import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/app_entities.dart';

class PosThermalReceiptPreview extends StatelessWidget {
  const PosThermalReceiptPreview({
    super.key,
    required this.saleDetail,
    this.cashierName = 'Cashier 1',
    this.customerName,
  });

  final SaleDetailView saleDetail;
  final String cashierName;
  final String? customerName;

  @override
  Widget build(BuildContext context) {
    final sale = saleDetail.sale;
    final items = saleDetail.items;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Container(
          width: 320, // Approximate physical 58mm scale representation
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFDFD),
            borderRadius: AppRadii.sm,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Text(
                'DARVI GROUP AGRI TECH',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Text(
                '#2 Totad Bldg, Gokul Rd, Hubli 580030',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Courier', fontSize: 11),
              ),
              const Text(
                'GSTIN: 29BKZPA0053M1ZQ • Ph: 9986890777',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Courier', fontSize: 11),
              ),
              const SizedBox(height: 6),
              const Text(
                '================================',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const Text(
                'TAX INVOICE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                '--------------------------------',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Courier', fontSize: 11),
              ),

              // Invoice Details
              _receiptRow('Invoice No:', sale.invoiceNo),
              _receiptRow(
                'Date/Time :',
                '${sale.createdAt.day.toString().padLeft(2, '0')}/${sale.createdAt.month.toString().padLeft(2, '0')}/${sale.createdAt.year} ${sale.createdAt.hour.toString().padLeft(2, '0')}:${sale.createdAt.minute.toString().padLeft(2, '0')}',
              ),
              _receiptRow('Cashier   :', cashierName),
              _receiptRow('Customer  :', customerName ?? 'Walk-in Customer'),
              const Text(
                '--------------------------------',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Courier', fontSize: 11),
              ),

              // Column Headers
              const Text(
                'ITEM              QTY     TOTAL',
                style: TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const Text(
                '--------------------------------',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Courier', fontSize: 11),
              ),

              // Items
              ...items.map((it) {
                final name = it.name.length > 17 ? it.name.substring(0, 16) : it.name.padRight(17);
                final qty = '${it.qty}'.padLeft(4);
                final total = it.lineTotal.toStringAsFixed(2).padLeft(9);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$name$qty$total',
                        style: const TextStyle(fontFamily: 'Courier', fontSize: 11),
                      ),
                      Text(
                        '  @ ${it.price.toStringAsFixed(2)}${it.discount > 0 ? " (Disc: ${it.discount.toStringAsFixed(2)})" : ""}',
                        style: TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                );
              }),

              const Text(
                '--------------------------------',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Courier', fontSize: 11),
              ),

              // Calculations
              _receiptRow('Subtotal :', AppFormatters.money(sale.subtotal, currency: "INR")),
              if (sale.discountTotal > 0)
                _receiptRow('Discount :', '-${AppFormatters.money(sale.discountTotal, currency: "INR")}'),
              if (sale.taxTotal > 0) ...[
                _receiptRow('CGST (9%):', AppFormatters.money(sale.taxTotal / 2, currency: "INR")),
                _receiptRow('SGST (9%):', AppFormatters.money(sale.taxTotal / 2, currency: "INR")),
              ],
              if (sale.roundOff != 0)
                _receiptRow('Round-Off:', sale.roundOff.toStringAsFixed(2)),
              const Text(
                '--------------------------------',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Courier', fontSize: 11),
              ),
              _receiptRow(
                'GRAND TOTAL:',
                AppFormatters.money(sale.total, currency: "INR"),
                isBold: true,
                fontSize: 13,
              ),
              _receiptRow('Pay Mode   :', sale.paymentMethod.name.toUpperCase()),
              _receiptRow('Paid Amount:', AppFormatters.money(sale.paid, currency: "INR")),
              if (sale.changeAmount > 0)
                _receiptRow('Change Due :', AppFormatters.money(sale.changeAmount, currency: "INR")),
              if (sale.total > sale.paid)
                _receiptRow('Balance Due:', AppFormatters.money(sale.total - sale.paid, currency: "INR")),

              const SizedBox(height: 8),
              const Text(
                '================================',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Courier', fontSize: 11),
              ),
              const SizedBox(height: 4),
              const Text(
                'Improving Agriculture,\nImproving lives.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Goods once sold will not be\ntaken back or exchanged.\nThank You! Visit Again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Courier', fontSize: 10),
              ),
              const SizedBox(height: 8),
              const Text(
                '* * * END OF RECEIPT * * *',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Courier', fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 11,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

