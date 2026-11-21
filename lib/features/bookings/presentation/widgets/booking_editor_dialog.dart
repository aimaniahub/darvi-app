import 'package:flutter/material.dart';

import '../../../../core/utils/money_calculator.dart';
import '../../../../data/local/db/app_database.dart';

class BookingEditorDialog extends StatefulWidget {
  const BookingEditorDialog({
    super.key,
    required this.plots,
    required this.customers,
    required this.accounts,
    this.preselectedPlotId,
  });

  final List<Plot> plots;
  final List<dynamic> customers;
  final List<dynamic> accounts;
  final int? preselectedPlotId;

  @override
  State<BookingEditorDialog> createState() => _BookingEditorDialogState();
}

class _BookingEditorDialogState extends State<BookingEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _bookingNumCtrl;
  late final TextEditingController _advanceCtrl;
  late final TextEditingController _refNoCtrl;
  late final TextEditingController _notesCtrl;

  int? _selectedPlotId;
  int? _selectedCustomerId;
  int? _selectedAccountId;
  String _paymentMode = 'upi';

  late List<Plot> _availablePlots;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _bookingNumCtrl = TextEditingController(text: 'BK-${now.year}-${now.millisecondsSinceEpoch.toString().substring(8)}');
    _advanceCtrl = TextEditingController(text: '100000');
    _refNoCtrl = TextEditingController();
    _notesCtrl = TextEditingController();

    // Filter to available or reserved plots, or preselected plot
    _availablePlots = widget.plots.where((p) => p.status == 'available' || p.status == 'reserved' || p.id == widget.preselectedPlotId).toList();

    _selectedPlotId = widget.preselectedPlotId ?? (_availablePlots.isNotEmpty ? _availablePlots.first.id : null);
    _selectedCustomerId = widget.customers.isNotEmpty ? (widget.customers.first.id as int) : null;
    _selectedAccountId = widget.accounts.isNotEmpty ? (widget.accounts.first.id as int) : 1;
  }

  Plot? get _currentPlot {
    if (_selectedPlotId == null) return null;
    return widget.plots.where((p) => p.id == _selectedPlotId).firstOrNull;
  }

  double get _totalPlotValue => _currentPlot?.totalPrice ?? 0.0;
  double get _advanceAmount => double.tryParse(_advanceCtrl.text.trim()) ?? 0.0;
  double get _balance => _totalPlotValue - _advanceAmount;

  @override
  void dispose() {
    _bookingNumCtrl.dispose();
    _advanceCtrl.dispose();
    _refNoCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_availablePlots.isEmpty) {
      return AlertDialog(
        title: const Text('No Plots Available'),
        content: const Text('There are currently no available or reserved plots to book. Please add or free up a plot first.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bookmark_added, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          const Text('Customer Plot Booking'),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _bookingNumCtrl,
                        decoration: const InputDecoration(labelText: 'Booking Ref # *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedPlotId,
                        decoration: const InputDecoration(labelText: 'Select Farmland Plot *', prefixIcon: Icon(Icons.landscape)),
                        items: _availablePlots.map((p) {
                          return DropdownMenuItem<int>(
                            value: p.id,
                            child: Text('${p.uniquePlotId} (₹${(p.totalPrice / 100000).toStringAsFixed(1)}L)'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedPlotId = val;
                            if (_currentPlot != null) {
                              _advanceCtrl.text = (_currentPlot!.totalPrice * 0.1).toStringAsFixed(0);
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _selectedCustomerId,
                  decoration: const InputDecoration(labelText: 'Customer / Investor *', prefixIcon: Icon(Icons.person)),
                  items: widget.customers.map<DropdownMenuItem<int>>((c) {
                    return DropdownMenuItem<int>(
                      value: c.id as int,
                      child: Text('${c.name} (${c.phone ?? "No phone"})'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCustomerId = val),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 14),

                // Plot summary banner
                if (_currentPlot != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Plot ${_currentPlot!.uniquePlotId} • ${_currentPlot!.dimensions}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Area: ${_currentPlot!.areaSqFt.toStringAsFixed(0)} Sq.Ft. • ${_currentPlot!.cropType ?? "Agro-forestry"}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                            ),
                          ],
                        ),
                        Text(
                          MoneyCalculator.formatCurrency(_totalPlotValue),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _advanceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Booking Advance (₹) *',
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final a = double.tryParse(v ?? '') ?? 0.0;
                          if (a <= 0) return 'Must be > 0';
                          if (a > _totalPlotValue) return 'Cannot exceed total value';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _paymentMode,
                        decoration: const InputDecoration(labelText: 'Payment Mode'),
                        items: const [
                          DropdownMenuItem(value: 'upi', child: Text('UPI / QR')),
                          DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer / NEFT')),
                          DropdownMenuItem(value: 'cheque', child: Text('Cheque / DD')),
                          DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _paymentMode = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedAccountId,
                        decoration: const InputDecoration(labelText: 'Deposit To Account *'),
                        items: widget.accounts.map<DropdownMenuItem<int>>((a) {
                          return DropdownMenuItem<int>(
                            value: a.id as int,
                            child: Text('${a.name} (${a.type.toUpperCase()})'),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedAccountId = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _refNoCtrl,
                        decoration: const InputDecoration(labelText: 'Txn / UTR / Cheque #'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Balance Calculation
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Remaining Outstanding Balance:'),
                    Text(
                      MoneyCalculator.formatCurrency(_balance),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '* Note: A 4-stage installment schedule will automatically be registered for this booking.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Special Terms / Remarks'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Confirm Booking'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            if (_selectedPlotId == null || _selectedCustomerId == null || _selectedAccountId == null) return;

            final now = DateTime.now();
            final advance = double.parse(_advanceCtrl.text.trim());
            final remaining = _totalPlotValue - advance;

            // Generate 4-part installment schedule
            final m1 = remaining * 0.3;
            final m2 = remaining * 0.3;
            final m3 = remaining - m1 - m2;

            final installments = [
              {
                'installmentNumber': 1,
                'title': 'Booking Advance',
                'dueDate': now,
                'amount': advance,
              },
              {
                'installmentNumber': 2,
                'title': 'Agreement & Legal Documentation',
                'dueDate': now.add(const Duration(days: 30)),
                'amount': m1,
              },
              {
                'installmentNumber': 3,
                'title': 'Plantation & Drip Infrastructure Milestone',
                'dueDate': now.add(const Duration(days: 90)),
                'amount': m2,
              },
              {
                'installmentNumber': 4,
                'title': 'Possession & Registration',
                'dueDate': now.add(const Duration(days: 180)),
                'amount': m3,
              },
            ];

            Navigator.of(context).pop({
              'bookingNumber': _bookingNumCtrl.text.trim(),
              'plotId': _selectedPlotId,
              'customerId': _selectedCustomerId,
              'totalPlotValue': _totalPlotValue,
              'bookingAmount': advance,
              'paymentAccountId': _selectedAccountId,
              'paymentMode': _paymentMode,
              'referenceNo': _refNoCtrl.text.trim().isEmpty ? null : _refNoCtrl.text.trim(),
              'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
              'installments': installments,
            });
          },
        ),
      ],
    );
  }
}

