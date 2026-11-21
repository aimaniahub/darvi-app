import 'package:flutter/material.dart';

import '../../../../core/utils/money_calculator.dart';
import '../../../../data/local/db/app_database.dart';

class QuotationEditorDialog extends StatefulWidget {
  const QuotationEditorDialog({
    super.key,
    required this.customers,
    required this.leads,
    required this.products,
    required this.plots,
    this.preselectedPlot,
    this.preselectedLead,
  });

  final List<dynamic> customers;
  final List<Lead> leads;
  final List<dynamic> products;
  final List<Plot> plots;
  final Plot? preselectedPlot;
  final Lead? preselectedLead;

  @override
  State<QuotationEditorDialog> createState() => _QuotationEditorDialogState();
}

class _QuotationEditorDialogState extends State<QuotationEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _quoteNumCtrl;
  late final TextEditingController _custNameCtrl;
  late final TextEditingController _custPhoneCtrl;
  late final TextEditingController _termsCtrl;
  late final TextEditingController _notesCtrl;

  int? _customerId;
  int? _leadId;
  DateTime _validUntil = DateTime.now().add(const Duration(days: 15));

  final List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _quoteNumCtrl = TextEditingController(text: 'QT-${now.year}-${now.millisecondsSinceEpoch.toString().substring(8)}');
    _custNameCtrl = TextEditingController(text: widget.preselectedLead?.name ?? '');
    _custPhoneCtrl = TextEditingController(text: widget.preselectedLead?.phone ?? '');
    _termsCtrl = TextEditingController(
      text: '1. Quotation valid for 15 days.\n2. 20% advance required upon confirmation.\n3. Subject to Hubli jurisdiction.',
    );
    _notesCtrl = TextEditingController();
    _leadId = widget.preselectedLead?.id;

    if (widget.preselectedPlot != null) {
      final p = widget.preselectedPlot!;
      _items.add({
        'itemType': 'plot',
        'referenceId': p.id,
        'description': 'Vikshha Plot ${p.uniquePlotId} (${p.dimensions}, ${p.areaSqFt.toStringAsFixed(0)} Sq.Ft.)',
        'quantity': 1.0,
        'unitPrice': p.totalPrice,
        'discount': 0.0,
        'gstRate': 0.0,
        'total': p.totalPrice,
      });
    }
  }

  void _addItemDialog() async {
    String type = 'product';
    int? refId;
    final descCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: '0');
    final discCtrl = TextEditingController(text: '0');
    final gstCtrl = TextEditingController(text: '0');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Add Quotation Line Item'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(labelText: 'Item Type'),
                      items: const [
                        DropdownMenuItem(value: 'product', child: Text('Agri Product')),
                        DropdownMenuItem(value: 'plot', child: Text('Vikshha Plot')),
                        DropdownMenuItem(value: 'service', child: Text('Farm Management Service')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setLocal(() {
                            type = val;
                            refId = null;
                            descCtrl.clear();
                            priceCtrl.text = '0';
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    if (type == 'product') ...[
                      DropdownButtonFormField<int?>(
                        value: refId,
                        decoration: const InputDecoration(labelText: 'Select Product'),
                        items: widget.products.map<DropdownMenuItem<int?>>((p) {
                          return DropdownMenuItem<int?>(
                            value: p.id as int,
                            child: Text('${p.name} (₹${p.price})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final p = widget.products.firstWhere((e) => e.id == val);
                            setLocal(() {
                              refId = val;
                              descCtrl.text = p.name as String;
                              priceCtrl.text = (p.price as num).toString();
                              gstCtrl.text = ((p.gstRate as num?) ?? 0.0).toString();
                            });
                          }
                        },
                      ),
                    ] else if (type == 'plot') ...[
                      DropdownButtonFormField<int?>(
                        value: refId,
                        decoration: const InputDecoration(labelText: 'Select Plot'),
                        items: widget.plots.map((p) {
                          return DropdownMenuItem<int?>(
                            value: p.id,
                            child: Text('${p.uniquePlotId} - ${p.dimensions} (₹${p.totalPrice})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final p = widget.plots.firstWhere((e) => e.id == val);
                            setLocal(() {
                              refId = val;
                              descCtrl.text = 'Vikshha Plot ${p.uniquePlotId} (${p.dimensions})';
                              priceCtrl.text = p.totalPrice.toStringAsFixed(0);
                              gstCtrl.text = '0';
                            });
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Item Description *'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Qty'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Unit Price (₹)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: discCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Discount (₹)'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: gstCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'GST %'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final desc = descCtrl.text.trim();
                  if (desc.isEmpty) return;
                  final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                  final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                  final disc = double.tryParse(discCtrl.text.trim()) ?? 0.0;
                  final gst = double.tryParse(gstCtrl.text.trim()) ?? 0.0;

                  final lineBase = (qty * price) - disc;
                  final tax = lineBase * (gst / 100);
                  final total = lineBase + tax;

                  setState(() {
                    _items.add({
                      'itemType': type,
                      'referenceId': refId,
                      'description': desc,
                      'quantity': qty,
                      'unitPrice': price,
                      'discount': disc,
                      'gstRate': gst,
                      'total': total,
                    });
                  });
                  Navigator.of(ctx).pop();
                },
                child: const Text('Add Item'),
              ),
            ],
          );
        },
      ),
    );
  }

  double get _subtotal => _items.fold(0.0, (sum, i) => sum + ((i['quantity'] as num).toDouble() * (i['unitPrice'] as num).toDouble()));
  double get _discountTotal => _items.fold(0.0, (sum, i) => sum + (i['discount'] as num).toDouble());
  double get _taxTotal {
    double tax = 0.0;
    for (final i in _items) {
      final base = ((i['quantity'] as num).toDouble() * (i['unitPrice'] as num).toDouble()) - (i['discount'] as num).toDouble();
      tax += base * ((i['gstRate'] as num).toDouble() / 100);
    }
    return tax;
  }
  double get _grandTotal => _subtotal - _discountTotal + _taxTotal;

  @override
  void dispose() {
    _quoteNumCtrl.dispose();
    _custNameCtrl.dispose();
    _custPhoneCtrl.dispose();
    _termsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.request_quote, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          const Text('Create Official Quotation'),
        ],
      ),
      content: SizedBox(
        width: 600,
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
                        controller: _quoteNumCtrl,
                        decoration: const InputDecoration(labelText: 'Quotation No. *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Valid Until: ${_validUntil.toLocal().toString().substring(0, 10)}', style: const TextStyle(fontSize: 13)),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_month),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _validUntil,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 180)),
                            );
                            if (picked != null) setState(() => _validUntil = picked);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _custNameCtrl,
                        decoration: const InputDecoration(labelText: 'Client Name *', prefixIcon: Icon(Icons.person)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _custPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Client Phone *', prefixIcon: Icon(Icons.phone)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Line Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Item'),
                      onPressed: _addItemDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text('No line items added yet. Click "+ Add Item" above.'),
                  )
                else
                  ..._items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final itm = entry.value;
                    return Card(
                      elevation: 0,
                      color: Colors.grey.shade100,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        title: Text(itm['description'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Qty: ${itm['quantity']} × ₹${itm['unitPrice']} • Disc: ₹${itm['discount']} • GST: ${itm['gstRate']}%'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              MoneyCalculator.formatCurrency((itm['total'] as num).toDouble()),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              onPressed: () => setState(() => _items.removeAt(idx)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                // Summary preview
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 260,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Subtotal: ${MoneyCalculator.formatCurrency(_subtotal)}', style: const TextStyle(fontSize: 12)),
                        if (_discountTotal > 0)
                          Text('Discount: -${MoneyCalculator.formatCurrency(_discountTotal)}', style: const TextStyle(fontSize: 12, color: Colors.red)),
                        if (_taxTotal > 0)
                          Text('GST Total: +${MoneyCalculator.formatCurrency(_taxTotal)}', style: const TextStyle(fontSize: 12)),
                        const Divider(height: 12),
                        Text(
                          'Grand Total: ${MoneyCalculator.formatCurrency(_grandTotal)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).primaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _termsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Terms & Conditions'),
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
          label: const Text('Save Quotation'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            if (_items.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please add at least one line item.')),
              );
              return;
            }

            final cgst = _taxTotal / 2;
            final sgst = _taxTotal / 2;

            Navigator.of(context).pop({
              'quotationNumber': _quoteNumCtrl.text.trim(),
              'customerId': _customerId,
              'leadId': _leadId,
              'customerName': _custNameCtrl.text.trim(),
              'customerPhone': _custPhoneCtrl.text.trim(),
              'validUntil': _validUntil,
              'subtotal': _subtotal,
              'discountTotal': _discountTotal,
              'taxTotal': _taxTotal,
              'cgstTotal': cgst,
              'sgstTotal': sgst,
              'igstTotal': 0.0,
              'totalAmount': _grandTotal,
              'status': 'draft',
              'terms': _termsCtrl.text.trim(),
              'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
              'items': _items,
            });
          },
        ),
      ],
    );
  }
}

