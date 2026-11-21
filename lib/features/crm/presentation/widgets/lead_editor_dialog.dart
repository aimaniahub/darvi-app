import 'package:flutter/material.dart';

import '../../../../data/local/db/app_database.dart';

class LeadEditorDialog extends StatefulWidget {
  const LeadEditorDialog({
    super.key,
    required this.projects,
    required this.employees,
    this.lead,
    this.onDuplicateCheck,
  });

  final List<Project> projects;
  final List<dynamic> employees;
  final Lead? lead;
  final Future<dynamic> Function(String phone, {int? excludeId})? onDuplicateCheck;

  @override
  State<LeadEditorDialog> createState() => _LeadEditorDialogState();
}

class _LeadEditorDialogState extends State<LeadEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _altPhoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _districtCtrl;
  late final TextEditingController _budgetCtrl;
  late final TextEditingController _plotSizeCtrl;
  late final TextEditingController _reqCtrl;
  late final TextEditingController _notesCtrl;

  String _source = 'Walk-in';
  String _stage = 'new';
  String _priority = 'medium';
  int? _interestedProjectId;
  int? _assignedEmployeeId;
  DateTime? _followUpDate;
  String? _duplicateWarning;

  static const _sources = [
    'Walk-in',
    'Phone Enquiry',
    'Referral',
    'Digital Ads',
    'Agri Expo',
    'Website',
    'Other',
  ];

  static const _stages = [
    'new',
    'contacted',
    'interested',
    'site_visit',
    'negotiation',
    'converted',
    'lost',
  ];

  static const _priorities = [
    'low',
    'medium',
    'high',
    'urgent',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.lead?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.lead?.phone ?? '');
    _altPhoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController(text: widget.lead?.email ?? '');
    _addressCtrl = TextEditingController();
    _cityCtrl = TextEditingController();
    _districtCtrl = TextEditingController();
    _budgetCtrl = TextEditingController(
      text: widget.lead != null && widget.lead!.budget > 0 ? widget.lead!.budget.toStringAsFixed(0) : '',
    );
    _plotSizeCtrl = TextEditingController();
    _reqCtrl = TextEditingController(text: widget.lead?.requirements ?? '');
    _notesCtrl = TextEditingController(text: widget.lead?.notes ?? '');

    _source = widget.lead?.source ?? 'Walk-in';
    _stage = widget.lead?.stage ?? 'new';
    _interestedProjectId = widget.lead?.interestedProjectId;
    _assignedEmployeeId = widget.lead?.assignedEmployeeId;
    _followUpDate = widget.lead?.nextFollowUpDate;
  }

  void _checkDuplicate(String val) async {
    if (widget.onDuplicateCheck == null) return;
    final clean = val.trim();
    if (clean.length >= 10) {
      final duplicate = await widget.onDuplicateCheck!(clean, excludeId: widget.lead?.id);
      if (mounted) {
        setState(() {
          if (duplicate != null) {
            _duplicateWarning = 'Warning: Lead already exists with this phone (${duplicate.name})';
          } else {
            _duplicateWarning = null;
          }
        });
      }
    } else {
      if (_duplicateWarning != null) {
        setState(() => _duplicateWarning = null);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _altPhoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _budgetCtrl.dispose();
    _plotSizeCtrl.dispose();
    _reqCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.lead != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.person_add_alt_1, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(isEdit ? 'Edit Farmland Lead' : 'Register New Farmland Lead'),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_duplicateWarning != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _duplicateWarning!,
                            style: const TextStyle(color: Colors.brown, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Investor Name *', prefixIcon: Icon(Icons.person)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone No. *', prefixIcon: Icon(Icons.phone)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        onChanged: _checkDuplicate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _altPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Alternate Phone', prefixIcon: Icon(Icons.phone_android)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _source,
                        decoration: const InputDecoration(labelText: 'Lead Source'),
                        items: _sources.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _source = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _priority,
                        decoration: const InputDecoration(labelText: 'Priority Level'),
                        items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _priority = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: _interestedProjectId,
                        decoration: const InputDecoration(labelText: 'Interested Project'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Any Project')),
                          ...widget.projects.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.code})'))),
                        ],
                        onChanged: (val) => setState(() => _interestedProjectId = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _plotSizeCtrl,
                        decoration: const InputDecoration(labelText: 'Interested Plot Size', hintText: 'e.g. 2400 sq ft / 0.5 acre'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _budgetCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Budget (₹)', hintText: '1500000', prefixIcon: Icon(Icons.currency_rupee)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _stage,
                        decoration: const InputDecoration(labelText: 'CRM Stage'),
                        items: _stages.map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _stage = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityCtrl,
                        decoration: const InputDecoration(labelText: 'City', prefixIcon: Icon(Icons.location_city)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _districtCtrl,
                        decoration: const InputDecoration(labelText: 'District / State', prefixIcon: Icon(Icons.map)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(labelText: 'Residential / Business Address', prefixIcon: Icon(Icons.home)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: _assignedEmployeeId,
                  decoration: const InputDecoration(labelText: 'Assigned Executive'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Unassigned')),
                    ...widget.employees.map((e) => DropdownMenuItem(value: e.id, child: Text('${e.name} (${e.designation})'))),
                  ],
                  onChanged: (val) => setState(() => _assignedEmployeeId = val),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text(
                    _followUpDate != null
                        ? 'Next Follow-up: ${_followUpDate!.toLocal().toString().substring(0, 10)}'
                        : 'Set Next Follow-up Date',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_month),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _followUpDate ?? DateTime.now().add(const Duration(days: 2)),
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _followUpDate = picked);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reqCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Requirements & Preferences',
                    hintText: 'e.g. 2400 sq ft, Sandalwood plantation, corner plot',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Interaction Notes',
                    hintText: 'Caller discussion details, preferred contact time',
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
          label: Text(isEdit ? 'Update Lead' : 'Save Lead'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final data = {
              'id': widget.lead?.id,
              'name': _nameCtrl.text.trim(),
              'phone': _phoneCtrl.text.trim(),
              'alternatePhone': _altPhoneCtrl.text.trim().isEmpty ? null : _altPhoneCtrl.text.trim(),
              'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
              'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
              'city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
              'district': _districtCtrl.text.trim().isEmpty ? null : _districtCtrl.text.trim(),
              'source': _source,
              'priority': _priority,
              'interestedProjectId': _interestedProjectId,
              'interestedPlotSize': _plotSizeCtrl.text.trim().isEmpty ? null : _plotSizeCtrl.text.trim(),
              'budget': double.tryParse(_budgetCtrl.text.trim()) ?? 0.0,
              'requirements': _reqCtrl.text.trim().isEmpty ? null : _reqCtrl.text.trim(),
              'stage': _stage,
              'assignedEmployeeId': _assignedEmployeeId,
              'nextFollowUpDate': _followUpDate,
              'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            };
            Navigator.of(context).pop(data);
          },
        ),
      ],
    );
  }
}
