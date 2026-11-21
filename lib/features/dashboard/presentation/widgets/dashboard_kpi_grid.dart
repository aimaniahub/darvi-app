import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_stat_card.dart';
import '../../../../core/widgets/app_stat_grid.dart';
import '../cubit/dashboard_state.dart';

/// Redesigned KPI Section using Phase 3 AppStatGrid and AppStatCard.
/// Prioritizes Top 4 primary metrics in a compact 2-column layout on mobile,
/// followed by secondary business metrics.
class DashboardKpiGrid extends StatelessWidget {
  const DashboardKpiGrid({
    super.key,
    required this.kpis,
  });

  final DashboardKpiData kpis;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Business Overview & Real-Time KPIs',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              '${kpis.totalTransactions} Total Bills',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Unified 2-Column Responsive KPI Grid (Top 4 primary metrics first)
        AppStatGrid(
          spacing: 8,
          children: [
            // 1. Today's Sales (Primary 1)
            AppStatCard(
              title: "Today's Sales",
              value: AppFormatters.money(kpis.todaySales),
              subtitle: '${kpis.todayInvoices} bills recorded today',
              icon: TablerIcons.receipt,
              accentColor: AppColors.primary,
              trendBadge: '+Today',
              trendPositive: true,
              onTap: () => context.go('/pos'),
            ),

            // 2. Monthly Sales (Primary 2)
            AppStatCard(
              title: 'Monthly Sales',
              value: AppFormatters.money(kpis.monthSales),
              subtitle: '${kpis.monthInvoices} invoices this month',
              icon: TablerIcons.trendingUp,
              accentColor: AppColors.success,
              trendBadge: 'MTD',
              trendPositive: true,
              onTap: () => context.go('/reports'),
            ),

            // 3. Average Bill Value (Primary 3)
            AppStatCard(
              title: 'Average Bill Value',
              value: AppFormatters.money(kpis.averageBillValue),
              subtitle: 'Per invoice average',
              icon: TablerIcons.calculator,
              accentColor: const Color(0xFF0284C7),
              onTap: () => context.go('/reports'),
            ),

            // 4. Today's Collections (Primary 4)
            AppStatCard(
              title: "Today's Collections",
              value: AppFormatters.money(kpis.todayCollections),
              subtitle: 'Cash, UPI & Bank receipts',
              icon: TablerIcons.cash,
              accentColor: Colors.teal,
              trendBadge: 'Received',
              trendPositive: true,
              onTap: () => context.go('/financials'),
            ),

            // 5. Customer Receivables
            AppStatCard(
              title: 'Customer Receivables',
              value: AppFormatters.money(kpis.totalReceivables),
              subtitle: '${kpis.totalCustomers} registered customers',
              icon: TablerIcons.wallet,
              accentColor: AppColors.warning,
              trendBadge: 'Dues',
              trendPositive: false,
              onTap: () => context.go('/parties'),
            ),

            // 6. Supplier Payables
            AppStatCard(
              title: 'Supplier Payables',
              value: AppFormatters.money(kpis.totalPayables),
              subtitle: 'Inward purchase dues',
              icon: TablerIcons.receiptTax,
              accentColor: AppColors.error,
              trendBadge: 'Payable',
              trendPositive: false,
              onTap: () => context.go('/purchases'),
            ),

            // 7. Monthly Expenses
            AppStatCard(
              title: 'Monthly Expenses',
              value: AppFormatters.money(kpis.monthlyExpenses),
              subtitle: 'Operating costs this month',
              icon: TablerIcons.receipt,
              accentColor: const Color(0xFFE11D48),
              onTap: () => context.go('/financials'),
            ),

            // 8. Total Products & Stock
            AppStatCard(
              title: 'Catalog Products',
              value: '${kpis.totalProducts}',
              subtitle: 'Active inventory items',
              icon: TablerIcons.package,
              accentColor: AppColors.primary,
              onTap: () => context.go('/products'),
            ),

            // 9. Low Stock Alerts
            AppStatCard(
              title: 'Low Stock Alerts',
              value: '${kpis.lowStockProductsCount}',
              subtitle: kpis.lowStockProductsCount > 0 ? 'Items below reorder level' : 'All items well stocked',
              icon: TablerIcons.alertTriangle,
              accentColor: kpis.lowStockProductsCount > 0 ? AppColors.error : AppColors.success,
              trendBadge: kpis.lowStockProductsCount > 0 ? 'Urgent' : 'Healthy',
              trendPositive: kpis.lowStockProductsCount == 0,
              onTap: () => context.go('/inventory'),
            ),

            // 10. Inventory Valuation
            AppStatCard(
              title: 'Inventory Valuation',
              value: AppFormatters.money(kpis.inventoryValuation),
              subtitle: 'At purchase cost',
              icon: TablerIcons.packages,
              accentColor: const Color(0xFF0D9488),
              onTap: () => context.go('/inventory'),
            ),

            // 11. Vikshha Farmland Plots
            AppStatCard(
              title: 'Farmland Plots',
              value: '${kpis.availablePlots} / ${kpis.totalPlots}',
              subtitle: '${kpis.bookedPlots} plots booked/sold',
              icon: TablerIcons.buildingEstate,
              accentColor: AppColors.leafAccent,
              progress: kpis.totalPlots > 0 ? (kpis.bookedPlots / kpis.totalPlots) : 0.0,
              targetLabel: kpis.totalPlots > 0 ? '${((kpis.bookedPlots / kpis.totalPlots) * 100).toStringAsFixed(0)}% Booked' : '0% Booked',
              onTap: () => context.go('/plots'),
            ),

            // 12. Farmland Bookings & CRM Leads
            AppStatCard(
              title: 'Bookings & Leads',
              value: '${kpis.activeBookings} Bookings',
              subtitle: '${kpis.activeLeads} active leads',
              icon: TablerIcons.buildingCommunity,
              accentColor: const Color(0xFF8B5CF6),
              onTap: () => context.go('/crm'),
            ),
          ],
        ),
      ],
    );
  }
}
