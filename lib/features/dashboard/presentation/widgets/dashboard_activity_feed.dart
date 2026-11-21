import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/cards.dart';
import '../cubit/dashboard_state.dart';

class DashboardActivityFeed extends StatelessWidget {
  const DashboardActivityFeed({
    super.key,
    required this.state,
  });

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 720;

        if (isTablet) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildRecentSalesCard(context),
                    const SizedBox(height: AppSpacing.md),
                    _buildLowStockCard(context),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  children: [
                    _buildRecentBookingsCard(context),
                    const SizedBox(height: AppSpacing.md),
                    _buildPendingFollowUpsCard(context),
                  ],
                ),
              ),
            ],
          );
        }

        // Mobile layout: stacked
        return Column(
          children: [
            _buildRecentSalesCard(context),
            const SizedBox(height: AppSpacing.md),
            _buildRecentBookingsCard(context),
            const SizedBox(height: AppSpacing.md),
            _buildLowStockCard(context),
            const SizedBox(height: AppSpacing.md),
            _buildPendingFollowUpsCard(context),
          ],
        );
      },
    );
  }

  Widget _buildRecentSalesCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadii.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 6, top: 8),
            child: DarviSectionHeader(
              title: 'Recent Sales Invoices',
              actionLabel: 'View All',
              onAction: () => context.go('/reports'),
            ),
          ),
          const Divider(),
          if (state.recentSales.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No sales completed yet', style: TextStyle(color: Colors.grey)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.recentSales.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = state.recentSales[i];
                final timeStr = DateFormat('dd MMM, hh:mm a').format(s.createdAt);
                return ActivityTile(
                  leadingIcon: TablerIcons.receipt,
                  iconColor: AppColors.primary,
                  title: s.invoiceNo,
                  subtitle: '${s.status.name.toUpperCase()} • $timeStr',
                  trailingTitle: AppFormatters.money(s.total),
                  trailingSubtitle: s.paymentMethod.name.toUpperCase(),
                  trailingColor: AppColors.primary,
                  onTap: () => context.go('/reports'),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentBookingsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadii.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 6, top: 8),
            child: DarviSectionHeader(
              title: 'Recent Plot Bookings',
              actionLabel: 'View All',
              onAction: () => context.go('/bookings'),
            ),
          ),
          const Divider(),
          if (state.recentBookings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No plot bookings recorded yet', style: TextStyle(color: Colors.grey)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.recentBookings.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final b = state.recentBookings[i];
                final dateStr = DateFormat('dd MMM yyyy').format(b.bookingDate);
                return ActivityTile(
                  leadingIcon: TablerIcons.bookmark,
                  iconColor: Colors.amber.shade800,
                  title: b.bookingNumber,
                  subtitle: 'Plot #${b.plotId} • $dateStr',
                  trailingTitle: AppFormatters.money(b.bookingAmount),
                  trailingSubtitle: b.status.toUpperCase(),
                  trailingColor: AppColors.textPrimary,
                  onTap: () => context.go('/bookings'),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLowStockCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadii.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 6, top: 8),
            child: DarviSectionHeader(
              title: 'Low Stock Alerts',
              actionLabel: 'Manage Stock',
              onAction: () => context.go('/products'),
            ),
          ),
          const Divider(),
          if (state.lowStockProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(TablerIcons.circleCheck, color: AppColors.success, size: 18),
                  SizedBox(width: 8),
                  Text('All inventory items are well-stocked', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.lowStockProducts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = state.lowStockProducts[i];
                return ActivityTile(
                  leadingIcon: TablerIcons.alertTriangle,
                  iconColor: AppColors.error,
                  title: p.name,
                  subtitle: 'SKU: ${p.sku} • Cost: ${AppFormatters.money(p.cost)}',
                  trailingTitle: '${p.stockQty} ${p.unit}',
                  trailingSubtitle: 'Min: ${p.lowStockThreshold}',
                  trailingColor: AppColors.error,
                  onTap: () => context.go('/products'),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPendingFollowUpsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadii.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 6, top: 8),
            child: DarviSectionHeader(
              title: 'Pending Farmland Follow-ups',
              actionLabel: 'Open CRM',
              onAction: () => context.go('/crm'),
            ),
          ),
          const Divider(),
          if (state.pendingFollowUps.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No pending investor follow-ups due', style: TextStyle(color: Colors.grey)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.pendingFollowUps.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final lead = state.pendingFollowUps[i];
                final dateStr = lead.nextFollowUpDate != null
                    ? DateFormat('dd MMM, hh:mm a').format(lead.nextFollowUpDate!)
                    : 'Scheduled';
                return ActivityTile(
                  leadingIcon: TablerIcons.phoneCall,
                  iconColor: AppColors.leafAccent,
                  title: lead.name,
                  subtitle: '${lead.phone} • ${lead.source}',
                  trailingTitle: dateStr,
                  trailingSubtitle: lead.stage.toUpperCase(),
                  trailingColor: AppColors.primary,
                  onTap: () => context.go('/crm'),
                );
              },
            ),
        ],
      ),
    );
  }
}
