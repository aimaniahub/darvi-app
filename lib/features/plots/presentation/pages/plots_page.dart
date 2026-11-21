import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/money_calculator.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/local/db/app_database.dart';
import '../cubit/plot_cubit.dart';
import '../widgets/plot_detail_sheet.dart';
import '../widgets/plot_editor_dialog.dart';
import '../widgets/project_editor_dialog.dart';

class PlotsPage extends StatelessWidget {
  const PlotsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    return BlocProvider(
      create: (context) => PlotCubit(deps.plotRepository)..load(),
      child: const _PlotsView(),
    );
  }
}

class _PlotsView extends StatefulWidget {
  const _PlotsView();

  @override
  State<_PlotsView> createState() => _PlotsViewState();
}

class _PlotsViewState extends State<_PlotsView> {
  final _searchCtrl = TextEditingController();

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'reserved':
        return Colors.orange;
      case 'booked':
        return Colors.blue;
      case 'sold':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _openPlotEditor(BuildContext context, {Plot? plot}) async {
    final cubit = context.read<PlotCubit>();
    final projects = cubit.state.projects;
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please register a property/project first!')),
      );
      _openProjectEditor(context);
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => PlotEditorDialog(
        projects: projects,
        plot: plot,
        initialProjectId: cubit.state.selectedProject?.id,
      ),
    );

    if (result != null) {
      await cubit.savePlot(
        id: result['id'] as int?,
        projectId: result['projectId'] as int,
        plotNumber: result['plotNumber'] as String,
        uniquePlotId: result['uniquePlotId'] as String,
        dimensions: result['dimensions'] as String,
        areaSqFt: result['areaSqFt'] as double,
        surveyNumber: result['surveyNumber'] as String?,
        facing: result['facing'] as String?,
        pricePerSqFt: result['pricePerSqFt'] as double? ?? 0.0,
        status: result['status'] as String,
        basePrice: result['basePrice'] as double,
        totalPrice: result['totalPrice'] as double,
        cropType: result['cropType'] as String?,
        plantationDetails: result['plantationDetails'] as String?,
        notes: result['notes'] as String?,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(plot != null ? 'Plot updated!' : 'Plot registered successfully!')),
        );
      }
    }
  }

  void _openProjectEditor(BuildContext context, {Project? project}) async {
    final cubit = context.read<PlotCubit>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => ProjectEditorDialog(project: project),
    );

    if (result != null) {
      await cubit.saveProject(
        id: result['id'] as int?,
        name: result['name'] as String,
        code: result['code'] as String,
        location: result['location'] as String,
        totalArea: result['totalArea'] as double,
        totalPlots: result['totalPlots'] as int,
        description: result['description'] as String?,
        amenities: result['amenities'] as String?,
        legalStatus: result['legalStatus'] as String?,
        address: result['address'] as String?,
        gpsCoordinates: result['gpsCoordinates'] as String?,
        status: result['status'] as String? ?? 'active',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(project != null ? 'Project updated!' : 'Project created!')),
        );
      }
    }
  }

  void _showPlotDetails(BuildContext context, Plot plot) {
    final cubit = context.read<PlotCubit>();
    final deps = AppScope.of(context);
    final project = cubit.state.projects.firstWhere(
      (p) => p.id == plot.projectId,
      orElse: () => Project(
        id: 0,
        workspaceId: 1,
        name: 'Darvi Farmland',
        code: 'VK',
        location: 'Hubli',
        totalArea: 0,
        totalPlots: 0,
        status: 'active',
        createdAt: DateTime.now(),
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => PlotDetailSheet(
        plot: plot,
        project: project,
        plotRepository: deps.plotRepository,
        onEdit: () {
          Navigator.of(ctx).pop();
          _openPlotEditor(context, plot: plot);
        },
        onStatusChanged: (newStatus) {
          Navigator.of(ctx).pop();
          cubit.updateStatus(plot.id, newStatus);
        },
        onBookPlot: () {
          Navigator.of(ctx).pop();
          context.push('/bookings', extra: {'preselectedPlotId': plot.id});
        },
        onCreateQuotation: () {
          Navigator.of(ctx).pop();
          context.push('/quotations', extra: {'preselectedPlot': plot});
        },
        onDelete: () async {
          Navigator.of(ctx).pop();
          final confirm = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Delete Plot'),
              content: Text('Are you sure you want to delete plot ${plot.uniquePlotId}?'),
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
            try {
              await cubit.deletePlot(plot.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Plot deleted successfully')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                );
              }
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Plot Management & Inventory',
        breadcrumbs: const ['Vikshha Farmlands', 'Projects'],
        subtitle: 'Farmland projects, layout plots, demarcation & boundary specs',
        actions: [
          IconButton(
            tooltip: 'Add Project / Property',
            icon: const Icon(TablerIcons.buildingEstate, color: AppColors.textPrimary),
            onPressed: () => _openProjectEditor(context),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(TablerIcons.refresh, color: AppColors.textPrimary),
            onPressed: () => context.read<PlotCubit>().load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(TablerIcons.mapPinPlus),
        label: const Text('Add Plot'),
        onPressed: () => _openPlotEditor(context),
      ),
      body: BlocConsumer<PlotCubit, PlotState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading && state.plots.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppLoadingSkeleton(count: 6),
            );
          }

          if (state.errorMessage != null && state.plots.isEmpty) {
            return AppEmptyState(
              icon: TablerIcons.alertCircle,
              title: 'Unable to Load Plots',
              message: state.errorMessage!,
              action: AppButton.primary(
                label: 'Retry',
                icon: TablerIcons.refresh,
                onPressed: () => context.read<PlotCubit>().load(),
              ),
            );
          }

          final availableCount = state.plots.where((p) => p.status.toLowerCase() == 'available').length;
          final reservedCount = state.plots.where((p) => p.status.toLowerCase() == 'reserved').length;
          final bookedCount = state.plots.where((p) => p.status.toLowerCase() == 'booked' || p.status.toLowerCase() == 'sold').length;

          return Column(
            children: [
              // Responsive 2-Column KPI Summary
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: AppStatGrid(
                  spacing: 8,
                  children: [
                    AppStatCard(
                      title: 'Total Plots',
                      value: '${state.plots.length}',
                      subtitle: state.selectedProject != null ? state.selectedProject!.code : 'All projects',
                      icon: TablerIcons.trees,
                      accentColor: AppColors.primary,
                    ),
                    AppStatCard(
                      title: 'Available Plots',
                      value: '$availableCount',
                      subtitle: 'Ready for booking',
                      icon: TablerIcons.circleCheck,
                      accentColor: AppColors.success,
                      trendBadge: 'Available',
                      trendPositive: true,
                    ),
                    AppStatCard(
                      title: 'Reserved',
                      value: '$reservedCount',
                      subtitle: 'Token advance paid',
                      icon: TablerIcons.clock,
                      accentColor: AppColors.warning,
                      trendBadge: 'Hold',
                      trendPositive: false,
                    ),
                    AppStatCard(
                      title: 'Booked / Sold',
                      value: '$bookedCount',
                      subtitle: 'Deed registered',
                      icon: TablerIcons.bookmark,
                      accentColor: AppColors.leafAccent,
                    ),
                  ],
                ),
              ),

              // 1. Projects horizontal selector
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('All Projects'),
                        selected: state.selectedProject == null,
                        onSelected: (_) => context.read<PlotCubit>().selectProject(null),
                      ),
                    ),
                    ...state.projects.map((proj) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${proj.name} (${proj.code})'),
                          selected: state.selectedProject?.id == proj.id,
                          onSelected: (selected) {
                            context.read<PlotCubit>().selectProject(selected ? proj : null);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // 2. Status Segmented Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<PlotStatusFilter>(
                    segments: [
                      ButtonSegment(
                        value: PlotStatusFilter.all,
                        label: Text('All (${state.plots.length})'),
                      ),
                      const ButtonSegment(
                        value: PlotStatusFilter.available,
                        label: Text('Available'),
                        icon: Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                      ),
                      const ButtonSegment(
                        value: PlotStatusFilter.reserved,
                        label: Text('Reserved'),
                        icon: Icon(Icons.access_time, color: Colors.orange, size: 16),
                      ),
                      const ButtonSegment(
                        value: PlotStatusFilter.booked,
                        label: Text('Booked'),
                        icon: Icon(Icons.bookmark, color: Colors.blue, size: 16),
                      ),
                      const ButtonSegment(
                        value: PlotStatusFilter.sold,
                        label: Text('Sold'),
                        icon: Icon(Icons.done_all, color: Colors.purple, size: 16),
                      ),
                    ],
                    selected: {state.statusFilter},
                    onSelectionChanged: (set) {
                      context.read<PlotCubit>().filterStatus(set.first);
                    },
                  ),
                ),
              ),

              // Facing Filter and Project KPI Summary Bar
              if (state.selectedProject != null && state.projectSummaries.containsKey(state.selectedProject!.id)) ...[
                Builder(
                  builder: (context) {
                    final summary = state.projectSummaries[state.selectedProject!.id]!;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _ProjectKpi(label: 'Total Plots', value: '${summary['totalPlots']}'),
                          _ProjectKpi(label: 'Available', value: '${summary['availablePlots']}', color: Colors.green),
                          _ProjectKpi(label: 'Reserved', value: '${summary['reservedPlots']}', color: Colors.orange),
                          _ProjectKpi(label: 'Booked', value: '${summary['bookedPlots']}', color: Colors.blue),
                          _ProjectKpi(label: 'Sold', value: '${summary['soldPlots']}', color: Colors.purple),
                        ],
                      ),
                    );
                  },
                ),
              ],

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: state.facingFilter,
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Facing Filter',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Directions')),
                          DropdownMenuItem(value: 'East', child: Text('East Facing')),
                          DropdownMenuItem(value: 'North', child: Text('North Facing')),
                          DropdownMenuItem(value: 'West', child: Text('West Facing')),
                          DropdownMenuItem(value: 'South', child: Text('South Facing')),
                          DropdownMenuItem(value: 'North-East', child: Text('North-East')),
                        ],
                        onChanged: (val) {
                          if (val != null) context.read<PlotCubit>().filterFacing(val);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search plot #, unique ID, survey #, crop type...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              context.read<PlotCubit>().search('');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) => context.read<PlotCubit>().search(val),
                ),
              ),

              // 4. Plots List / Grid
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.plots.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.landscape_outlined, size: 54, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text('No plots found matching current filter', style: TextStyle(color: Colors.grey, fontSize: 16)),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Farmland Plot'),
                                  onPressed: () => _openPlotEditor(context),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: state.plots.length,
                            itemBuilder: (context, index) {
                              final plot = state.plots[index];
                              final statusColor = _statusColor(plot.status);

                              return Card(
                                elevation: 0.5,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _showPlotDetails(context, plot),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    plot.uniquePlotId,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: Theme.of(context).primaryColor,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  plot.dimensions,
                                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: statusColor),
                                              ),
                                              child: Text(
                                                plot.status.toUpperCase(),
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(Icons.park, size: 16, color: Colors.green),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      plot.cropType ?? 'Agro-Forestry & Sandalwood',
                                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${plot.areaSqFt.toStringAsFixed(0)} Sq.Ft. • ${MoneyCalculator.formatCurrency(plot.basePrice)}/Sq.Ft.',
                                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              MoneyCalculator.formatCurrency(plot.totalPrice),
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
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

class _ProjectKpi extends StatelessWidget {
  const _ProjectKpi({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }
}

