import 'package:flutter/material.dart';

import '../../../../core/utils/money_calculator.dart';
import '../../../../data/local/db/app_database.dart';
import '../../../../domain/repositories/repositories.dart';

class LeadDetailSheet extends StatefulWidget {
  const LeadDetailSheet({
    super.key,
    required this.lead,
    required this.project,
    required this.employee,
    required this.crmRepository,
    required this.onEdit,
    required this.onStageChanged,
    required this.onScheduleVisit,
    required this.onConvertToCustomer,
    required this.onCreateQuotation,
    this.onDelete,
    this.onFollowUpUpdated,
  });

  final Lead lead;
  final Project? project;
  final dynamic employee;
  final CrmRepository crmRepository;
  final VoidCallback onEdit;
  final ValueChanged<String> onStageChanged;
  final VoidCallback onScheduleVisit;
  final VoidCallback onConvertToCustomer;
  final VoidCallback onCreateQuotation;
  final VoidCallback? onDelete;
  final VoidCallback? onFollowUpUpdated;

  @override
  State<LeadDetailSheet> createState() => _LeadDetailSheetState();
}

class _LeadDetailSheetState extends State<LeadDetailSheet> {
  final _activityCtrl = TextEditingController();
  final _followUpRemarksCtrl = TextEditingController();
  String _activityType = 'call';

  Color _stageColor(String stage) {
    switch (stage.toLowerCase()) {
      case 'new':
        return Colors.blue;
      case 'contacted':
        return Colors.indigo;
      case 'interested':
        return Colors.teal;
      case 'site_visit':
        return Colors.orange;
      case 'negotiation':
        return Colors.deepOrange;
      case 'converted':
        return Colors.green;
      case 'lost':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _addActivity() async {
    final note = _activityCtrl.text.trim();
    if (note.isEmpty) return;
    await widget.crmRepository.logLeadActivity(
      leadId: widget.lead.id,
      employeeId: widget.employee?.id,
      activityType: _activityType,
      notes: note,
    );
    _activityCtrl.clear();
    setState(() {});
  }

  void _scheduleFollowUp() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 2)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    final scheduled = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime?.hour ?? 10,
      pickedTime?.minute ?? 0,
    );

    await widget.crmRepository.createFollowUp(
      leadId: widget.lead.id,
      employeeId: widget.employee?.id,
      scheduledDate: scheduled,
      remarks: _followUpRemarksCtrl.text.trim().isNotEmpty ? _followUpRemarksCtrl.text.trim() : 'Follow-up regarding plot inquiry',
    );
    _followUpRemarksCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Follow-up task scheduled successfully!')),
      );
      setState(() {});
      widget.onFollowUpUpdated?.call();
    }
  }

  @override
  void dispose() {
    _activityCtrl.dispose();
    _followUpRemarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stageColor = _stageColor(widget.lead.stage);

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
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: stageColor.withValues(alpha: 0.15),
                    child: Text(
                      widget.lead.name.isNotEmpty ? widget.lead.name[0].toUpperCase() : 'L',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: stageColor),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.lead.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('${widget.lead.phone} • Source: ${widget.lead.source}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                        if (widget.lead.email != null) Text(widget.lead.email!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: stageColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: stageColor),
                    ),
                    child: Text(
                      widget.lead.stage.toUpperCase(),
                      style: TextStyle(color: stageColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Overview Details Card
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _InfoCol(label: 'Budget', value: widget.lead.budget > 0 ? MoneyCalculator.formatCurrency(widget.lead.budget) : 'Not specified', isHighlight: true),
                          _InfoCol(label: 'Target Property', value: widget.project?.code ?? 'Any'),
                          _InfoCol(label: 'Assigned To', value: widget.employee?.name ?? 'Unassigned'),
                        ],
                      ),
                      if (widget.lead.nextFollowUpDate != null) ...[
                        const Divider(height: 20),
                        Row(
                          children: [
                            const Icon(Icons.alarm, size: 16, color: Colors.orange),
                            const SizedBox(width: 6),
                            Text(
                              'Next Follow-up: ${widget.lead.nextFollowUpDate!.toLocal().toString().substring(0, 10)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
                            ),
                          ],
                        ),
                      ],
                      if (widget.lead.requirements != null && widget.lead.requirements!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Requirements: ${widget.lead.requirements!}',
                            style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                          ),
                        ),
                      ],
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
                  FilledButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Convert to Customer'),
                    onPressed: widget.lead.stage == 'converted' ? null : widget.onConvertToCustomer,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event_available),
                    label: const Text('Schedule Follow-up'),
                    onPressed: _scheduleFollowUp,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.directions_walk),
                    label: const Text('Schedule Site Visit'),
                    onPressed: widget.onScheduleVisit,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.request_quote_outlined),
                    label: const Text('Send Quotation'),
                    onPressed: widget.onCreateQuotation,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                    onPressed: widget.onEdit,
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Change Stage',
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.timeline),
                      label: const Text('Stage'),
                      onPressed: null,
                    ),
                    onSelected: widget.onStageChanged,
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'new', child: Text('New')),
                      PopupMenuItem(value: 'contacted', child: Text('Contacted')),
                      PopupMenuItem(value: 'interested', child: Text('Interested')),
                      PopupMenuItem(value: 'site_visit', child: Text('Site Visit')),
                      PopupMenuItem(value: 'negotiation', child: Text('Negotiation')),
                      PopupMenuItem(value: 'converted', child: Text('Converted')),
                      PopupMenuItem(value: 'lost', child: Text('Lost')),
                    ],
                  ),
                  if (widget.onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Delete Lead',
                      onPressed: widget.onDelete,
                    ),
                ],
              ),

              const SizedBox(height: 24),
              // Scheduled Follow-ups for this lead
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Scheduled Follow-ups', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Follow-up'),
                    onPressed: _scheduleFollowUp,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: widget.crmRepository.getFollowUps(leadId: widget.lead.id),
                builder: (context, snapshot) {
                  final followUps = snapshot.data ?? [];
                  if (followUps.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Center(
                        child: Text('No active follow-ups scheduled for this lead.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ),
                    );
                  }
                  return Column(
                    children: followUps.map((f) {
                      final status = (f['status'] as String? ?? 'pending').toLowerCase();
                      final isCompleted = status == 'completed';
                      final schedDate = DateTime.fromMillisecondsSinceEpoch(f['scheduled_date'] as int);
                      final isOverdue = !isCompleted && schedDate.isBefore(DateTime.now());

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: Icon(
                            isCompleted ? Icons.check_circle : (isOverdue ? Icons.warning : Icons.alarm),
                            color: isCompleted ? Colors.green : (isOverdue ? Colors.red : Colors.orange),
                          ),
                          title: Text(
                            f['remarks']?.toString().isNotEmpty == true ? f['remarks'] as String : 'Follow-up Call',
                            style: TextStyle(
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Due: ${schedDate.toLocal().toString().substring(0, 16)} • Status: ${status.toUpperCase()}',
                            style: TextStyle(fontSize: 12, color: isOverdue ? Colors.red : Colors.grey.shade700),
                          ),
                          trailing: !isCompleted
                              ? IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  tooltip: 'Mark Complete',
                                  onPressed: () async {
                                    await widget.crmRepository.updateFollowUpStatus(
                                      f['id'] as int,
                                      'completed',
                                      remarks: 'Completed follow-up discussion',
                                    );
                                    setState(() {});
                                    widget.onFollowUpUpdated?.call();
                                  },
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 24),
              // Interaction Log / Activities
              const Text('Add Interaction Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  DropdownButton<String>(
                    value: _activityType,
                    items: const [
                      DropdownMenuItem(value: 'call', child: Text('Call')),
                      DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                      DropdownMenuItem(value: 'meeting', child: Text('Meeting')),
                      DropdownMenuItem(value: 'note', child: Text('Note')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _activityType = val);
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _activityCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Enter discussion notes...',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send, size: 18),
                    onPressed: _addActivity,
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Text('Communication History & Activity Timeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              FutureBuilder<List<LeadActivity>>(
                future: widget.crmRepository.getLeadActivities(widget.lead.id).then((l) => l.cast<LeadActivity>()),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                  }
                  final activities = snapshot.data ?? [];
                  if (activities.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Center(
                        child: Text('No previous communication history logged.', style: TextStyle(color: Colors.grey)),
                      ),
                    );
                  }
                  return Column(
                    children: activities.map((act) {
                      IconData icon = Icons.note;
                      if (act.activityType == 'call') icon = Icons.call;
                      if (act.activityType == 'whatsapp') icon = Icons.chat;
                      if (act.activityType == 'meeting') icon = Icons.groups;
                      if (act.activityType == 'site_visit') icon = Icons.directions_walk;
                      if (act.activityType == 'conversion') icon = Icons.check_circle;
                      if (act.activityType == 'follow_up_scheduled') icon = Icons.alarm;

                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.grey.shade200,
                          child: Icon(icon, size: 14, color: Colors.grey.shade800),
                        ),
                        title: Text(act.notes, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                          '${act.activityType.toUpperCase()} • ${act.createdAt.toLocal().toString().substring(0, 16)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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

class _InfoCol extends StatelessWidget {
  const _InfoCol({required this.label, required this.value, this.isHighlight = false});

  final String label;
  final String value;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isHighlight ? 15 : 13,
            color: isHighlight ? Theme.of(context).primaryColor : null,
          ),
        ),
      ],
    );
  }
}
