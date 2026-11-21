import 'package:flutter/material.dart';

import '../../../../data/local/db/app_database.dart';

class SiteVisitDialog extends StatefulWidget {
  const SiteVisitDialog({
    super.key,
    required this.lead,
    required this.projects,
    required this.employees,
  });

  final Lead lead;
  final List<Project> projects;
  final List<dynamic> employees;

  @override
  State<SiteVisitDialog> createState() => _SiteVisitDialogState();
}

class _SiteVisitDialogState extends State<SiteVisitDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _projectId;
  int? _conductedByEmployeeId;
  DateTime _scheduledDate = DateTime.now().add(const Duration(days: 1, hours: 2));
  final _feedbackCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _projectId = widget.lead.interestedProjectId ?? (widget.projects.isNotEmpty ? widget.projects.first.id : null);
    _conductedByEmployeeId = widget.lead.assignedEmployeeId ?? (widget.employees.isNotEmpty ? widget.employees.first.id : null);
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.directions_walk, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          const Text('Schedule Farmland Site Visit'),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Investor: ${widget.lead.name} (${widget.lead.phone})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int?>(
                value: _projectId,
                decoration: const InputDecoration(labelText: 'Project / Property', prefixIcon: Icon(Icons.apartment)),
                items: widget.projects.map<DropdownMenuItem<int?>>((p) => DropdownMenuItem<int?>(value: p.id as int?, child: Text('${p.name} (${p.code})'))).toList(),
                onChanged: (val) => setState(() => _projectId = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _conductedByEmployeeId,
                decoration: const InputDecoration(labelText: 'Accompanying Executive', prefixIcon: Icon(Icons.badge)),
                items: widget.employees.map<DropdownMenuItem<int?>>((e) => DropdownMenuItem<int?>(value: e.id as int?, child: Text('${e.name} (${e.role})'))).toList(),
                onChanged: (val) => setState(() => _conductedByEmployeeId = val),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available),
                title: Text('Date: ${_scheduledDate.toLocal().toString().substring(0, 16)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _scheduledDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (pickedDate != null && context.mounted) {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_scheduledDate),
                      );
                      if (pickedTime != null) {
                        setState(() {
                          _scheduledDate = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _feedbackCtrl,
                decoration: const InputDecoration(
                  labelText: 'Instructions / Vehicle details',
                  hintText: 'e.g. Pick-up at Hubli Airport road office at 9:30 AM',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.schedule),
          label: const Text('Confirm Schedule'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop({
              'leadId': widget.lead.id,
              'projectId': _projectId,
              'conductedByEmployeeId': _conductedByEmployeeId,
              'scheduledDate': _scheduledDate,
              'feedback': _feedbackCtrl.text.trim().isEmpty ? null : _feedbackCtrl.text.trim(),
            });
          },
        ),
      ],
    );
  }
}
