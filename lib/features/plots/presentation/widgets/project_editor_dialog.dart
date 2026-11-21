import 'package:flutter/material.dart';

import '../../../../data/local/db/app_database.dart';

class ProjectEditorDialog extends StatefulWidget {
  const ProjectEditorDialog({super.key, this.project});

  final Project? project;

  @override
  State<ProjectEditorDialog> createState() => _ProjectEditorDialogState();
}

class _ProjectEditorDialogState extends State<ProjectEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _locCtrl;
  late final TextEditingController _areaCtrl;
  late final TextEditingController _plotsCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _amenitiesCtrl;
  late final TextEditingController _gpsCtrl;

  String _legalStatus = 'clear_title';
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.project?.name ?? '');
    _codeCtrl = TextEditingController(text: widget.project?.code ?? '');
    _locCtrl = TextEditingController(text: widget.project?.location ?? '');
    _areaCtrl = TextEditingController(text: widget.project != null && widget.project!.totalArea > 0 ? widget.project!.totalArea.toString() : '');
    _plotsCtrl = TextEditingController(text: widget.project != null && widget.project!.totalPlots > 0 ? widget.project!.totalPlots.toString() : '');
    _descCtrl = TextEditingController(text: widget.project?.description ?? '');
    _amenitiesCtrl = TextEditingController();
    _gpsCtrl = TextEditingController();
    _status = widget.project?.status ?? 'active';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _locCtrl.dispose();
    _areaCtrl.dispose();
    _plotsCtrl.dispose();
    _descCtrl.dispose();
    _amenitiesCtrl.dispose();
    _gpsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.project != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.business, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(isEdit ? 'Edit Property / Project' : 'New Property / Project'),
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
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Project Name *', hintText: 'Vikshha Agro Farmland - Phase 1'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codeCtrl,
                        decoration: const InputDecoration(labelText: 'Project Code *', hintText: 'VK-P1'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _plotsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Total Plots', hintText: '40'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _areaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Total Area (Acres)', hintText: '25.0'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _legalStatus,
                        decoration: const InputDecoration(labelText: 'Legal Title Status'),
                        items: const [
                          DropdownMenuItem(value: 'clear_title', child: Text('Clear Title (Approved)')),
                          DropdownMenuItem(value: 'under_process', child: Text('Under Process')),
                          DropdownMenuItem(value: 'na_converted', child: Text('NA Converted')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _legalStatus = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locCtrl,
                  decoration: const InputDecoration(labelText: 'Location & Address *', hintText: 'Gokul Road, Hubli'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amenitiesCtrl,
                        decoration: const InputDecoration(labelText: 'Amenities', hintText: 'Drip irrigation, Clubhouse, 30ft road'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _gpsCtrl,
                        decoration: const InputDecoration(labelText: 'GPS Coordinates', hintText: '15.3647° N, 75.1240° E'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description / Highlights', hintText: 'Sandalwood & agro-forestry estate'),
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
          label: Text(isEdit ? 'Update Project' : 'Create Project'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final data = {
              'id': widget.project?.id,
              'name': _nameCtrl.text.trim(),
              'code': _codeCtrl.text.trim().toUpperCase(),
              'location': _locCtrl.text.trim(),
              'totalArea': double.tryParse(_areaCtrl.text.trim()) ?? 0.0,
              'totalPlots': int.tryParse(_plotsCtrl.text.trim()) ?? 0,
              'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
              'amenities': _amenitiesCtrl.text.trim().isEmpty ? null : _amenitiesCtrl.text.trim(),
              'legalStatus': _legalStatus,
              'address': _locCtrl.text.trim(),
              'gpsCoordinates': _gpsCtrl.text.trim().isEmpty ? null : _gpsCtrl.text.trim(),
              'status': _status,
            };
            Navigator.of(context).pop(data);
          },
        ),
      ],
    );
  }
}

