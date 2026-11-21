import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/models/app_models.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/repositories/repositories.dart';
import '../cubit/reports_cubit.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key, this.cubit});

  final ReportsCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    return BlocProvider(
      create: (_) => cubit ?? (ReportsCubit(
        reportsRepository: deps.reportsRepository,
        salesRepository: deps.salesRepository,
        exportService: deps.fileExportService,
      )..load()),
      child: const _ReportsView(),
    );
  }
}

class _ReportsView extends StatelessWidget {
  const _ReportsView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<ReportsCubit, ReportsState>(
      builder: (context, state) {
        if (state.loading && state.invoices.isEmpty && state.summary == ComprehensiveReportSummary.empty) {
          return const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: AppLoadingSkeleton(count: 8),
            ),
          );
        }

        final isMobile = MediaQuery.of(context).size.width < 768;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppHeader(
            title: l10n.tr('reports'),
            subtitle: 'Sales, purchases, inventory, P&L, balance sheets & tax reports',
            actions: [
              IconButton(
                onPressed: state.loading ? null : () => context.read<ReportsCubit>().load(),
                icon: const Icon(TablerIcons.refresh, color: AppColors.textPrimary),
                tooltip: 'Refresh',
              ),
              PopupMenuButton<String>(
                icon: const Icon(TablerIcons.fileExport, color: AppColors.textPrimary),
                tooltip: 'Export & Share',
                onSelected: (val) {
                  final cubit = context.read<ReportsCubit>();
                  switch (val) {
                    case 'pdf':
                      cubit.exportPdfReport();
                      break;
                    case 'print':
                      cubit.printPdfReport();
                      break;
                    case 'csv_sales':
                      cubit.exportSalesCsv();
                      break;
                    case 'csv_purchases':
                      cubit.exportPurchasesCsv();
                      break;
                    case 'csv_inventory':
                      cubit.exportInventoryCsv();
                      break;
                    case 'csv_gst':
                      cubit.exportGstCsv();
                      break;
                    case 'csv_trial_balance':
                      cubit.exportTrialBalanceCsv();
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'pdf',
                    child: Row(
                      children: [
                        Icon(AppIcons.invoice, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('Export Comprehensive PDF'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'print',
                    child: Row(
                      children: [
                        Icon(AppIcons.print, color: AppColors.primary, size: 18),
                        SizedBox(width: 8),
                        Text('Print PDF Report'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'csv_sales',
                    child: Row(
                      children: [
                        Icon(AppIcons.download, size: 18),
                        SizedBox(width: 8),
                        Text('Export Sales CSV'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'csv_purchases',
                    child: Row(
                      children: [
                        Icon(AppIcons.download, size: 18),
                        SizedBox(width: 8),
                        Text('Export Purchases CSV'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'csv_inventory',
                    child: Row(
                      children: [
                        Icon(AppIcons.download, size: 18),
                        SizedBox(width: 8),
                        Text('Export Inventory CSV'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'csv_gst',
                    child: Row(
                      children: [
                        Icon(AppIcons.download, size: 18),
                        SizedBox(width: 8),
                        Text('Export GST Tax CSV'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'csv_trial_balance',
                    child: Row(
                      children: [
                        Icon(AppIcons.download, size: 18),
                        SizedBox(width: 8),
                        Text('Export Trial Balance CSV'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => context.read<ReportsCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _QuickDateFilterBar(state: state),
                const SizedBox(height: AppSpacing.md),
                _ReportsKpiDashboard(summary: state.summary),
                const SizedBox(height: AppSpacing.lg),
                _ReportCategoryTabs(
                  selectedTab: state.selectedTab,
                  onTabSelected: (index) => context.read<ReportsCubit>().selectTab(index),
                ),
                const SizedBox(height: AppSpacing.md),
                switch (state.selectedTab) {
                  0 => _SalesReportsTab(state: state, isMobile: isMobile),
                  1 => _PurchasesReportsTab(state: state, isMobile: isMobile),
                  2 => _InventoryReportsTab(state: state, isMobile: isMobile),
                  3 => _FinancialsReportsTab(state: state, isMobile: isMobile),
                  4 => _GstReportsTab(state: state, isMobile: isMobile),
                  5 => _HrReportsTab(state: state, isMobile: isMobile),
                  _ => const SizedBox.shrink(),
                },
                const SizedBox(height: AppSpacing.lg),
                const _P3BusinessExtensionsSummaryCard(),
                if (state.error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    state.error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickDateFilterBar extends StatelessWidget {
  const _QuickDateFilterBar({required this.state});

  final ReportsState state;

  @override
  Widget build(BuildContext context) {
    final from = state.from;
    final to = state.to;
    final cubit = context.read<ReportsCubit>();

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(AppIcons.calendar, size: 18, color: AppColors.primary),
            const SizedBox(width: 4),
            _FilterChipButton(
              label: 'All Time',
              isSelected: from == null && to == null,
              onTap: () => cubit.setPresetRange('all'),
            ),
            _FilterChipButton(
              label: 'Today',
              isSelected: _isToday(from, to),
              onTap: () => cubit.setPresetRange('today'),
            ),
            _FilterChipButton(
              label: 'Yesterday',
              isSelected: _isYesterday(from, to),
              onTap: () => cubit.setPresetRange('yesterday'),
            ),
            _FilterChipButton(
              label: 'Last 7 Days',
              isSelected: _isLast7Days(from, to),
              onTap: () => cubit.setPresetRange('7days'),
            ),
            _FilterChipButton(
              label: 'This Month',
              isSelected: _isThisMonth(from, to),
              onTap: () => cubit.setPresetRange('thisMonth'),
            ),
            ActionChip(
              avatar: const Icon(AppIcons.calendar, size: 16),
              label: Text(
                from == null || to == null
                    ? 'Custom Range'
                    : '${AppFormatters.shortDate(from)} → ${AppFormatters.shortDate(to)}',
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () async {
                final now = DateTime.now();
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(now.year - 2),
                  lastDate: DateTime(now.year + 1),
                  initialDateRange: from != null && to != null
                      ? DateTimeRange(start: from, end: to)
                      : DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
                );
                if (range != null) {
                  await cubit.setRange(range.start, range.end);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime? f, DateTime? t) {
    if (f == null || t == null) return false;
    final now = DateTime.now();
    return f.year == now.year && f.month == now.month && f.day == now.day;
  }

  bool _isYesterday(DateTime? f, DateTime? t) {
    if (f == null || t == null) return false;
    final y = DateTime.now().subtract(const Duration(days: 1));
    return f.year == y.year && f.month == y.month && f.day == y.day;
  }

  bool _isLast7Days(DateTime? f, DateTime? t) {
    if (f == null || t == null) return false;
    final diff = t.difference(f).inDays;
    return diff >= 6 && diff <= 8 && t.isAfter(DateTime.now().subtract(const Duration(hours: 24)));
  }

  bool _isThisMonth(DateTime? f, DateTime? t) {
    if (f == null || t == null) return false;
    final now = DateTime.now();
    return f.year == now.year && f.month == now.month && f.day == 1;
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppColors.primaryContainer,
      onSelected: (_) => onTap(),
    );
  }
}

class _ReportsKpiDashboard extends StatelessWidget {
  const _ReportsKpiDashboard({required this.summary});

  final ComprehensiveReportSummary summary;

  @override
  Widget build(BuildContext context) {
    return AppStatGrid(
      minTileWidth: 200,
      children: [
        AppStatCard(
          title: 'Total Sales Revenue',
          value: AppFormatters.money(summary.totalSales),
          subtitle: '${summary.totalSalesInvoices} sales invoices',
          icon: AppIcons.currencyRupee,
          accentColor: AppColors.primary,
        ),
        AppStatCard(
          title: 'Total Purchases',
          value: AppFormatters.money(summary.totalPurchases),
          subtitle: '${summary.totalPurchaseInvoices} supplier bills',
          icon: AppIcons.purchases,
          accentColor: Colors.blue,
        ),
        AppStatCard(
          title: 'Gross Margin / Profit',
          value: AppFormatters.money(summary.grossProfit),
          subtitle: 'Revenue minus direct COGS',
          icon: AppIcons.trendUp,
          accentColor: Colors.green,
          trendBadge: summary.grossProfit >= 0 ? '+Healthy' : '-Low',
          trendPositive: summary.grossProfit >= 0,
        ),
        AppStatCard(
          title: 'Net Operating Profit',
          value: AppFormatters.money(summary.netProfit),
          subtitle: 'Gross profit - OpEx overhead',
          icon: AppIcons.wallet,
          accentColor: Colors.teal,
          trendBadge: summary.netProfit >= 0 ? '+Profit' : '-Loss',
          trendPositive: summary.netProfit >= 0,
        ),
        AppStatCard(
          title: 'Operating Expenses',
          value: AppFormatters.money(summary.totalExpenses),
          subtitle: 'Operating overhead & utilities',
          icon: AppIcons.financials,
          accentColor: Colors.red,
        ),
        AppStatCard(
          title: 'Net Cash Flow',
          value: AppFormatters.money(summary.netCashFlow),
          subtitle: 'In: ${AppFormatters.money(summary.cashInflow)} | Out: ${AppFormatters.money(summary.cashOutflow)}',
          icon: AppIcons.transfer,
          accentColor: Colors.deepPurple,
        ),
        AppStatCard(
          title: 'Customer Receivables',
          value: AppFormatters.money(summary.outstandingReceivables),
          subtitle: 'Pending customer collections',
          icon: AppIcons.user,
          accentColor: Colors.amber.shade800,
        ),
        AppStatCard(
          title: 'Supplier Payables',
          value: AppFormatters.money(summary.outstandingPayables),
          subtitle: 'Outstanding trade payables',
          icon: AppIcons.bank,
          accentColor: Colors.deepOrange,
        ),
        AppStatCard(
          title: 'Inventory Valuation',
          value: AppFormatters.money(summary.inventoryValuation),
          subtitle: '${summary.lowStockCount} items at low threshold',
          icon: AppIcons.stock,
          accentColor: Colors.indigo,
        ),
        AppStatCard(
          title: 'Net GST Liability',
          value: AppFormatters.money(summary.netGstLiability),
          subtitle: 'Out: ${AppFormatters.money(summary.outputGstTotal)} | In: ${AppFormatters.money(summary.inputGstTotal)}',
          icon: AppIcons.receipt,
          accentColor: Colors.blueGrey,
        ),
      ],
    );
  }
}

class _ReportCategoryTabs extends StatelessWidget {
  const _ReportCategoryTabs({
    required this.selectedTab,
    required this.onTabSelected,
  });

  final int selectedTab;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (0, 'Sales & Invoices', AppIcons.shoppingCart),
      (1, 'Purchases & Payables', AppIcons.purchases),
      (2, 'Inventory Valuation', AppIcons.stock),
      (3, 'Financials & Trial Balance', AppIcons.financials),
      (4, 'GST & Tax Registers', AppIcons.receipt),
      (5, 'HR & Payroll Analytics', AppIcons.employees),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((t) {
          final isSelected = selectedTab == t.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              avatar: Icon(
                t.$3,
                size: 16,
                color: isSelected ? AppColors.primary : Colors.grey.shade700,
              ),
              label: Text(
                t.$2,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primary : Colors.grey.shade800,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primaryContainer.withValues(alpha: 0.4),
              onSelected: (_) => onTabSelected(t.$1),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SalesReportsTab extends StatelessWidget {
  const _SalesReportsTab({required this.state, required this.isMobile});

  final ReportsState state;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.salesByProduct.isNotEmpty) ...[
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Top Performing Products (Volume & Turnover)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: state.salesByProduct.take(6).map((p) {
                      return Chip(
                        avatar: const Icon(AppIcons.products, size: 16, color: AppColors.primary),
                        label: Text('${p.productName}: ${p.qty} pcs (${AppFormatters.money(p.total)})'),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sales Invoices (${state.invoices.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton.icon(
                      onPressed: () => context.read<ReportsCubit>().exportSalesCsv(),
                      icon: const Icon(AppIcons.download, size: 16),
                      label: const Text('Export CSV'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (state.invoices.isEmpty)
                  const AppEmptyState(
                    title: 'No sales records in range',
                    message: 'Try adjusting the date range or record sales at POS.',
                    icon: AppIcons.shoppingCart,
                  )
                else if (isMobile)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.invoices.take(20).length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final inv = state.invoices[idx];
                      return ListTile(
                        dense: true,
                        title: Text(inv.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${AppFormatters.shortDate(inv.createdAt)} • ${inv.paymentMethod.name.toUpperCase()}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(AppFormatters.money(inv.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            AppBadge(
                              label: inv.status.value,
                              tone: inv.status == SaleStatus.completed ? AppBadgeTone.success : AppBadgeTone.warning,
                            ),
                          ],
                        ),
                        onTap: () => context.push('/reports/invoice/${inv.id}'),
                      );
                    },
                  )
                else
                  AppDataTable<SaleSummary>(
                    minWidth: 650,
                    columns: [
                      AppDataColumn<SaleSummary>(
                        title: 'Invoice #',
                        cellBuilder: (ctx, inv, idx) => Text(inv.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      AppDataColumn<SaleSummary>(
                        title: 'Date & Time',
                        cellBuilder: (ctx, inv, idx) => Text(AppFormatters.shortDate(inv.createdAt)),
                      ),
                      AppDataColumn<SaleSummary>(
                        title: 'Payment Method',
                        cellBuilder: (ctx, inv, idx) => Text(inv.paymentMethod.name.toUpperCase()),
                      ),
                      AppDataColumn<SaleSummary>(
                        title: 'Total Amount',
                        numeric: true,
                        cellBuilder: (ctx, inv, idx) => Text(AppFormatters.money(inv.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      AppDataColumn<SaleSummary>(
                        title: 'Status',
                        cellBuilder: (ctx, inv, idx) => AppBadge(
                          label: inv.status.value,
                          tone: inv.status == SaleStatus.completed ? AppBadgeTone.success : AppBadgeTone.warning,
                        ),
                      ),
                    ],
                    items: state.invoices.take(30).toList(),
                    onRowTap: (inv) => context.push('/reports/invoice/${inv.id}'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PurchasesReportsTab extends StatelessWidget {
  const _PurchasesReportsTab({required this.state, required this.isMobile});

  final ReportsState state;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Purchase Invoices & Supplier Bills (${state.purchaseRows.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton.icon(
                  onPressed: () => context.read<ReportsCubit>().exportPurchasesCsv(),
                  icon: const Icon(AppIcons.download, size: 16),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (state.purchaseRows.isEmpty)
              const AppEmptyState(
                title: 'No purchase invoices in range',
                message: 'Record supplier invoices in Purchase Management.',
                icon: AppIcons.purchases,
              )
            else if (isMobile)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.purchaseRows.take(20).length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final row = state.purchaseRows[idx];
                  return ListTile(
                    dense: true,
                    title: Text(row.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${row.supplierName} • ${AppFormatters.shortDate(row.date)}'),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(AppFormatters.money(row.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Bal: ${AppFormatters.money(row.balanceDue)}', style: TextStyle(fontSize: 11, color: row.balanceDue > 0 ? Colors.red : Colors.green)),
                      ],
                    ),
                  );
                },
              )
            else
              AppDataTable<PurchaseReportRow>(
                minWidth: 750,
                columns: [
                  AppDataColumn<PurchaseReportRow>(
                    title: 'Invoice #',
                    cellBuilder: (ctx, r, idx) => Text(r.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  AppDataColumn<PurchaseReportRow>(
                    title: 'Supplier',
                    cellBuilder: (ctx, r, idx) => Text(r.supplierName),
                  ),
                  AppDataColumn<PurchaseReportRow>(
                    title: 'Date',
                    cellBuilder: (ctx, r, idx) => Text(AppFormatters.shortDate(r.date)),
                  ),
                  AppDataColumn<PurchaseReportRow>(
                    title: 'Total Bill',
                    numeric: true,
                    cellBuilder: (ctx, r, idx) => Text(AppFormatters.money(r.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  AppDataColumn<PurchaseReportRow>(
                    title: 'Paid',
                    numeric: true,
                    cellBuilder: (ctx, r, idx) => Text(AppFormatters.money(r.paidAmount)),
                  ),
                  AppDataColumn<PurchaseReportRow>(
                    title: 'Balance Due',
                    numeric: true,
                    cellBuilder: (ctx, r, idx) => Text(
                      AppFormatters.money(r.balanceDue),
                      style: TextStyle(fontWeight: FontWeight.bold, color: r.balanceDue > 0 ? Colors.red : Colors.green),
                    ),
                  ),
                  AppDataColumn<PurchaseReportRow>(
                    title: 'Payment Status',
                    cellBuilder: (ctx, r, idx) => AppBadge(
                      label: r.paymentStatus,
                      tone: r.balanceDue <= 0 ? AppBadgeTone.success : AppBadgeTone.warning,
                    ),
                  ),
                ],
                items: state.purchaseRows.take(30).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _InventoryReportsTab extends StatelessWidget {
  const _InventoryReportsTab({required this.state, required this.isMobile});

  final ReportsState state;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Inventory Valuation & Stock Status (${state.inventoryRows.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton.icon(
                  onPressed: () => context.read<ReportsCubit>().exportInventoryCsv(),
                  icon: const Icon(AppIcons.download, size: 16),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (state.inventoryRows.isEmpty)
              const AppEmptyState(
                title: 'No inventory catalog found',
                message: 'Add items in Products & Inventory.',
                icon: AppIcons.stock,
              )
            else if (isMobile)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.inventoryRows.take(20).length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final r = state.inventoryRows[idx];
                  return ListTile(
                    dense: true,
                    title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${r.sku} • Stock: ${r.stock}'),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Val: ${AppFormatters.money(r.stock * r.cost)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        AppBadge(
                          label: r.lowStock ? 'Low Stock' : 'In Stock',
                          tone: r.lowStock ? AppBadgeTone.error : AppBadgeTone.success,
                        ),
                      ],
                    ),
                  );
                },
              )
            else
              AppDataTable<InventoryReportRow>(
                minWidth: 800,
                columns: [
                  AppDataColumn<InventoryReportRow>(
                    title: 'Product Name',
                    cellBuilder: (ctx, r, idx) => Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  AppDataColumn<InventoryReportRow>(
                    title: 'SKU',
                    cellBuilder: (ctx, r, idx) => Text(r.sku),
                  ),
                  AppDataColumn<InventoryReportRow>(
                    title: 'Category',
                    cellBuilder: (ctx, r, idx) => Text(r.category),
                  ),
                  AppDataColumn<InventoryReportRow>(
                    title: 'Stock Qty',
                    numeric: true,
                    cellBuilder: (ctx, r, idx) => Text('${r.stock}'),
                  ),
                  AppDataColumn<InventoryReportRow>(
                    title: 'Unit Cost',
                    numeric: true,
                    cellBuilder: (ctx, r, idx) => Text(AppFormatters.money(r.cost)),
                  ),
                  AppDataColumn<InventoryReportRow>(
                    title: 'Unit Price',
                    numeric: true,
                    cellBuilder: (ctx, r, idx) => Text(AppFormatters.money(r.price)),
                  ),
                  AppDataColumn<InventoryReportRow>(
                    title: 'Stock Valuation (Cost)',
                    numeric: true,
                    cellBuilder: (ctx, r, idx) => Text(AppFormatters.money(r.stock * r.cost), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  AppDataColumn<InventoryReportRow>(
                    title: 'Status',
                    cellBuilder: (ctx, r, idx) => AppBadge(
                      label: r.lowStock ? 'Low Stock' : 'Healthy',
                      tone: r.lowStock ? AppBadgeTone.error : AppBadgeTone.success,
                    ),
                  ),
                ],
                items: state.inventoryRows.take(30).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _FinancialsReportsTab extends StatelessWidget {
  const _FinancialsReportsTab({required this.state, required this.isMobile});

  final ReportsState state;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    double totalDebit = 0.0;
    double totalCredit = 0.0;
    for (final r in state.trialBalanceRows) {
      totalDebit += r.debit;
      totalCredit += r.credit;
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Financial Accounts & Trial Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton.icon(
                  onPressed: () => context.read<ReportsCubit>().exportTrialBalanceCsv(),
                  icon: const Icon(AppIcons.download, size: 16),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (state.trialBalanceRows.isEmpty)
              const AppEmptyState(
                title: 'No ledger records yet',
                message: 'Accounts and ledger entries will populate here.',
                icon: AppIcons.financials,
              )
            else ...[
              AppDataTable<FinancialTrialBalanceRow>(
                minWidth: 650,
                columns: [
                  AppDataColumn<FinancialTrialBalanceRow>(
                    title: 'Account Code',
                    cellBuilder: (ctx, r, idx) => Text(r.accountCode, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  AppDataColumn<FinancialTrialBalanceRow>(
                    title: 'Account Name',
                    cellBuilder: (ctx, r, idx) => Text(r.accountName),
                  ),
                  AppDataColumn<FinancialTrialBalanceRow>(
                    title: 'Account Type',
                    cellBuilder: (ctx, r, idx) => AppBadge(
                      label: r.accountType.toUpperCase(),
                      tone: AppBadgeTone.neutral,
                    ),
                  ),
                  AppDataColumn<FinancialTrialBalanceRow>(
                    title: 'Debit (₹)',
                    numeric: true,
                    cellBuilder: (ctx, r, idx) => Text(AppFormatters.money(r.debit), style: TextStyle(fontWeight: r.debit > 0 ? FontWeight.bold : FontWeight.normal)),
                  ),
                  AppDataColumn<FinancialTrialBalanceRow>(
                    title: 'Credit (₹)',
                    numeric: true,
                    cellBuilder: (ctx, r, idx) => Text(AppFormatters.money(r.credit), style: TextStyle(fontWeight: r.credit > 0 ? FontWeight.bold : FontWeight.normal)),
                  ),
                ],
                items: state.trialBalanceRows,
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Total Debit: ${AppFormatters.money(totalDebit)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 24),
                  Text('Total Credit: ${AppFormatters.money(totalCredit)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 24),
                  AppBadge(
                    label: (totalDebit - totalCredit).abs() < 1.0 ? 'Balanced' : 'Difference: ${AppFormatters.money((totalDebit - totalCredit).abs())}',
                    tone: (totalDebit - totalCredit).abs() < 1.0 ? AppBadgeTone.success : AppBadgeTone.warning,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GstReportsTab extends StatelessWidget {
  const _GstReportsTab({required this.state, required this.isMobile});

  final ReportsState state;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('GST & Tax Registers (${state.gstRows.length} transactions)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton.icon(
                  onPressed: () => context.read<ReportsCubit>().exportGstCsv(),
                  icon: const Icon(AppIcons.download, size: 16),
                  label: const Text('Export GST CSV'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (state.gstRows.isEmpty)
              const AppEmptyState(
                title: 'No GST tax transactions in range',
                message: 'Sales and purchases with applicable tax will appear here.',
                icon: AppIcons.receipt,
              )
            else if (isMobile)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.gstRows.take(20).length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final r = state.gstRows[idx];
                  return ListTile(
                    dense: true,
                    title: Text(r.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${r.partyName} • ${r.type == 'sales_output' ? 'Outward' : 'Inward'}'),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Tax: ${AppFormatters.money(r.totalGst)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Val: ${AppFormatters.money(r.totalInvoiceValue)}', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  );
                },
              )
            else
              AppDataTable<GstReportRow>(
                minWidth: 950,
                columns: [
                  AppDataColumn<GstReportRow>(
                    title: 'Type',
                    cellBuilder: (ctx, r, idx) {
                      final isSales = r.type == 'sales_output';
                      return AppBadge(
                        label: isSales ? 'Outward' : 'Inward',
                        tone: isSales ? AppBadgeTone.info : AppBadgeTone.success,
                      );
                    },
                  ),
                  AppDataColumn<GstReportRow>(
                    title: 'Invoice #',
                    cellBuilder: (ctx, r, idx) => Text(r.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  AppDataColumn<GstReportRow>(
                    title: 'Party Name',
                    cellBuilder: (ctx, r, idx) => Text(r.partyName),
                  ),
                  AppDataColumn<GstReportRow>(
                    title: 'GSTIN',
                    cellBuilder: (ctx, r, idx) => Text(r.partyGstin),
                  ),
                  AppDataColumn<GstReportRow>(
                    title: 'Date',
                    cellBuilder: (ctx, r, idx) => Text(AppFormatters.shortDate(r.invoiceDate)),
                  ),
                  AppDataColumn<GstReportRow>(
                    title: 'Taxable Val',
                    numeric: true,
                    cellBuilder: (ctx, r, idx) => Text(AppFormatters.money(r.taxableAmount)),
                  ),
                  AppDataColumn<GstReportRow>(
                    title: 'CGST',
                    numeric: true,
                    cellBuilder: (ctx, r, idx) => Text(AppFormatters.money(r.cgst)),
                  ),
                  AppDataColumn<GstReportRow>(
                    title: 'SGST',
                    numeric: true,
                    cellBuilder: (ctx, r, idx) => Text(AppFormatters.money(r.sgst)),
                  ),
                  AppDataColumn<GstReportRow>(
                    title: 'IGST',
                    numeric: true,
                    cellBuilder: (ctx, r, idx) => Text(AppFormatters.money(r.igst)),
                  ),
                  AppDataColumn<GstReportRow>(
                    title: 'Total GST',
                    numeric: true,
                    cellBuilder: (ctx, r, idx) => Text(AppFormatters.money(r.totalGst), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  AppDataColumn<GstReportRow>(
                    title: 'Total Invoice',
                    numeric: true,
                    cellBuilder: (ctx, r, idx) => Text(AppFormatters.money(r.totalInvoiceValue), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
                items: state.gstRows.take(30).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _HrReportsTab extends StatelessWidget {
  const _HrReportsTab({required this.state, required this.isMobile});

  final ReportsState state;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final hr = state.hrSummary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppStatGrid(
          minTileWidth: 200,
          children: [
            AppStatCard(
              title: 'Total Workforce',
              value: '${hr.totalEmployees}',
              subtitle: '${hr.activeEmployees} active on duty',
              icon: AppIcons.employees,
              accentColor: AppColors.primary,
            ),
            AppStatCard(
              title: 'Attendance Average',
              value: '${hr.attendancePercentage.toStringAsFixed(1)}%',
              subtitle: '${hr.totalWorkingDays} operational days',
              icon: AppIcons.calendar,
              accentColor: Colors.blue,
              trendBadge: hr.attendancePercentage >= 80 ? 'Good' : 'Review',
              trendPositive: hr.attendancePercentage >= 80,
            ),
            AppStatCard(
              title: 'Approved Leaves',
              value: '${hr.approvedLeaves}',
              subtitle: 'Staff leaves logged',
              icon: AppIcons.calendar,
              accentColor: Colors.orange,
            ),
            AppStatCard(
              title: 'Payroll Disbursed',
              value: AppFormatters.money(hr.totalPayrollDisbursed),
              subtitle: 'Disbursed salaries',
              icon: AppIcons.cash,
              accentColor: Colors.green,
            ),
            AppStatCard(
              title: 'Pending Payroll',
              value: AppFormatters.money(hr.pendingPayrollAmount),
              subtitle: 'Pending staff salary dues',
              icon: AppIcons.clock,
              accentColor: Colors.red,
            ),
            AppStatCard(
              title: 'Commissions & Incentives',
              value: AppFormatters.money(hr.totalIncentivesPaid),
              subtitle: 'Sales bonuses & incentives',
              icon: AppIcons.receipt,
              accentColor: Colors.purple,
            ),
          ],
        ),
      ],
    );
  }
}

class _P3BusinessExtensionsSummaryCard extends StatelessWidget {
  const _P3BusinessExtensionsSummaryCard();

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return FutureBuilder<Map<String, dynamic>>(
      future: () async {
        final plotsRaw = await deps.plotRepository.getPlots();
        final plots = plotsRaw.cast<dynamic>();

        final leadsRaw = await deps.crmRepository.getLeads();
        final leads = leadsRaw.cast<dynamic>();

        final bookingsRaw = await deps.bookingRepository.getBookings();
        final bookings = bookingsRaw.cast<dynamic>();

        final deliveriesRaw = await deps.deliveryRepository.getDeliveries();
        final deliveries = deliveriesRaw.cast<dynamic>();

        final totalPlotVal = plots.fold<double>(0.0, (sum, p) => sum + ((p.totalPrice as num?)?.toDouble() ?? 0.0));
        final availablePlots = plots.where((p) => p.status == 'available').length;
        final bookedPlots = plots.where((p) => p.status == 'booked' || p.status == 'sold').length;

        final totalLeads = leads.length;
        final convertedLeads = leads.where((l) => l.stage == 'converted').length;
        final siteVisitLeads = leads.where((l) => l.stage == 'site_visit').length;

        final totalBookedVal = bookings.fold<double>(0.0, (sum, b) => sum + ((b.totalPlotValue as num?)?.toDouble() ?? 0.0));
        final totalAdvance = bookings.fold<double>(0.0, (sum, b) => sum + ((b.bookingAmount as num?)?.toDouble() ?? 0.0));

        final pendingDeliveries = deliveries.where((d) => d.status != 'delivered').length;
        final completedDeliveries = deliveries.where((d) => d.status == 'delivered').length;

        return {
          'plotsCount': plots.length,
          'availablePlots': availablePlots,
          'bookedPlots': bookedPlots,
          'totalPlotVal': totalPlotVal,
          'totalLeads': totalLeads,
          'convertedLeads': convertedLeads,
          'siteVisitLeads': siteVisitLeads,
          'bookingsCount': bookings.length,
          'totalBookedVal': totalBookedVal,
          'totalAdvance': totalAdvance,
          'pendingDeliveries': pendingDeliveries,
          'completedDeliveries': completedDeliveries,
        };
      }(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final d = snapshot.data!;

        return Card(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.green.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/darvi_icon.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(TablerIcons.trees, color: Colors.green, size: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Vikshha Farmland & Extensions Overview',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _MiniMetric(
                      title: 'Plots Available',
                      value: '${d['availablePlots']} / ${d['plotsCount']}',
                      subtitle: 'Val: ₹${((d['totalPlotVal'] as double) / 100000).toStringAsFixed(1)}L',
                      icon: AppIcons.plots,
                      color: Colors.green,
                    ),
                    _MiniMetric(
                      title: 'CRM Lead Funnel',
                      value: '${d['convertedLeads']} Converted',
                      subtitle: '${d['siteVisitLeads']} Site Visits • ${d['totalLeads']} Leads',
                      icon: AppIcons.parties,
                      color: Colors.blue,
                    ),
                    _MiniMetric(
                      title: 'Farmland Bookings',
                      value: '${d['bookingsCount']} Booked',
                      subtitle: 'Advance: ₹${((d['totalAdvance'] as double) / 100000).toStringAsFixed(1)}L',
                      icon: AppIcons.bookings,
                      color: Colors.purple,
                    ),
                    _MiniMetric(
                      title: 'Deliveries',
                      value: '${d['completedDeliveries']} Delivered',
                      subtitle: '${d['pendingDeliveries']} In Progress',
                      icon: AppIcons.deliveries,
                      color: Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
