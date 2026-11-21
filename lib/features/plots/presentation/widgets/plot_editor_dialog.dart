import 'package:flutter/material.dart';

import '../../../../data/local/db/app_database.dart';

class PlotEditorDialog extends StatefulWidget {
  const PlotEditorDialog({
    super.key,
    required this.projects,
    this.plot,
    this.initialProjectId,
  });

  final List<Project> projects;
  final Plot? plot;
  final int? initialProjectId;

  @override
  State<PlotEditorDialog> createState() => _PlotEditorDialogState();
}

class _PlotEditorDialogState extends State<PlotEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late int _selectedProjectId;
  late final TextEditingController _plotNumCtrl;
  late final TextEditingController _uniqueIdCtrl;
  late final TextEditingController _dimCtrl;
  late final TextEditingController _areaCtrl;
  late final TextEditingController _surveyCtrl;
  late final TextEditingController _basePriceCtrl;
  late final TextEditingController _totalPriceCtrl;
  late final TextEditingController _cropCtrl;
  late final TextEditingController _plantationCtrl;
  late final TextEditingController _notesCtrl;
  String _status = 'available';
  String _facing = 'East';

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.plot?.projectId ?? widget.initialProjectId ?? widget.projects.first.id;
    _plotNumCtrl = TextEditingController(text: widget.plot?.plotNumber ?? '');
    _uniqueIdCtrl = TextEditingController(text: widget.plot?.uniquePlotId ?? '');
    _dimCtrl = TextEditingController(text: widget.plot?.dimensions ?? '40 x 60 ft');
    _areaCtrl = TextEditingController(text: widget.plot != null ? widget.plot!.areaSqFt.toStringAsFixed(0) : '2400');
    _surveyCtrl = TextEditingController(text: widget.plot?.surveyNumber ?? '');
    _basePriceCtrl = TextEditingController(text: widget.plot != null ? widget.plot!.basePrice.toStringAsFixed(0) : '500');
    _totalPriceCtrl = TextEditingController(text: widget.plot != null ? widget.plot!.totalPrice.toStringAsFixed(0) : '1200000');
    _cropCtrl = TextEditingController(text: widget.plot?.cropType ?? 'Sandalwood & Mahogany');
    _plantationCtrl = TextEditingController(text: widget.plot?.plantationDetails ?? 'Automated drip irrigation');
    _notesCtrl = TextEditingController(text: widget.plot?.notes ?? '');
    _status = widget.plot?.status ?? 'available';
    _facing = 'East';

    _areaCtrl.addListener(_recalculateTotal);
    _basePriceCtrl.addListener(_recalculateTotal);
    _plotNumCtrl.addListener(_autoGenerateUniqueId);
  }

  void _autoGenerateUniqueId() {
    if (widget.plot != null) return; // Do not overwrite on edit
    final project = widget.projects.firstWhere(
      (p) => p.id == _selectedProjectId,
      orElse: () => widget.projects.first,
    );
    final numStr = _plotNumCtrl.text.trim().replaceAll(' ', '-').toUpperCase();
    if (numStr.isNotEmpty) {
      _uniqueIdCtrl.text = '${project.code}-$numStr';
    }
  }

  void _recalculateTotal() {
    final area = double.tryParse(_areaCtrl.text.trim()) ?? 0.0;
    final basePrice = double.tryParse(_basePriceCtrl.text.trim()) ?? 0.0;
    final total = area * basePrice;
    _totalPriceCtrl.text = total.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _areaCtrl.removeListener(_recalculateTotal);
    _basePriceCtrl.removeListener(_recalculateTotal);
    _plotNumCtrl.removeListener(_autoGenerateUniqueId);
    _plotNumCtrl.dispose();
    _uniqueIdCtrl.dispose();
    _dimCtrl.dispose();
    _areaCtrl.dispose();
    _surveyCtrl.dispose();
    _basePriceCtrl.dispose();
    _totalPriceCtrl.dispose();
    _cropCtrl.dispose();
    _plantationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.plot != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.landscape, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(isEdit ? 'Edit Farmland Plot' : 'Register New Farmland Plot'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _selectedProjectId,
                  decoration: const InputDecoration(labelText: 'Project *', prefixIcon: Icon(Icons.apartment)),
                  items: widget.projects.map((p) {
                    return DropdownMenuItem<int>(
                      value: p.id,
                      child: Text('${p.name} (${p.code})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedProjectId = val;
                        _autoGenerateUniqueId();
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _plotNumCtrl,
                        decoration: const InputDecoration(labelText: 'Plot No. *', hintText: 'e.g. A-15'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _uniqueIdCtrl,
                        decoration: const InputDecoration(labelText: 'Unique Plot ID *', hintText: 'e.g. VK-P1-A15'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dimCtrl,
                        decoration: const InputDecoration(labelText: 'Dimensions *', hintText: 'e.g. 40 x 60 ft'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _areaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Area (Sq. Ft.) *', hintText: '2400'),
                        validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid area' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _basePriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Rate (₹ / Sq.Ft.) *', hintText: '500'),
                        validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid rate' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _totalPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Total Valuation (₹) *', hintText: '1200000'),
                        validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid valuation' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _surveyCtrl,
                        decoration: const InputDecoration(labelText: 'Survey No.', hintText: 'e.g. Sy No 142/2A'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(value: 'available', child: Text('Available')),
                          DropdownMenuItem(value: 'reserved', child: Text('Reserved')),
                          DropdownMenuItem(value: 'booked', child: Text('Booked')),
                          DropdownMenuItem(value: 'sold', child: Text('Sold')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _status = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _facing,
                        decoration: const InputDecoration(labelText: 'Plot Facing Direction'),
                        items: const [
                          DropdownMenuItem(value: 'East', child: Text('East Facing')),
                          DropdownMenuItem(value: 'North', child: Text('North Facing')),
                          DropdownMenuItem(value: 'West', child: Text('West Facing')),
                          DropdownMenuItem(value: 'South', child: Text('South Facing')),
                          DropdownMenuItem(value: 'North-East', child: Text('North-East Corner')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _facing = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cropCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Crop & Agro-Forestry Type',
                    hintText: 'e.g. Sandalwood, Mahogany, Organic Kesar Mango',
                    prefixIcon: Icon(Icons.park),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _plantationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Plantation & Irrigation Details',
                    hintText: 'e.g. 25 trees planted, automated drip network',
                    prefixIcon: Icon(Icons.water_drop),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Remarks',
                    hintText: 'Plot orientation, special terms, etc.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: Text(isEdit ? 'Update Plot' : 'Save Plot'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final data = {
              'id': widget.plot?.id,
              'projectId': _selectedProjectId,
              'plotNumber': _plotNumCtrl.text.trim(),
              'uniquePlotId': _uniqueIdCtrl.text.trim(),
              'dimensions': _dimCtrl.text.trim(),
              'areaSqFt': double.parse(_areaCtrl.text.trim()),
              'surveyNumber': _surveyCtrl.text.trim().isEmpty ? null : _surveyCtrl.text.trim(),
              'facing': _facing,
              'pricePerSqFt': double.tryParse(_basePriceCtrl.text.trim()) ?? 0.0,
              'status': _status,
              'basePrice': double.parse(_basePriceCtrl.text.trim()),
              'totalPrice': double.parse(_totalPriceCtrl.text.trim()),
              'cropType': _cropCtrl.text.trim().isEmpty ? null : _cropCtrl.text.trim(),
              'plantationDetails': _plantationCtrl.text.trim().isEmpty ? null : _plantationCtrl.text.trim(),
              'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            };
            Navigator.of(context).pop(data);
          },
        ),
      ],
    );
  }
}

