import 'package:flutter/material.dart';

import '../../../../core/utils/money_calculator.dart';
import '../../../../data/local/db/app_database.dart';
import '../../../../domain/repositories/repositories.dart';

class BookingDetailSheet extends StatelessWidget {
  const BookingDetailSheet({
    super.key,
    required this.booking,
    required this.plot,
    required this.customer,
    required this.bookingRepository,
    required this.accounts,
    required this.onPaymentRecorded,
    required this.onCancelled,
  });

  final PlotBooking booking;
  final Plot? plot;
  final dynamic customer;
  final BookingRepository bookingRepository;
  final List<dynamic> accounts;
  final VoidCallback onPaymentRecorded;
  final VoidCallback onCancelled;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'booked':
        return Colors.blue;
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _showPayInstallmentDialog(BuildContext context, BookingInstallment inst) {
    final remaining = inst.amount - inst.paidAmount;
    final amountCtrl = TextEditingController(text: remaining.toStringAsFixed(0));
    final refCtrl = TextEditingController();
    int accountId = accounts.isNotEmpty ? (accounts.first.id as int) : 1;
    String mode = 'upi';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('Pay Installment #${inst.installmentNumber}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${inst.title} • Total Due: ${MoneyCalculator.formatCurrency(inst.amount)}'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount to Pay (₹) *', prefixIcon: Icon(Icons.currency_rupee)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: accountId,
                  decoration: const InputDecoration(labelText: 'Receiving Account *'),
                  items: accounts.map<DropdownMenuItem<int>>((a) {
                    return DropdownMenuItem<int>(
                      value: a.id as int,
                      child: Text('${a.name} (${a.type.toUpperCase()})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => accountId = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: mode,
                  decoration: const InputDecoration(labelText: 'Payment Mode *'),
                  items: const [
                    DropdownMenuItem(value: 'upi', child: Text('UPI / QR')),
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer / NEFT')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque / DD')),
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => mode = val);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: refCtrl,
                  decoration: const InputDecoration(labelText: 'UTR / Txn Ref Number'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final payAmount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  if (payAmount <= 0) return;
                  await bookingRepository.payInstallment(
                    installmentId: inst.id,
                    amount: payAmount,
                    paymentAccountId: accountId,
                    paymentMode: mode,
                    referenceNo: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
                  );
                  Navigator.of(ctx).pop();
                  onPaymentRecorded();
                },
                child: const Text('Record Payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    final reasonCtrl = TextEditingController(text: 'Customer requested cancellation');
    final refundCtrl = TextEditingController(text: booking.bookingAmount.toStringAsFixed(0));
    int refundAccountId = accounts.isNotEmpty ? (accounts.first.id as int) : 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Cancel Booking & Issue Refund'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Cancelling this booking will revert the plot status to Available and post double-entry refund ledger entries.',
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Cancellation Reason *'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: refundCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Refund Amount (₹) *', prefixIcon: Icon(Icons.currency_rupee)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: refundAccountId,
                  decoration: const InputDecoration(labelText: 'Refund From Account *'),
                  items: accounts.map<DropdownMenuItem<int>>((a) {
                    return DropdownMenuItem<int>(
                      value: a.id as int,
                      child: Text('${a.name} (${a.type.toUpperCase()})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => refundAccountId = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  final refundAmount = double.tryParse(refundCtrl.text.trim()) ?? 0.0;
                  await bookingRepository.cancelBooking(
                    bookingId: booking.id,
                    reason: reasonCtrl.text.trim(),
                    refundAmount: refundAmount,
                    refundAccountId: refundAccountId,
                  );
                  Navigator.of(ctx).pop();
                  onCancelled();
                },
                child: const Text('Confirm Cancellation'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(booking.status);

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
                    child: Icon(Icons.bookmark, color: statusColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(booking.bookingNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Plot: ${plot?.uniquePlotId ?? "Plot #${booking.plotId}"}', style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('Investor: ${customer?.name ?? "Customer #${booking.customerId}"}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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
                      booking.status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Financial Overview Card
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
                          const Text('Total Plot Valuation', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            MoneyCalculator.formatCurrency(booking.totalPlotValue),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Advance Paid: ${MoneyCalculator.formatCurrency(booking.bookingAmount)}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Balance: ${MoneyCalculator.formatCurrency(booking.totalPlotValue - booking.bookingAmount)}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              if (booking.status != 'cancelled')
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel Booking & Refund'),
                    onPressed: () => _showCancelDialog(context),
                  ),
                ),

              if (booking.status == 'cancelled') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Booking Cancelled', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      Text('Reason: ${booking.cancellationReason ?? "N/A"}', style: const TextStyle(fontSize: 12)),
                      Text('Refund Amount: ${MoneyCalculator.formatCurrency(booking.refundAmount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const Text('Installment Schedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              FutureBuilder<List<dynamic>>(
                future: bookingRepository.getInstallments(booking.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                  }
                  final installments = (snapshot.data ?? []).cast<BookingInstallment>();
                  if (installments.isEmpty) {
                    return const Text('No installment schedule generated.', style: TextStyle(color: Colors.grey));
                  }
                  return Column(
                    children: installments.map((inst) {
                      final isPaid = inst.status == 'paid';
                      return Card(
                        elevation: 0,
                        color: isPaid ? Colors.green.shade50 : Colors.grey.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isPaid ? Colors.green.shade200 : Colors.grey.shade300),
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            '#${inst.installmentNumber} • ${inst.title}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: Text(
                            'Due: ${inst.dueDate.toLocal().toString().substring(0, 10)} • Paid: ${MoneyCalculator.formatCurrency(inst.paidAmount)} / ${MoneyCalculator.formatCurrency(inst.amount)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          trailing: isPaid
                              ? const Chip(
                                  label: Text('PAID', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                                  backgroundColor: Colors.transparent,
                                  side: BorderSide(color: Colors.green),
                                )
                              : booking.status == 'cancelled'
                                  ? const Text('CANCELLED', style: TextStyle(color: Colors.red, fontSize: 11))
                                  : FilledButton.tonal(
                                      onPressed: () => _showPayInstallmentDialog(context, inst),
                                      child: const Text('Pay'),
                                    ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
