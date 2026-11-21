import 'package:flutter/material.dart';

import '../../../../core/services/quotation_pdf_service.dart';
import '../../../../core/utils/money_calculator.dart';
import '../../../../data/local/db/app_database.dart';
import '../../../../domain/repositories/repositories.dart';

class QuotationDetailSheet extends StatelessWidget {
  const QuotationDetailSheet({
    super.key,
    required this.quotation,
    required this.quotationRepository,
    required this.accounts,
    required this.onStatusChanged,
    required this.onConvertedToSale,
  });

  final Quotation quotation;
  final QuotationRepository quotationRepository;
  final List<dynamic> accounts;
  final ValueChanged<String> onStatusChanged;
  final void Function(int accountId, String mode) onConvertedToSale;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.grey;
      case 'sent':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'converted':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _showConvertDialog(BuildContext context) {
    int selectedAccountId = accounts.isNotEmpty ? (accounts.first.id as int) : 1;
    String paymentMode = 'upi';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Convert Quotation to Invoice'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Converting Quotation ${quotation.quotationNumber} (${MoneyCalculator.formatCurrency(quotation.totalAmount)}) into a confirmed Sales Invoice and generating balanced double-entry ledger entries.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedAccountId,
                  decoration: const InputDecoration(labelText: 'Receiving Account *'),
                  items: accounts.map<DropdownMenuItem<int>>((a) {
                    return DropdownMenuItem<int>(
                      value: a.id as int,
                      child: Text('${a.name} (${a.type.toUpperCase()})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedAccountId = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paymentMode,
                  decoration: const InputDecoration(labelText: 'Payment Mode *'),
                  items: const [
                    DropdownMenuItem(value: 'upi', child: Text('UPI / QR')),
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer / NEFT')),
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => paymentMode = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Confirm Conversion'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onConvertedToSale(selectedAccountId, paymentMode);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(quotation.status);
    final pdfService = QuotationPdfService();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: statusColor.withOpacity(0.12),
                    child: Icon(Icons.request_quote, color: statusColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(quotation.quotationNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Client: ${quotation.customerName} (${quotation.customerPhone})', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                        Text('Valid until: ${quotation.validUntil.toLocal().toString().substring(0, 10)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      quotation.status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Total Card
              Card(
                elevation: 0,
                color: Theme.of(context).primaryColor.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Grand Total Quotation', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            MoneyCalculator.formatCurrency(quotation.totalAmount),
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Subtotal: ${MoneyCalculator.formatCurrency(quotation.subtotal)}', style: const TextStyle(fontSize: 12)),
                          if (quotation.discountTotal > 0)
                            Text('Discount: -${MoneyCalculator.formatCurrency(quotation.discountTotal)}', style: const TextStyle(fontSize: 12, color: Colors.red)),
                          if (quotation.taxTotal > 0)
                            Text('GST: +${MoneyCalculator.formatCurrency(quotation.taxTotal)}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Action Buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FutureBuilder<List<dynamic>>(
                    future: quotationRepository.getQuotationItems(quotation.id),
                    builder: (context, snapshot) {
                      final items = (snapshot.data ?? []).cast<QuotationItem>();
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.share),
                            label: const Text('Share PDF'),
                            onPressed: items.isEmpty ? null : () => pdfService.shareQuotation(quotation: quotation, items: items),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.print),
                            label: const Text('Print'),
                            onPressed: items.isEmpty ? null : () => pdfService.printQuotation(quotation: quotation, items: items),
                          ),
                        ],
                      );
                    },
                  ),
                  if (quotation.status != 'converted')
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.shopping_cart_checkout),
                      label: const Text('Convert to Sale'),
                      onPressed: () => _showConvertDialog(context),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'Change Status',
                    onSelected: onStatusChanged,
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'draft', child: Text('Draft')),
                      PopupMenuItem(value: 'sent', child: Text('Sent')),
                      PopupMenuItem(value: 'accepted', child: Text('Accepted')),
                      PopupMenuItem(value: 'rejected', child: Text('Rejected')),
                    ],
                    child: const OutlinedButton(
                      onPressed: null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz, size: 18),
                          SizedBox(width: 4),
                          Text('Status'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Text('Quotation Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              FutureBuilder<List<dynamic>>(
                future: quotationRepository.getQuotationItems(quotation.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                  }
                  final items = (snapshot.data ?? []).cast<QuotationItem>();
                  if (items.isEmpty) {
                    return const Text('No line items recorded.', style: TextStyle(color: Colors.grey));
                  }
                  return Column(
                    children: items.map((itm) {
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.grey.shade200,
                          child: Icon(itm.itemType == 'plot' ? Icons.landscape : Icons.inventory_2, size: 14),
                        ),
                        title: Text(itm.description, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${itm.quantity} × ₹${itm.unitPrice} • Disc: ₹${itm.discount} • GST: ${itm.gstRate}%'),
                        trailing: Text(
                          MoneyCalculator.formatCurrency(itm.total),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              if (quotation.terms != null && quotation.terms!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Terms & Conditions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(quotation.terms!, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
            ],
          ),
        );
      },
    );
  }
}
