import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/money_calculator.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/local/db/app_database.dart';
import '../cubit/crm_cubit.dart';
import '../widgets/lead_detail_sheet.dart';
import '../widgets/lead_editor_dialog.dart';
import '../widgets/site_visit_dialog.dart';

class CrmPage extends StatelessWidget {
  const CrmPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    return BlocProvider(
      create: (context) => CrmCubit(
        crmRepository: deps.crmRepository,
        employeeRepository: deps.employeeRepository,
        plotRepository: deps.plotRepository,
      )..load(),
      child: const _CrmView(),
    );
  }
}

class _CrmView extends StatefulWidget {
  const _CrmView();

  @override
  State<_CrmView> createState() => _CrmViewState();
}

class _CrmViewState extends State<_CrmView> {
  final _searchCtrl = TextEditingController();

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

  void _openLeadEditor(BuildContext context, {Lead? lead}) async {
    final cubit = context.read<CrmCubit>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => LeadEditorDialog(
        projects: cubit.state.projects,
        employees: cubit.state.employees,
        lead: lead,
        onDuplicateCheck: (phone, {excludeId}) => cubit.checkDuplicatePhone(phone, excludeId: excludeId),
      ),
    );

    if (result != null) {
      await cubit.saveLead(
        id: result['id'] as int?,
        name: result['name'] as String,
        phone: result['phone'] as String,
        alternatePhone: result['alternatePhone'] as String?,
        email: result['email'] as String?,
        address: result['address'] as String?,
        city: result['city'] as String?,
        district: result['district'] as String?,
        source: result['source'] as String? ?? 'Walk-in',
        priority: result['priority'] as String? ?? 'medium',
        interestedProjectId: result['interestedProjectId'] as int?,
        interestedPlotSize: result['interestedPlotSize'] as String?,
        budget: result['budget'] as double? ?? 0.0,
        requirements: result['requirements'] as String?,
        stage: result['stage'] as String? ?? 'new',
        assignedEmployeeId: result['assignedEmployeeId'] as int?,
        nextFollowUpDate: result['nextFollowUpDate'] as DateTime?,
        notes: result['notes'] as String?,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lead != null ? 'Lead updated!' : 'Lead registered!')),
        );
      }
    }
  }

  void _openSiteVisitDialog(BuildContext context, Lead lead) async {
    final cubit = context.read<CrmCubit>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SiteVisitDialog(
        lead: lead,
        projects: cubit.state.projects,
        employees: cubit.state.employees,
      ),
    );

    if (result != null) {
      await cubit.scheduleSiteVisit(
        leadId: result['leadId'] as int,
        projectId: result['projectId'] as int?,
        scheduledDate: result['scheduledDate'] as DateTime,
        conductedByEmployeeId: result['conductedByEmployeeId'] as int?,
        feedback: result['feedback'] as String?,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Site visit scheduled successfully!')),
        );
      }
    }
  }

  void _showFollowUpsDialog(BuildContext context) {
    final cubit = context.read<CrmCubit>();
    showDialog(
      context: context,
      builder: (ctx) {
        final followUps = cubit.state.followUps;
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.alarm, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Follow-up Tasks (${followUps.length})'),
            ],
          ),
          content: SizedBox(
            width: 520,
            height: 400,
            child: followUps.isEmpty
                ? const Center(child: Text('No follow-up tasks recorded.'))
                : ListView.builder(
                    itemCount: followUps.length,
                    itemBuilder: (context, i) {
                      final f = followUps[i];
                      final status = (f['status'] as String? ?? 'pending').toLowerCase();
                      final isCompleted = status == 'completed';
                      final sched = DateTime.fromMillisecondsSinceEpoch(f['scheduled_date'] as int);
                      final isOverdue = !isCompleted && sched.isBefore(DateTime.now());

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            isCompleted ? Icons.check_circle : (isOverdue ? Icons.warning : Icons.alarm),
                            color: isCompleted ? Colors.green : (isOverdue ? Colors.red : Colors.orange),
                          ),
                          title: Text(
                            f['lead_name']?.toString() ?? 'Lead Follow-up',
                            style: TextStyle(
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Due: ${sched.toLocal().toString().substring(0, 16)}\nRemarks: ${f['remarks'] ?? 'N/A'}',
                          ),
                          isThreeLine: true,
                          trailing: !isCompleted
                              ? IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  tooltip: 'Mark Complete',
                                  onPressed: () async {
                                    await cubit.updateFollowUpStatus(f['id'] as int, 'completed');
                                    Navigator.of(ctx).pop();
                                  },
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showLeadDetails(BuildContext context, Lead lead) {
    final cubit = context.read<CrmCubit>();
    final deps = AppScope.of(context);

    final project = cubit.state.projects.where((p) => p.id == lead.interestedProjectId).firstOrNull;
    final employee = cubit.state.employees.where((e) => e.id == lead.assignedEmployeeId).firstOrNull;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => LeadDetailSheet(
        lead: lead,
        project: project,
        employee: employee,
        crmRepository: deps.crmRepository,
        onEdit: () {
          Navigator.of(ctx).pop();
          _openLeadEditor(context, lead: lead);
        },
        onStageChanged: (newStage) {
          Navigator.of(ctx).pop();
          cubit.updateStage(lead.id, newStage);
        },
        onScheduleVisit: () {
          Navigator.of(ctx).pop();
          _openSiteVisitDialog(context, lead);
        },
        onConvertToCustomer: () async {
          Navigator.of(ctx).pop();
          final custId = await cubit.convertToCustomer(lead.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lead converted to Customer #$custId!')),
            );
          }
        },
        onCreateQuotation: () {
          Navigator.of(ctx).pop();
          context.push('/quotations', extra: {'preselectedLead': lead});
        },
        onDelete: () async {
          Navigator.of(ctx).pop();
          final confirm = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Delete Lead'),
              content: Text('Are you sure you want to delete lead "${lead.name}"?'),
              actions: [
                TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.of(c).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await cubit.deleteLead(lead.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lead deleted successfully')),
              );
            }
          }
        },
        onFollowUpUpdated: () => cubit.load(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Farmland CRM & Leads',
        breadcrumbs: const ['Vikshha Farmlands'],
        subtitle: 'Investor enquiries, follow-up scheduling & site visit tracking',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(TablerIcons.refresh, color: AppColors.textPrimary),
            onPressed: () => context.read<CrmCubit>().load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(TablerIcons.userPlus),
        label: const Text('New Lead'),
        onPressed: () => _openLeadEditor(context),
      ),
      body: BlocConsumer<CrmCubit, CrmState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading && state.leads.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppLoadingSkeleton(count: 6),
            );
          }

          if (state.errorMessage != null && state.leads.isEmpty) {
            return AppEmptyState(
              icon: TablerIcons.alertCircle,
              title: 'Unable to Load Leads',
              message: state.errorMessage!,
              action: AppButton.primary(
                label: 'Retry',
                icon: TablerIcons.refresh,
                onPressed: () => context.read<CrmCubit>().load(),
              ),
            );
          }

          final activePipelineCount = state.leads
              .where((l) => l.stage != 'converted' && l.stage != 'lost')
              .length;

          return Column(
            children: [
              // Overdue follow-up alert banner
              if (state.overdueFollowUpsCount > 0)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${state.overdueFollowUpsCount} follow-up task(s) overdue!',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showFollowUpsDialog(context),
                        child: const Text('View All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),

              // Responsive 2-Column KPI Summary
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: AppStatGrid(
                  spacing: 8,
                  children: [
                    AppStatCard(
                      title: 'Total Inquiries',
                      value: '${state.leads.length}',
                      subtitle: 'Registered leads',
                      icon: TablerIcons.users,
                      accentColor: AppColors.primary,
                    ),
                    AppStatCard(
                      title: 'Active Pipeline',
                      value: '$activePipelineCount',
                      subtitle: 'In negotiation / follow-up',
                      icon: TablerIcons.trendingUp,
                      accentColor: AppColors.success,
                      trendBadge: 'Active',
                      trendPositive: true,
                    ),
                    AppStatCard(
                      title: 'Overdue Follow-ups',
                      value: '${state.overdueFollowUpsCount}',
                      subtitle: state.overdueFollowUpsCount > 0 ? 'Urgent attention needed' : 'All tasks up to date',
                      icon: TablerIcons.alarm,
                      accentColor: state.overdueFollowUpsCount > 0 ? AppColors.error : AppColors.success,
                      trendBadge: state.overdueFollowUpsCount > 0 ? 'Due' : 'Clear',
                      trendPositive: state.overdueFollowUpsCount == 0,
                      onTap: () => _showFollowUpsDialog(context),
                    ),
                    AppStatCard(
                      title: 'Site Visits',
                      value: '${state.siteVisits.length}',
                      subtitle: 'Conducted / scheduled',
                      icon: TablerIcons.mapPin,
                      accentColor: AppColors.leafAccent,
                    ),
                  ],
                ),
              ),

              // 1. Stage Filter Segment
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<CrmStageFilter>(
                    segments: [
                      ButtonSegment(
                        value: CrmStageFilter.all,
                        label: Text('All (${state.leads.length})'),
                      ),
                      const ButtonSegment(value: CrmStageFilter.newStage, label: Text('New')),
                      const ButtonSegment(value: CrmStageFilter.contacted, label: Text('Contacted')),
                      const ButtonSegment(value: CrmStageFilter.interested, label: Text('Interested')),
                      const ButtonSegment(value: CrmStageFilter.siteVisit, label: Text('Site Visit')),
                      const ButtonSegment(value: CrmStageFilter.negotiation, label: Text('Negotiation')),
                      const ButtonSegment(value: CrmStageFilter.converted, label: Text('Converted')),
                      const ButtonSegment(value: CrmStageFilter.lost, label: Text('Lost')),
                    ],
                    selected: {state.stageFilter},
                    onSelectionChanged: (set) {
                      context.read<CrmCubit>().filterStage(set.first);
                    },
                  ),
                ),
              ),

              // Source & Priority Filters Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: state.sourceFilter,
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Source Filter',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Sources')),
                          DropdownMenuItem(value: 'Walk-in', child: Text('Walk-in')),
                          DropdownMenuItem(value: 'Phone Enquiry', child: Text('Phone Enquiry')),
                          DropdownMenuItem(value: 'Referral', child: Text('Referral')),
                          DropdownMenuItem(value: 'Digital Ads', child: Text('Digital Ads')),
                          DropdownMenuItem(value: 'Agri Expo', child: Text('Agri Expo')),
                          DropdownMenuItem(value: 'Website', child: Text('Website')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (val) {
                          if (val != null) context.read<CrmCubit>().filterSource(val);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: state.priorityFilter,
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Priority Filter',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Priorities')),
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                          DropdownMenuItem(value: 'medium', child: Text('Medium')),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                          DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                        ],
                        onChanged: (val) {
                          if (val != null) context.read<CrmCubit>().filterPriority(val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      icon: const Icon(Icons.alarm),
                      tooltip: 'Follow-ups (${state.followUps.length})',
                      onPressed: () => _showFollowUpsDialog(context),
                    ),
                  ],
                ),
              ),

              // 2. Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search lead name, phone, email, requirements...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              context.read<CrmCubit>().search('');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) => context.read<CrmCubit>().search(val),
                ),
              ),

              // 3. Leads List
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.leads.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.groups_outlined, size: 54, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text('No leads found matching current stage', style: TextStyle(color: Colors.grey, fontSize: 16)),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  icon: const Icon(Icons.person_add),
                                  label: const Text('Register New Lead'),
                                  onPressed: () => _openLeadEditor(context),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: state.leads.length,
                            itemBuilder: (context, index) {
                              final lead = state.leads[index];
                              final stageColor = _stageColor(lead.stage);
                              final project = state.projects.where((p) => p.id == lead.interestedProjectId).firstOrNull;

                              return Card(
                                elevation: 0.5,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _showLeadDetails(context, lead),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      lead.name,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade100,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      lead.source,
                                                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: stageColor.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: stageColor),
                                              ),
                                              child: Text(
                                                lead.stage.toUpperCase(),
                                                style: TextStyle(
                                                  color: stageColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(lead.phone, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                            if (project != null) ...[
                                              const SizedBox(width: 12),
                                              Icon(Icons.apartment, size: 14, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text(project.code, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                            ],
                                          ],
                                        ),
                                        if (lead.budget > 0) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            'Budget: ${MoneyCalculator.formatCurrency(lead.budget)}',
                                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                                          ),
                                        ],
                                        if (lead.nextFollowUpDate != null) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(Icons.alarm, size: 14, color: Colors.orange),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Follow-up: ${lead.nextFollowUpDate!.toLocal().toString().substring(0, 10)}',
                                                style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

