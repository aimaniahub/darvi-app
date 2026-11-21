import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import '../widgets/dashboard_activity_feed.dart';
import '../widgets/dashboard_charts_section.dart';
import '../widgets/dashboard_kpi_grid.dart';
import '../widgets/dashboard_quick_actions.dart';

class HomeDashboardPage extends StatelessWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    return BlocProvider(
      create: (_) => DashboardCubit(
        db: deps.database,
        salesRepository: deps.salesRepository,
        productRepository: deps.productRepository,
        partyRepository: deps.partyRepository,
        purchaseRepository: deps.purchaseRepository,
        expenseRepository: deps.expenseRepository,
        plotRepository: deps.plotRepository,
        crmRepository: deps.crmRepository,
        bookingRepository: deps.bookingRepository,
      )..load(),
      child: const _HomeDashboardView(),
    );
  }
}

class _HomeDashboardView extends StatelessWidget {
  const _HomeDashboardView();

  void _showNotificationsSheet(BuildContext context, DashboardState state) {
    final totalAlerts = state.lowStockProducts.length + state.pendingFollowUps.length;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(TablerIcons.bell, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Notification Centre ($totalAlerts)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(TablerIcons.x, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: totalAlerts == 0
                    ? const Center(
                        child: Text('No unread notifications or urgent alerts', style: TextStyle(color: Colors.grey)),
                      )
                    : ListView(
                        children: [
                          if (state.lowStockProducts.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  const Icon(TablerIcons.alertTriangle, color: AppColors.error, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'LOW INVENTORY ALERTS (${state.lowStockProducts.length})',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                                  ),
                                ],
                              ),
                            ),
                            ...state.lowStockProducts.map((p) => ListTile(
                                  dense: true,
                                  leading: const Icon(TablerIcons.packages, color: AppColors.error),
                                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Current Stock: ${p.stockQty} ${p.unit} (Threshold: ${p.lowStockThreshold})'),
                                  trailing: TextButton(
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      context.go('/products');
                                    },
                                    child: const Text('Restock'),
                                  ),
                                )),
                          ],
                          if (state.pendingFollowUps.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  const Icon(TablerIcons.phoneCall, color: AppColors.leafAccent, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'INVESTOR FOLLOW-UPS DUE (${state.pendingFollowUps.length})',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.leafAccent),
                                  ),
                                ],
                              ),
                            ),
                            ...state.pendingFollowUps.map((l) => ListTile(
                                  dense: true,
                                  leading: const Icon(TablerIcons.user, color: AppColors.leafAccent),
                                  title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${l.phone} • ${l.requirements ?? "General inquiry"}'),
                                  trailing: TextButton(
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      context.go('/crm');
                                    },
                                    child: const Text('View Lead'),
                                  ),
                                )),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        final alertCount = state.lowStockProducts.length + state.pendingFollowUps.length;
        final nowFormatted = DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now());

        if (state.loading && state.salesTrend.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppHeader(
              title: 'Dashboard',
              subtitle: nowFormatted,
              actions: [
                IconButton(
                  icon: const Icon(TablerIcons.refresh, size: 20, color: AppColors.textPrimary),
                  tooltip: 'Refresh',
                  onPressed: () {},
                ),
              ],
            ),
            body: const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: AppLoadingSkeleton(count: 8),
            ),
          );
        }

        if (state.error != null && state.salesTrend.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppHeader(
              title: 'Dashboard',
              subtitle: nowFormatted,
              actions: [
                IconButton(
                  icon: const Icon(TablerIcons.refresh, size: 20, color: AppColors.textPrimary),
                  tooltip: 'Refresh',
                  onPressed: () => context.read<DashboardCubit>().load(period: state.selectedPeriod),
                ),
              ],
            ),
            body: AppEmptyState(
              icon: TablerIcons.alertCircle,
              title: 'Unable to Load Dashboard Data',
              message: state.error!,
              action: AppButton.primary(
                label: 'Retry Loading',
                icon: TablerIcons.refresh,
                onPressed: () => context.read<DashboardCubit>().load(period: state.selectedPeriod),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppHeader(
            title: 'Dashboard',
            subtitle: nowFormatted,
            actions: [
              IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(TablerIcons.bell, size: 20, color: AppColors.textPrimary),
                    if (alertCount > 0)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                          child: Text(
                            alertCount > 99 ? '99+' : alertCount.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
                tooltip: 'Notification Centre ($alertCount)',
                onPressed: () => _showNotificationsSheet(context, state),
              ),
              IconButton(
                icon: const Icon(TablerIcons.refresh, size: 20, color: AppColors.textPrimary),
                tooltip: 'Refresh Dashboard',
                onPressed: () => context.read<DashboardCubit>().load(period: state.selectedPeriod),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => context.read<DashboardCubit>().load(period: state.selectedPeriod),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              children: [
                const DashboardQuickActions(),
                const SizedBox(height: AppSpacing.lg),
                DashboardKpiGrid(kpis: state.kpis),
                const SizedBox(height: AppSpacing.lg),
                DashboardChartsSection(
                  state: state,
                  onPeriodChanged: (period) => context.read<DashboardCubit>().changePeriod(period),
                ),
                const SizedBox(height: AppSpacing.lg),
                DashboardActivityFeed(state: state),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        );
      },
    );
  }
}

