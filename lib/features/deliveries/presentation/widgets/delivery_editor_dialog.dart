import 'package:flutter/material.dart';

class DeliveryEditorDialog extends StatefulWidget {
  const DeliveryEditorDialog({
    super.key,
    required this.customers,
    required this.sales,
    required this.products,
    this.preselectedSaleId,
  });

  final List<dynamic> customers;
  final List<dynamic> sales;
  final List<dynamic> products;
  final int? preselectedSaleId;

  @override
  State<DeliveryEditorDialog> createState() => _DeliveryEditorDialogState();
}

class _DeliveryEditorDialogState extends State<DeliveryEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _delNumCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _transporterCtrl;
  late final TextEditingController _vehicleCtrl;
  late final TextEditingController _trackingCtrl;
  late final TextEditingController _shippingChargeCtrl;
  late final TextEditingController _notesCtrl;

  int? _customerId;
  int? _saleId;
  DateTime _dispatchDate = DateTime.now();
  DateTime _expectedDeliveryDate = DateTime.now().add(const Duration(days: 3));

  final List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _delNumCtrl = TextEditingController(text: 'DO-${now.year}-${now.millisecondsSinceEpoch.toString().substring(8)}');
    _addressCtrl = TextEditingController();
    _transporterCtrl = TextEditingController(text: 'VRL Logistics Hubli');
    _vehicleCtrl = TextEditingController();
    _trackingCtrl = TextEditingController();
    _shippingChargeCtrl = TextEditingController(text: '0');
    _notesCtrl = TextEditingController();

    _saleId = widget.preselectedSaleId;
    _customerId = widget.customers.isNotEmpty ? (widget.customers.first.id as int) : null;
    if (widget.customers.isNotEmpty) {
      _addressCtrl.text = (widget.customers.first.address as String?) ?? 'Hubli, Karnataka';
    }
  }

  void _addItemDialog() async {
    int? productId = widget.products.isNotEmpty ? (widget.products.first.id as int) : null;
    final qtyCtrl = TextEditingController(text: '1');
    String unit = 'bag';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Add Dispatch Item'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: productId,
                  decoration: const InputDecoration(labelText: 'Product *'),
                  items: widget.products.map<DropdownMenuItem<int>>((p) {
                    return DropdownMenuItem<int>(
                      value: p.id as int,
                      child: Text('${p.name} (Stock: ${p.stockQty})'),
                    );
                  }).toList(),
                  onChanged: (val) => setLocal(() => productId = val),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantity *'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: unit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: const [
                          DropdownMenuItem(value: 'bag', child: Text('Bag')),
                          DropdownMenuItem(value: 'piece', child: Text('Piece')),
                          DropdownMenuItem(value: 'box', child: Text('Box')),
                          DropdownMenuItem(value: 'kg', child: Text('Kg')),
                          DropdownMenuItem(value: 'litre', child: Text('Litre')),
                        ],
                        onChanged: (val) {
                          if (val != null) setLocal(() => unit = val);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (productId == null) return;
                  final q = int.tryParse(qtyCtrl.text.trim()) ?? 1;
                  final prod = widget.products.firstWhere((p) => p.id == productId);
                  setState(() {
                    _items.add({
                      'productId': productId,
                      'productName': prod.name,
                      'quantity': q,
                      'unit': unit,
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

  @override
  void dispose() {
    _delNumCtrl.dispose();
    _addressCtrl.dispose();
    _transporterCtrl.dispose();
    _vehicleCtrl.dispose();
    _trackingCtrl.dispose();
    _shippingChargeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.local_shipping, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          const Text('New Delivery Order'),
        ],
      ),
      content: SizedBox(
        width: 560,
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
                        controller: _delNumCtrl,
                        decoration: const InputDecoration(labelText: 'Delivery Order # *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: _saleId,
                        decoration: const InputDecoration(labelText: 'Linked Invoice (Optional)'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('None / Direct Dispatch')),
                          ...widget.sales.map((s) => DropdownMenuItem(value: s.id as int, child: Text(s.invoiceNo as String))),
                        ],
                        onChanged: (val) => setState(() => _saleId = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _customerId,
                  decoration: const InputDecoration(labelText: 'Customer / Recipient *', prefixIcon: Icon(Icons.person)),
                  items: widget.customers.map<DropdownMenuItem<int>>((c) {
                    return DropdownMenuItem<int>(
                      value: c.id as int,
                      child: Text('${c.name} (${c.phone ?? "No phone"})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _customerId = val;
                      final cust = widget.customers.firstWhere((e) => e.id == val);
                      if (cust.address != null && cust.address.isNotEmpty) {
                        _addressCtrl.text = cust.address as String;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(labelText: 'Delivery Address *', prefixIcon: Icon(Icons.location_on)),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _transporterCtrl,
                        decoration: const InputDecoration(labelText: 'Transporter Name', hintText: 'e.g. VRL Logistics'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _vehicleCtrl,
                        decoration: const InputDecoration(labelText: 'Vehicle Number', hintText: 'KA-25-EA-1234'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _trackingCtrl,
                        decoration: const InputDecoration(labelText: 'Docket / Tracking #', hintText: 'VRL12345678'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _shippingChargeCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Shipping Charges (₹)', prefixIcon: Icon(Icons.currency_rupee)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Dispatch: ${_dispatchDate.toLocal().toString().substring(0, 10)}', style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_today, size: 18),
                          onPressed: () async {
                            final p = await showDatePicker(
                              context: context,
                              initialDate: _dispatchDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 7)),
                              lastDate: DateTime.now().add(const Duration(days: 30)),
                            );
                            if (p != null) setState(() => _dispatchDate = p);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Expected: ${_expectedDeliveryDate.toLocal().toString().substring(0, 10)}', style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_month, size: 18),
                          onPressed: () async {
                            final p = await showDatePicker(
                              context: context,
                              initialDate: _expectedDeliveryDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 90)),
                            );
                            if (p != null) setState(() => _expectedDeliveryDate = p);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Dispatched Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text('No products added for dispatch. Click "+ Add Item".'),
                  )
                else
                  ..._items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final itm = entry.value;
                    return Card(
                      elevation: 0,
                      color: Colors.grey.shade100,
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        title: Text(itm['productName'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${itm['quantity']} ${itm['unit']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              onPressed: () => setState(() => _items.removeAt(idx)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Create Dispatch Order'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            if (_customerId == null) return;
            if (_items.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please add at least one product to dispatch.')),
              );
              return;
            }

            Navigator.of(context).pop({
              'deliveryNumber': _delNumCtrl.text.trim(),
              'saleId': _saleId,
              'customerId': _customerId,
              'deliveryAddress': _addressCtrl.text.trim(),
              'transporterName': _transporterCtrl.text.trim().isEmpty ? null : _transporterCtrl.text.trim(),
              'vehicleNumber': _vehicleCtrl.text.trim().isEmpty ? null : _vehicleCtrl.text.trim(),
              'trackingNumber': _trackingCtrl.text.trim().isEmpty ? null : _trackingCtrl.text.trim(),
              'shippingCharges': double.tryParse(_shippingChargeCtrl.text.trim()) ?? 0.0,
              'dispatchDate': _dispatchDate,
              'expectedDeliveryDate': _expectedDeliveryDate,
              'status': 'dispatched',
              'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
              'items': _items,
            });
          },
        ),
      ],
    );
  }
}

