import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/app_models.dart';
import '../../../../core/services/thermal_printer_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../cubit/pos_cubit.dart';

class PosCheckoutReviewView extends StatefulWidget {
  const PosCheckoutReviewView({super.key});

  @override
  State<PosCheckoutReviewView> createState() => _PosCheckoutReviewViewState();
}

class _PosCheckoutReviewViewState extends State<PosCheckoutReviewView> {
  final TextEditingController _paidCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();

  // Split payment row inputs
  PaymentMethod _splitMethod = PaymentMethod.cash;
  final TextEditingController _splitAmountCtrl = TextEditingController();
  int? _splitAccountId;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<PosCubit>();
    final state = cubit.state;
    _paidCtrl.text = (state.paid > 0 ? state.paid : state.total).toStringAsFixed(2);
    _notesCtrl.text = state.notes;
    _refCtrl.text = state.paymentReference;
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    _refCtrl.dispose();
    _splitAmountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PosCubit>();

    return BlocConsumer<PosCubit, PosState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        final customer = state.selectedCustomer;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppHeader(
            title: 'Cart & Checkout Review',
            breadcrumbs: const ['POS Billing'],
            subtitle: 'Cashier: ${state.cashierName} • Customer: ${customer?.name ?? "Walk-in Customer"}',
            showBackButton: true,
            onBackPressed: () => cubit.setViewMode(PosViewMode.workspace),
            actions: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                icon: const Icon(TablerIcons.edit, size: 16),
                label: const Text('Edit Cart'),
                onPressed: () => cubit.setViewMode(PosViewMode.workspace),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // LEFT COLUMN: Itemized Order Summary & Tax Breakdown
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    children: [
                                      _buildOrderTableCard(state),
                                      const SizedBox(height: AppSpacing.md),
                                      _buildFinancialBreakdownCard(state),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                // RIGHT COLUMN: Payment & Settlement & Printing
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    children: [
                                      _buildPaymentCard(context, cubit, state),
                                      const SizedBox(height: AppSpacing.md),
                                      _buildPrintOptionsCard(context, cubit, state),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _buildOrderTableCard(state),
                                const SizedBox(height: AppSpacing.md),
                                _buildFinancialBreakdownCard(state),
                                const SizedBox(height: AppSpacing.md),
                                _buildPaymentCard(context, cubit, state),
                                const SizedBox(height: AppSpacing.md),
                                _buildPrintOptionsCard(context, cubit, state),
                              ],
                            ),
                    ),
                  ),
                  _buildBottomCheckoutDock(context, cubit, state),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildOrderTableCard(PosState state) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.md,
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(TablerIcons.list, color: Color(0xFF135D44), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Order Summary (${state.cart.length} distinct items, ${state.totalQuantityCount} total units)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const Divider(height: 20),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(4),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
              },
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: Color(0xFFF1F5F3)),
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text('Unit Price', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                ...state.cart.map((item) {
                  return TableRow(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            if (item.batchNumber != null)
                              Text('Batch: ${item.batchNumber}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                            if (item.discount > 0)
                              Text('Discount: -₹${item.discount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: Colors.blue)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Text('${item.qty} ${item.unit}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Text(AppFormatters.money(item.price, currency: "INR"), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Text(AppFormatters.money(item.lineTotal, currency: "INR"), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialBreakdownCard(PosState state) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.md,
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(TablerIcons.calculator, color: Color(0xFF135D44), size: 20),
                SizedBox(width: 8),
                Text(
                  'Tax & Financial Breakdown',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const Divider(height: 20),
            _breakdownRow('Gross Subtotal:', AppFormatters.money(state.grossSubtotal, currency: "INR")),
            if (state.itemDiscountsTotal > 0)
              _breakdownRow('Item Discounts:', '-${AppFormatters.money(state.itemDiscountsTotal, currency: "INR")}', textColor: Colors.blue),
            if (state.orderDiscount > 0)
              _breakdownRow('Bill Discount:', '-${AppFormatters.money(state.orderDiscount, currency: "INR")}', textColor: Colors.blue),
            _breakdownRow('Taxable Value:', AppFormatters.money(state.taxableAmount, currency: "INR")),
            if (state.taxEnabled) ...[
              _breakdownRow('Intra-state CGST (9%):', AppFormatters.money(state.cgst, currency: "INR")),
              _breakdownRow('Intra-state SGST (9%):', AppFormatters.money(state.sgst, currency: "INR")),
            ],
            if (state.roundOff != 0)
              _breakdownRow('Round-Off Delta:', state.roundOff.toStringAsFixed(2)),
            const Divider(height: 16),
            _breakdownRow(
              'Final Total Due:',
              AppFormatters.money(state.total, currency: "INR"),
              isBold: true,
              fontSize: 16,
              textColor: const Color(0xFF135D44),
            ),
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 12,
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context, PosCubit cubit, PosState state) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.md,
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(TablerIcons.cash, color: Color(0xFF135D44), size: 20),
                SizedBox(width: 8),
                Text(
                  'Payment & Settlement',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const Divider(height: 20),

            // Payment Mode Selector Tabs
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _paymentChip(cubit, state, PaymentMethod.cash, 'Cash', TablerIcons.cash),
                _paymentChip(cubit, state, PaymentMethod.upi, 'UPI', TablerIcons.qrcode),
                _paymentChip(cubit, state, PaymentMethod.bankTransfer, 'Bank Transfer', TablerIcons.buildingBank),
                _paymentChip(cubit, state, PaymentMethod.card, 'Card', TablerIcons.creditCard),
                _paymentChip(cubit, state, PaymentMethod.split, 'Split Payment', TablerIcons.gitFork),
                _paymentChip(cubit, state, PaymentMethod.credit, 'Credit (Pay Later)', TablerIcons.clock),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Mode 1: Cash Mode
            if (state.paymentMethod == PaymentMethod.cash) ...[
              const Text('Quick Cash Tender:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _quickCashButton(cubit, state.total, 'Exact (₹${state.total.toStringAsFixed(0)})'),
                  _quickCashButton(cubit, 100, '₹100'),
                  _quickCashButton(cubit, 200, '₹200'),
                  _quickCashButton(cubit, 500, '₹500'),
                  _quickCashButton(cubit, 1000, '₹1000'),
                  _quickCashButton(cubit, 2000, '₹2000'),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _paidCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Cash Received / Tendered (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(TablerIcons.currencyRupee),
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val) ?? 0.0;
                  cubit.setPaid(parsed);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: AppRadii.sm,
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Change Due to Customer:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      AppFormatters.money(state.change, currency: "INR"),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ],

            // Mode 2: UPI, Bank, Card
            if (state.paymentMethod == PaymentMethod.upi ||
                state.paymentMethod == PaymentMethod.bankTransfer ||
                state.paymentMethod == PaymentMethod.card) ...[
              if (state.accounts.isNotEmpty) ...[
                DropdownButtonFormField<int?>(
                  value: state.selectedPaymentAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Receiving Bank / Drawer Account',
                    border: OutlineInputBorder(),
                  ),
                  items: state.accounts.map((acc) {
                    return DropdownMenuItem<int?>(
                      value: acc.id,
                      child: Text('${acc.name} (${acc.type.toUpperCase()})'),
                    );
                  }).toList(),
                  onChanged: (id) => cubit.setPaymentAccountId(id),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              TextField(
                controller: _refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Transaction / UTR Reference No (Optional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => cubit.setPaymentReference(val),
              ),
            ],

            // Mode 3: Split Payments (Multi-row allocation)
            if (state.paymentMethod == PaymentMethod.split) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: AppRadii.sm,
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Order: ${AppFormatters.money(state.total, currency: "INR")}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('Remaining: ${AppFormatters.money(state.remainingSplitBalance, currency: "INR")}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: state.remainingSplitBalance > 0 ? Colors.red : Colors.green,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Split rows list
              if (state.splitPayments.isNotEmpty) ...[
                ...state.splitPayments.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final sp = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadii.sm,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Text(sp.method.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const Spacer(),
                        Text(AppFormatters.money(sp.amount, currency: "INR"),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF135D44))),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(TablerIcons.trash, size: 18, color: Colors.red),
                          onPressed: () => cubit.removeSplitPayment(idx),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.xs),
              ],

              // Add Split Row Section
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<PaymentMethod>(
                      value: _splitMethod,
                      isDense: true,
                      decoration: const InputDecoration(labelText: 'Method', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: PaymentMethod.cash, child: Text('Cash')),
                        DropdownMenuItem(value: PaymentMethod.upi, child: Text('UPI')),
                        DropdownMenuItem(value: PaymentMethod.bankTransfer, child: Text('Bank')),
                        DropdownMenuItem(value: PaymentMethod.card, child: Text('Card')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _splitMethod = val);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: TextField(
                      controller: _splitAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount (₹)',
                        border: const OutlineInputBorder(),
                        hintText: state.remainingSplitBalance > 0
                            ? state.remainingSplitBalance.toStringAsFixed(0)
                            : '',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF135D44),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    onPressed: () {
                      final amt = double.tryParse(_splitAmountCtrl.text) ?? state.remainingSplitBalance;
                      if (amt > 0) {
                        cubit.addSplitPayment(_splitMethod, amt, accountId: _splitAccountId);
                        _splitAmountCtrl.clear();
                      }
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],

            // Mode 4: Credit Sale (Pay Later)
            if (state.paymentMethod == PaymentMethod.credit) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: AppRadii.sm,
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(TablerIcons.infoCircle, color: Colors.amber, size: 18),
                        SizedBox(width: 6),
                        Text('Credit Sale Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The entire amount of ${AppFormatters.money(state.total, currency: "INR")} will be added to customer\'s ledger receivable balance.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                    ),
                    if (state.isCustomerOverCredit) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'WARNING: This credit sale exceeds the customer\'s credit limit!',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // Cashier Notes
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Order / Cashier Notes (Optional)',
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => cubit.setNotes(val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentChip(
    PosCubit cubit,
    PosState state,
    PaymentMethod method,
    String label,
    IconData icon,
  ) {
    final selected = state.paymentMethod == method;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: selected ? Colors.white : Colors.black87),
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF135D44),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) {
        cubit.setPaymentMethod(method);
        if (method != PaymentMethod.cash && method != PaymentMethod.split) {
          cubit.resetPaidToTotal();
          _paidCtrl.text = state.total.toStringAsFixed(2);
        } else if (method == PaymentMethod.credit) {
          cubit.setPaid(0);
          _paidCtrl.text = '0.00';
        }
      },
    );
  }

  Widget _quickCashButton(PosCubit cubit, double amount, String label) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 32),
      ),
      onPressed: () {
        cubit.setPaid(amount);
        _paidCtrl.text = amount.toStringAsFixed(2);
      },
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _buildPrintOptionsCard(BuildContext context, PosCubit cubit, PosState state) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.md,
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(TablerIcons.printer, color: Color(0xFF135D44), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Print & Receipt Options',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Auto-Print', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    Switch(
                      value: state.autoPrintOnCheckout,
                      activeTrackColor: const Color(0xFF135D44),
                      onChanged: (val) => cubit.setAutoPrintOnCheckout(val),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),

            // Live Connection Status Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: state.isClenterConnected ? Colors.green.shade50 : Colors.amber.shade50,
                borderRadius: AppRadii.sm,
                border: Border.all(
                  color: state.isClenterConnected ? Colors.green.shade300 : Colors.amber.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        state.isClenterConnected ? TablerIcons.circleCheck : TablerIcons.alertTriangle,
                        color: state.isClenterConnected ? Colors.green.shade700 : Colors.amber.shade900,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.isClenterConnected
                              ? 'Cleanter App Connected & Ready'
                              : 'Cleanter not connected',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: state.isClenterConnected ? Colors.green.shade900 : Colors.amber.shade900,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(TablerIcons.refresh, size: 18),
                        tooltip: 'Check Cleanter Connection',
                        onPressed: () => cubit.connectClenter(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.isClenterConnected
                        ? 'Receipt will print smoothly to Cleanter local thermal service.'
                        : 'Connect via Cleanter companion app or print smoothly via System Spooler without interruption.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                  if (!state.isClenterConnected) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(0, 32),
                          ),
                          icon: const Icon(TablerIcons.refresh, size: 14),
                          label: const Text('Connect Cleanter', style: TextStyle(fontSize: 11)),
                          onPressed: () => cubit.connectClenter(),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(0, 32),
                          ),
                          icon: const Icon(TablerIcons.printer, size: 14),
                          label: const Text('Use System Spooler', style: TextStyle(fontSize: 11)),
                          onPressed: () => cubit.setPrintTransportMode(PrintTransportMode.systemSpooler),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Receipt Paper Format
            const Text(
              'Receipt Paper Format:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('58mm Thermal (SSEZNIK2POS)'),
                  selected: state.paperWidth == ReceiptPaperWidth.mm58,
                  onSelected: (_) => cubit.setPaperWidth(ReceiptPaperWidth.mm58),
                ),
                ChoiceChip(
                  label: const Text('80mm Thermal'),
                  selected: state.paperWidth == ReceiptPaperWidth.mm80,
                  onSelected: (_) => cubit.setPaperWidth(ReceiptPaperWidth.mm80),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Direct 1-Click Print Receipt Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF135D44),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: AppRadii.md),
              ),
              icon: const Icon(TablerIcons.printer, size: 18),
              label: const Text(
                'Print Receipt Now',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: state.receiptProcessing ? null : () => cubit.printReceiptSmooth(),
            ),

            const SizedBox(height: AppSpacing.xs),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 38),
                shape: RoundedRectangleBorder(borderRadius: AppRadii.md),
              ),
              icon: const Icon(TablerIcons.fileInvoice, size: 16),
              label: const Text('Print A4 Tax Invoice (PDF)', style: TextStyle(fontSize: 12)),
              onPressed: state.receiptProcessing ? null : () => cubit.printA4Pdf(),
            ),

            if (state.receiptProcessing) ...[
              const SizedBox(height: AppSpacing.sm),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCheckoutDock(BuildContext context, PosCubit cubit, PosState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Order details summary on the left (never wraps vertically)
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${state.totalQuantityCount} Items • ${state.cart.length} Products',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    AppFormatters.money(state.total, currency: 'INR'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF135D44),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Actions on the right: Print & Complete Sale
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF135D44),
                    side: const BorderSide(color: Color(0xFF135D44)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: AppRadii.md),
                  ),
                  icon: const Icon(TablerIcons.printer, size: 16),
                  label: const Text('Print', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: state.receiptProcessing || state.cart.isEmpty
                      ? null
                      : () => cubit.printReceiptSmooth(),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF135D44),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: AppRadii.md),
                  ),
                  icon: state.isCheckingOut
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(TablerIcons.circleCheck, size: 16),
                  label: Text(
                    state.isCheckingOut ? 'Processing...' : 'Complete Sale',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: state.isCheckingOut || state.cart.isEmpty
                      ? null
                      : () async {
                          await cubit.checkout();
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

