import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/app_models.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../cubit/purchases_cubit.dart';

class PurchasesPage extends StatelessWidget {
  const PurchasesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    return BlocProvider(
      create: (_) => PurchasesCubit(
        purchaseRepository: deps.purchaseRepository,
        partyRepository: deps.partyRepository,
        productRepository: deps.productRepository,
        accountRepository: deps.accountRepository,
      )..load(),
      child: const _PurchasesView(),
    );
  }
}

class _PurchasesView extends StatefulWidget {
  const _PurchasesView();

  @override
  State<_PurchasesView> createState() => _PurchasesViewState();
}

class _PurchasesViewState extends State<_PurchasesView> {
  final TextEditingController _searchController = TextEditingController();
  bool _showRecentInward = false;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  List<Map<String, dynamic>> _getSortedInvoices(List<Map<String, dynamic>> invoices) {
    if (_sortColumnIndex == null) return invoices;
    final sorted = List<Map<String, dynamic>>.from(invoices);
    sorted.sort((a, b) {
      int comparison;
      switch (_sortColumnIndex) {
        case 0:
          final aNo = (a['invoice_number'] as String? ?? '').toLowerCase();
          final bNo = (b['invoice_number'] as String? ?? '').toLowerCase();
          comparison = aNo.compareTo(bNo);
          break;
        case 1:
          final aSup = (a['supplier_name'] as String? ?? '').toLowerCase();
          final bSup = (b['supplier_name'] as String? ?? '').toLowerCase();
          comparison = aSup.compareTo(bSup);
          break;
        case 2:
          final aSecs = a['invoice_date'] as int? ?? 0;
          final bSecs = b['invoice_date'] as int? ?? 0;
          comparison = aSecs.compareTo(bSecs);
          break;
        case 4:
          final aTot = (a['total_amount'] as num? ?? 0.0).toDouble();
          final bTot = (b['total_amount'] as num? ?? 0.0).toDouble();
          comparison = aTot.compareTo(bTot);
          break;
        case 6:
          final aDue = ((a['total_amount'] as num? ?? 0.0) - (a['paid_amount'] as num? ?? 0.0)).toDouble();
          final bDue = ((b['total_amount'] as num? ?? 0.0) - (b['paid_amount'] as num? ?? 0.0)).toDouble();
          comparison = aDue.compareTo(bDue);
          break;
        default:
          comparison = 0;
      }
      return _sortAscending ? comparison : -comparison;
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PurchasesCubit, PurchasesState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<PurchasesCubit>();
        final metrics = state.metrics;

        final totalPurchased = metrics?.totalPurchases ?? 0.0;
        final totalPaid = metrics?.totalPaid ?? 0.0;
        final totalDue = metrics?.totalOutstanding ?? 0.0;
        final todayPurchased = metrics?.todayPurchases ?? 0.0;
        final monthlyPurchased = metrics?.monthlyPurchases ?? 0.0;
        final returnsTotal = metrics?.returnsTotal ?? 0.0;
        final invoicesCount = metrics?.invoicesCount ?? state.invoices.length;
        final pendingPaymentsCount = metrics?.pendingSupplierPayments ?? 0;

        final sortedInvoices = _getSortedInvoices(state.invoices);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppHeader(
            title: 'Purchases & Inward Stock',
            subtitle: 'Inward inventory, supplier bills, debit notes & payables',
            actions: [
              IconButton(
                icon: const Icon(TablerIcons.chartBar, color: AppColors.textPrimary),
                tooltip: 'Purchase Analytics & GST Summary',
                onPressed: () => _openPurchaseReports(context),
              ),
              IconButton(
                icon: const Icon(TablerIcons.receiptRefund, color: AppColors.textPrimary),
                tooltip: 'Debit Notes & Returns',
                onPressed: () => _openDebitNotesSheet(context, state),
              ),
              IconButton(
                icon: const Icon(TablerIcons.refresh, color: AppColors.textPrimary),
                tooltip: 'Refresh',
                onPressed: () => cubit.load(),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            onPressed: () => _openPurchaseBillEditor(context, state),
            icon: const Icon(TablerIcons.plus, size: 20),
            label: const Text('New Purchase Bill', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          body: RefreshIndicator(
            onRefresh: () => cubit.load(),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // 1. KPI Summary via AppStatGrid
                AppStatGrid(
                  minTileWidth: 190,
                  children: [
                    AppStatCard(
                      title: 'Total Purchases',
                      value: AppFormatters.money(totalPurchased),
                      subtitle: '$invoicesCount purchase invoices',
                      icon: TablerIcons.truckDelivery,
                      accentColor: AppColors.primary,
                    ),
                    AppStatCard(
                      title: "Today's Inward",
                      value: AppFormatters.money(todayPurchased),
                      subtitle: 'Received today',
                      icon: TablerIcons.calendarCheck,
                      accentColor: AppColors.success,
                      trendBadge: '+Today',
                      trendPositive: true,
                    ),
                    AppStatCard(
                      title: 'Monthly Purchases',
                      value: AppFormatters.money(monthlyPurchased),
                      subtitle: 'Month-to-date total',
                      icon: TablerIcons.trendingUp,
                      accentColor: const Color(0xFF0284C7),
                      trendBadge: 'MTD',
                      trendPositive: true,
                    ),
                    AppStatCard(
                      title: 'Total Amount Paid',
                      value: AppFormatters.money(totalPaid),
                      subtitle: 'Disbursed to suppliers',
                      icon: TablerIcons.circleCheck,
                      accentColor: AppColors.success,
                    ),
                    AppStatCard(
                      title: 'Supplier Payables',
                      value: AppFormatters.money(totalDue),
                      subtitle: '$pendingPaymentsCount pending bills',
                      icon: TablerIcons.receiptTax,
                      accentColor: totalDue > 0 ? AppColors.error : AppColors.success,
                      trendBadge: totalDue > 0 ? 'Payable' : 'Settled',
                      trendPositive: totalDue == 0,
                    ),
                    AppStatCard(
                      title: 'Debit Notes / Returns',
                      value: AppFormatters.money(returnsTotal),
                      subtitle: '${state.returns.length} returned vouchers',
                      icon: TablerIcons.receiptRefund,
                      accentColor: AppColors.warning,
                      onTap: () => _openDebitNotesSheet(context, state),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // 2. Filter Toolbar via AppFilterBar
                _buildFilterBar(context, state),
                const SizedBox(height: AppSpacing.lg),

                // 3. Invoices Table / Mobile Cards OR Recently Received Stock
                if (state.loading && state.invoices.isEmpty)
                  const AppLoadingSkeleton(count: 8)
                else if (_showRecentInward)
                  _buildRecentInwardSection(metrics?.recentReceivedStock ?? [])
                else if (sortedInvoices.isEmpty)
                  AppEmptyState(
                    icon: TablerIcons.fileOff,
                    title: 'No Purchase Bills Found',
                    message: state.searchQuery.isNotEmpty
                        ? 'No purchase invoices match "${state.searchQuery}".'
                        : 'No purchase invoices recorded matching selected criteria.',
                    action: AppButton.primary(
                      label: 'Create Purchase Bill',
                      icon: TablerIcons.plus,
                      onPressed: () => _openPurchaseBillEditor(context, state),
                    ),
                  )
                else
                  _buildInvoicesAdaptiveView(context, sortedInvoices, state),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Filter Toolbar ──────────────────────────────────────────────────
  Widget _buildFilterBar(BuildContext context, PurchasesState state) {
    final cubit = context.read<PurchasesCubit>();

    final filterOptions = <FilterOption>[
      FilterOption(id: 'ALL', label: 'All Bills', badge: '${state.invoices.length}'),
      const FilterOption(id: 'UNPAID', label: 'Due / Unpaid'),
      const FilterOption(id: 'PAID', label: 'Fully Paid'),
    ];

    return AppFilterBar(
      searchController: _searchController,
      searchHint: 'Search bill #, ref, supplier...',
      onSearchChanged: (query) => cubit.setSearchQuery(query),
      onSearchClear: () {
        _searchController.clear();
        cubit.setSearchQuery('');
      },
      filterOptions: filterOptions,
      selectedFilterId: state.statusFilter,
      onFilterSelected: (id) => cubit.setStatusFilter(id),
      onClearFilters: () {
        _searchController.clear();
        cubit.setSearchQuery('');
        cubit.setStatusFilter('ALL');
        cubit.setSupplierFilter(null);
        cubit.setDateRange(null, null);
      },
      onRefresh: () => cubit.load(),
      trailingAction: Wrap(
        spacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Supplier filter dropdown
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<int?>(
              initialValue: state.selectedSupplierFilter,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
                border: OutlineInputBorder(borderRadius: AppRadii.sm),
              ),
              hint: const Text('All Suppliers', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All Suppliers', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                ),
                ...state.suppliers.map((s) => DropdownMenuItem<int?>(
                      value: s.id,
                      child: Text(s.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: (supId) => cubit.setSupplierFilter(supId),
            ),
          ),

          // Date Range picker button
          IconButton(
            tooltip: state.fromDate != null
                ? '${AppFormatters.date(state.fromDate!)} - ${AppFormatters.date(state.toDate ?? state.fromDate!)}'
                : 'Filter by date range',
            icon: Icon(
              TablerIcons.calendar,
              size: 20,
              color: state.fromDate != null ? AppColors.primary : AppColors.textSecondary,
            ),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                initialDateRange: state.fromDate != null && state.toDate != null
                    ? DateTimeRange(start: state.fromDate!, end: state.toDate!)
                    : null,
              );
              if (picked != null) {
                cubit.setDateRange(picked.start, picked.end);
              }
            },
          ),

          // Toggle Recently Received Stock View
          IconButton(
            tooltip: _showRecentInward ? 'Switch to Invoices Table' : 'Show Recently Received Items',
            icon: Icon(
              _showRecentInward ? TablerIcons.receipt : TablerIcons.packages,
              size: 20,
              color: _showRecentInward ? AppColors.primary : AppColors.textSecondary,
            ),
            onPressed: () => setState(() => _showRecentInward = !_showRecentInward),
          ),
        ],
      ),
    );
  }

  // ── Adaptive Table / Card Invoices Presentation ───────────────────────
  Widget _buildInvoicesAdaptiveView(
    BuildContext context,
    List<Map<String, dynamic>> invoices,
    PurchasesState state,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 768;

        if (isDesktop) {
          return AppDataTable<Map<String, dynamic>>(
            minWidth: 920,
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            onSort: _onSort,
            columns: [
              AppDataColumn<Map<String, dynamic>>(
                title: 'Invoice & Ref',
                sortable: true,
                cellBuilder: (ctx, bill, idx) {
                  final isCancelled = (bill['is_cancelled'] as int? ?? 0) == 1;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '#${bill['invoice_number']}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          decoration: isCancelled ? TextDecoration.lineThrough : null,
                          color: isCancelled ? AppColors.textMuted : AppColors.textPrimary,
                        ),
                      ),
                      if (bill['internal_reference'] != null)
                        Text(
                          'Ref: ${bill['internal_reference']}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                    ],
                  );
                },
              ),
              AppDataColumn<Map<String, dynamic>>(
                title: 'Supplier',
                sortable: true,
                cellBuilder: (ctx, bill, idx) => Text(
                  bill['supplier_name'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
              AppDataColumn<Map<String, dynamic>>(
                title: 'Date',
                sortable: true,
                cellBuilder: (ctx, bill, idx) {
                  final dateSecs = bill['invoice_date'] as int?;
                  final dateStr = dateSecs != null
                      ? AppFormatters.date(DateTime.fromMillisecondsSinceEpoch(dateSecs * 1000))
                      : 'Today';
                  return Text(dateStr, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary));
                },
              ),
              AppDataColumn<Map<String, dynamic>>(
                title: 'Status',
                cellBuilder: (ctx, bill, idx) {
                  final isCancelled = (bill['is_cancelled'] as int? ?? 0) == 1;
                  final status = (bill['status'] as String? ?? 'unpaid').toLowerCase();
                  final total = (bill['total_amount'] as num? ?? 0.0).toDouble();
                  final paid = (bill['paid_amount'] as num? ?? 0.0).toDouble();
                  final due = total - paid;

                  if (isCancelled) {
                    return const AppBadge.neutral(label: 'CANCELLED', showDot: true);
                  }
                  if (status == 'paid' || due <= 0) {
                    return const AppBadge.success(label: 'PAID', showDot: true);
                  }
                  if (status == 'partial') {
                    return AppBadge.warning(label: 'PARTIAL (Due: ₹${due.toStringAsFixed(0)})', showDot: true);
                  }
                  return AppBadge.error(label: 'DUE (₹${due.toStringAsFixed(0)})', showDot: true);
                },
              ),
              AppDataColumn<Map<String, dynamic>>(
                title: 'Total Amount',
                numeric: true,
                sortable: true,
                cellBuilder: (ctx, bill, idx) => Text(
                  AppFormatters.money((bill['total_amount'] as num? ?? 0.0).toDouble()),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              AppDataColumn<Map<String, dynamic>>(
                title: 'Paid',
                numeric: true,
                cellBuilder: (ctx, bill, idx) => Text(
                  AppFormatters.money((bill['paid_amount'] as num? ?? 0.0).toDouble()),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.successText,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              AppDataColumn<Map<String, dynamic>>(
                title: 'Balance Due',
                numeric: true,
                sortable: true,
                cellBuilder: (ctx, bill, idx) {
                  final due = ((bill['total_amount'] as num? ?? 0.0) - (bill['paid_amount'] as num? ?? 0.0)).toDouble();
                  return Text(
                    AppFormatters.money(due),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: due > 0 ? AppColors.error : AppColors.successText,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  );
                },
              ),
              AppDataColumn<Map<String, dynamic>>(
                title: 'Actions',
                alignment: Alignment.centerRight,
                cellBuilder: (ctx, bill, idx) {
                  final billId = bill['id'] as int;
                  final total = (bill['total_amount'] as num? ?? 0.0).toDouble();
                  final paid = (bill['paid_amount'] as num? ?? 0.0).toDouble();
                  final due = total - paid;
                  final isCancelled = (bill['is_cancelled'] as int? ?? 0) == 1;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(TablerIcons.eye, size: 18, color: AppColors.primary),
                        tooltip: 'View Invoice Details',
                        onPressed: () => _openPurchaseBillDetails(context, billId),
                      ),
                      if (!isCancelled && due > 0)
                        IconButton(
                          icon: const Icon(TablerIcons.cash, size: 18, color: AppColors.success),
                          tooltip: 'Record Supplier Payment',
                          onPressed: () => _openRecordPaymentDialog(context, bill),
                        ),
                      PopupMenuButton<String>(
                        icon: const Icon(TablerIcons.dotsVertical, size: 18, color: AppColors.textMuted),
                        tooltip: 'More Actions',
                        onSelected: (action) {
                          if (action == 'return') {
                            _openPurchaseReturnDialog(context, billId);
                          } else if (action == 'edit') {
                            _openEditInvoiceDialog(context, billId, state);
                          } else if (action == 'cancel') {
                            _confirmCancelInvoice(context, billId);
                          }
                        },
                        itemBuilder: (ctx) => [
                          if (!isCancelled)
                            const PopupMenuItem(
                              value: 'return',
                              child: Row(
                                children: [
                                  Icon(TablerIcons.receiptRefund, size: 16, color: AppColors.warning),
                                  SizedBox(width: 8),
                                  Text('Debit Note / Return'),
                                ],
                              ),
                            ),
                          if (!isCancelled)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(TablerIcons.edit, size: 16, color: Color(0xFF0284C7)),
                                  SizedBox(width: 8),
                                  Text('Edit Invoice'),
                                ],
                              ),
                            ),
                          if (!isCancelled && paid == 0)
                            const PopupMenuItem(
                              value: 'cancel',
                              child: Row(
                                children: [
                                  Icon(TablerIcons.ban, size: 16, color: AppColors.error),
                                  SizedBox(width: 8),
                                  Text('Cancel Invoice', style: TextStyle(color: AppColors.error)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
            items: invoices,
            onRowTap: (bill) => _openPurchaseBillDetails(context, bill['id'] as int),
          );
        }

        // Mobile Card List fallback
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: invoices.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (ctx, idx) => _buildInvoiceCard(ctx, invoices[idx], state),
        );
      },
    );
  }

  Widget _buildInvoiceCard(BuildContext context, Map<String, dynamic> bill, PurchasesState state) {
    final total = (bill['total_amount'] as num? ?? 0.0).toDouble();
    final paid = (bill['paid_amount'] as num? ?? 0.0).toDouble();
    final due = total - paid;
    final isCancelled = (bill['is_cancelled'] as int? ?? 0) == 1;

    final dateSecs = bill['invoice_date'] as int?;
    final dateStr = dateSecs != null
        ? AppFormatters.date(DateTime.fromMillisecondsSinceEpoch(dateSecs * 1000))
        : 'Today';

    return AppCard.bordered(
      onTap: () => _openPurchaseBillDetails(context, bill['id'] as int),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isCancelled
                  ? AppColors.surfaceElevated
                  : due > 0
                      ? AppColors.errorContainer
                      : AppColors.successContainer,
              borderRadius: AppRadii.sm,
            ),
            child: Icon(
              isCancelled
                  ? TablerIcons.ban
                  : due > 0
                      ? TablerIcons.receiptTax
                      : TablerIcons.circleCheck,
              color: isCancelled
                  ? AppColors.textMuted
                  : due > 0
                      ? AppColors.error
                      : AppColors.successText,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      'Bill #${bill['invoice_number']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (bill['internal_reference'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Text(
                          bill['internal_reference'].toString(),
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${bill['supplier_name'] ?? "Unknown"} • $dateStr',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormatters.money(total),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 3),
              if (isCancelled)
                const AppBadge.neutral(label: 'CANCELLED')
              else if (due > 0)
                AppBadge.error(label: 'Due: ₹${due.toStringAsFixed(0)}')
              else
                const AppBadge.success(label: 'Fully Paid'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Recently Received Stock Section ──────────────────────────────────
  Widget _buildRecentInwardSection(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const AppEmptyState(
        icon: TablerIcons.packages,
        title: 'No Stock Inward Transactions Recorded',
        message: 'Stock inward entries from purchase invoices will appear here in chronological order.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 768;

        if (isDesktop) {
          return AppDataTable<Map<String, dynamic>>(
            minWidth: 800,
            columns: [
              AppDataColumn<Map<String, dynamic>>(
                title: 'Product Name',
                cellBuilder: (ctx, itm, idx) => Text(
                  itm['product_name'] ?? 'Product',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              AppDataColumn<Map<String, dynamic>>(
                title: 'Supplier',
                cellBuilder: (ctx, itm, idx) => Text(
                  itm['supplier_name'] ?? 'N/A',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ),
              AppDataColumn<Map<String, dynamic>>(
                title: 'Batch Number',
                cellBuilder: (ctx, itm, idx) => Text(
                  itm['batch_number'] ?? 'N/A',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
              AppDataColumn<Map<String, dynamic>>(
                title: 'Inward Qty',
                numeric: true,
                cellBuilder: (ctx, itm, idx) => AppBadge.success(
                  label: '+${itm['quantity'] ?? 0}',
                  showDot: true,
                ),
              ),
              AppDataColumn<Map<String, dynamic>>(
                title: 'Unit Cost',
                numeric: true,
                cellBuilder: (ctx, itm, idx) => Text(
                  AppFormatters.money((itm['unit_cost'] as num? ?? 0.0).toDouble()),
                  style: const TextStyle(fontSize: 12.5, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
              AppDataColumn<Map<String, dynamic>>(
                title: 'Total Line Cost',
                numeric: true,
                cellBuilder: (ctx, itm, idx) {
                  final qty = itm['quantity'] ?? 0;
                  final cost = (itm['unit_cost'] as num? ?? 0.0).toDouble();
                  return Text(
                    AppFormatters.money(qty * cost),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.primary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  );
                },
              ),
            ],
            items: items,
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (ctx, idx) {
            final itm = items[idx];
            final qty = itm['quantity'] ?? 0;
            final cost = (itm['unit_cost'] as num? ?? 0.0).toDouble();
            final batch = itm['batch_number'] as String?;

            return AppCard.bordered(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: AppRadii.sm,
                    ),
                    child: const Icon(TablerIcons.packages, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itm['product_name'] ?? 'Product',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        Text(
                          'Supplier: ${itm['supplier_name'] ?? "N/A"}${batch != null ? " • Batch: $batch" : ""}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                        Text(
                          'Inward Qty: $qty × ₹${cost.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    AppFormatters.money(qty * cost),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: AppColors.primary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Purchase Invoice Full Details Modal Sheet ─────────────────────────
  Future<void> _openPurchaseBillDetails(BuildContext context, int billId) async {
    final deps = AppScope.of(context);
    final detail = await deps.purchaseRepository.getPurchaseInvoiceDetail(billId);
    if (!context.mounted || detail == null) return;

    final items = (detail['items'] as List<dynamic>?) ?? [];
    final payments = (detail['payments'] as List<dynamic>?) ?? [];
    final returns = (detail['returns'] as List<dynamic>?) ?? [];
    final ledgerEntries = (detail['ledger_entries'] as List<dynamic>?) ?? [];
    final total = (detail['total_amount'] as num? ?? 0.0).toDouble();
    final paid = (detail['paid_amount'] as num? ?? 0.0).toDouble();
    final due = total - paid;
    final isCancelled = (detail['is_cancelled'] as int? ?? 0) == 1;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return DefaultTabController(
          length: 5,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: AppRadii.radiusXl),
            ),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              MediaQuery.of(sheetCtx).padding.bottom + AppSpacing.lg,
            ),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * 0.9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Purchase Bill #${detail['invoice_number']}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Supplier: ${detail['supplier_name']} • Ref: ${detail['internal_reference'] ?? "N/A"}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(TablerIcons.x, size: 20),
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const TabBar(
                  isScrollable: true,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(text: 'Items Breakdown'),
                    Tab(text: 'GST & Totals'),
                    Tab(text: 'Payments'),
                    Tab(text: 'Debit Notes'),
                    Tab(text: 'Ledger Audit'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Items Breakdown
                      ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final itm = items[idx] as Map<String, dynamic>;
                          final q = itm['quantity'] ?? 0;
                          final u = (itm['unit_cost'] as num? ?? 0.0).toDouble();
                          final t = (itm['total'] as num? ?? 0.0).toDouble();
                          final batch = itm['batch_number'] as String?;
                          final retQ = itm['returned_qty'] as int? ?? 0;

                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(itm['product_name'] ?? 'Product #${itm['product_id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Qty: $q ${itm['purchase_unit'] ?? "Unit"} × ₹${u.toStringAsFixed(2)} | Batch: ${batch ?? "N/A"}${retQ > 0 ? " (Returned: $retQ)" : ""}'),
                            trailing: Text('₹${t.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
                          );
                        },
                      ),

                      // Tab 2: GST & Totals
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            _summaryRow('Gross Subtotal:', AppFormatters.money((detail['gross_subtotal'] as num? ?? total).toDouble())),
                            _summaryRow('Item Discount Total:', AppFormatters.money((detail['item_discount_total'] as num? ?? 0.0).toDouble())),
                            _summaryRow('Invoice Discount:', AppFormatters.money((detail['invoice_discount'] as num? ?? 0.0).toDouble())),
                            _summaryRow('Taxable Value:', AppFormatters.money((detail['taxable_value'] as num? ?? total).toDouble())),
                            const Divider(),
                            _summaryRow('CGST:', AppFormatters.money((detail['cgst'] as num? ?? 0.0).toDouble())),
                            _summaryRow('SGST:', AppFormatters.money((detail['sgst'] as num? ?? 0.0).toDouble())),
                            _summaryRow('IGST:', AppFormatters.money((detail['igst'] as num? ?? 0.0).toDouble())),
                            _summaryRow('Total GST Tax:', AppFormatters.money((detail['tax_total'] as num? ?? 0.0).toDouble())),
                            _summaryRow('Round-Off:', AppFormatters.money((detail['round_off'] as num? ?? 0.0).toDouble())),
                            const Divider(),
                            _summaryRow('Grand Total:', AppFormatters.money(total), isBold: true),
                            _summaryRow('Amount Paid:', AppFormatters.money(paid), color: AppColors.successText),
                            _summaryRow('Balance Due:', AppFormatters.money(due), color: due > 0 ? AppColors.error : AppColors.successText, isBold: true),
                          ],
                        ),
                      ),

                      // Tab 3: Payments History
                      payments.isEmpty
                          ? const Center(child: Text('No payments recorded for this bill', style: TextStyle(color: AppColors.textMuted)))
                          : ListView.separated(
                              itemCount: payments.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, idx) {
                                final p = payments[idx] as Map<String, dynamic>;
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(TablerIcons.cash, color: AppColors.success),
                                  title: Text('₹${(p['amount'] as num? ?? 0.0).toStringAsFixed(2)} via ${p['account_name'] ?? "Account"}'),
                                  subtitle: Text('Mode: ${p['payment_mode']} • Ref: ${p['reference_no'] ?? "N/A"}\n${p['narration'] ?? ""}'),
                                );
                              },
                            ),

                      // Tab 4: Debit Notes
                      returns.isEmpty
                          ? const Center(child: Text('No debit notes issued for this invoice', style: TextStyle(color: AppColors.textMuted)))
                          : ListView.separated(
                              itemCount: returns.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, idx) {
                                final ret = returns[idx] as Map<String, dynamic>;
                                final totalAmt = (ret['total_amount'] as num? ?? 0.0).toDouble();
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(TablerIcons.receiptRefund, color: AppColors.warning),
                                  title: Text('Debit Note #${ret['debit_note_number'] ?? ret['id']}'),
                                  subtitle: Text('Reason: ${ret['reason'] ?? "N/A"}'),
                                  trailing: Text('₹${totalAmt.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning)),
                                );
                              },
                            ),

                      // Tab 5: Ledger Audit
                      ledgerEntries.isEmpty
                          ? const Center(child: Text('No ledger entries recorded', style: TextStyle(color: AppColors.textMuted)))
                          : ListView.separated(
                              itemCount: ledgerEntries.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, idx) {
                                final le = ledgerEntries[idx] as Map<String, dynamic>;
                                final debit = (le['debit'] as num? ?? 0.0).toDouble();
                                final credit = (le['credit'] as num? ?? 0.0).toDouble();

                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(le['narration'] ?? '${le['transaction_type']} entry'),
                                  subtitle: Text('Type: ${le['transaction_type']} • Ref: ${le['reference_type']} #${le['reference_id'] ?? ""}'),
                                  trailing: Text(
                                    debit > 0 ? 'Dr ₹${debit.toStringAsFixed(2)}' : 'Cr ₹${credit.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: debit > 0 ? const Color(0xFF0284C7) : AppColors.successText,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
                if (!isCancelled && due > 0)
                  AppButton.primary(
                    label: 'Pay Outstanding Due (${AppFormatters.money(due)})',
                    expanded: true,
                    icon: TablerIcons.cash,
                    onPressed: () {
                      Navigator.of(sheetCtx).pop();
                      _openRecordPaymentDialog(context, detail);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ── Record Supplier Payment Dialog ────────────────────────────────────
  void _openRecordPaymentDialog(BuildContext context, Map<String, dynamic> bill) {
    final cubit = context.read<PurchasesCubit>();
    final billId = bill['id'] as int;
    final total = (bill['total_amount'] as num? ?? 0.0).toDouble();
    final paid = (bill['paid_amount'] as num? ?? 0.0).toDouble();
    final due = total - paid;

    final amountController = TextEditingController(text: due.toStringAsFixed(2));
    final refController = TextEditingController();
    int selectedAccountId = 2; // Default to Bank

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Text('Pay Supplier • ${bill['supplier_name']}'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer,
                        borderRadius: AppRadii.sm,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Bill #${bill['invoice_number']}'),
                          Text('Total Due: ${AppFormatters.money(due)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppFormField(
                      label: 'Payment Amount *',
                      required: true,
                      child: AmountField(controller: amountController),
                    ),
                    AppFormField(
                      label: 'Pay From Account',
                      required: true,
                      child: AppDropdown<int>(
                        value: selectedAccountId,
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Store Cash Drawer')),
                          DropdownMenuItem(value: 2, child: Text('Company Bank Account')),
                          DropdownMenuItem(value: 3, child: Text('Store UPI Account')),
                        ],
                        onChanged: (id) {
                          if (id != null) setDialogState(() => selectedAccountId = id);
                        },
                      ),
                    ),
                    AppFormField(
                      label: 'Payment Reference / UTR / Cheque',
                      child: AppTextField(controller: refController, hint: 'e.g. UTR-982137912'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () async {
                    final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (amt <= 0) return;
                    try {
                      await cubit.recordPayment(
                        purchaseInvoiceId: billId,
                        accountId: selectedAccountId,
                        amount: amt,
                        referenceNo: refController.text.trim().isEmpty ? null : refController.text.trim(),
                        narration: 'Payment against purchase #${bill['invoice_number']}',
                      );
                      if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded successfully')));
                      }
                    } catch (e) {
                      if (dialogCtx.mounted) {
                        ScaffoldMessenger.of(dialogCtx).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
                  child: const Text('Confirm Payment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Purchase Return (Debit Note) Dialog ───────────────────────────────
  void _openPurchaseReturnDialog(BuildContext context, int billId) async {
    final deps = AppScope.of(context);
    final cubit = context.read<PurchasesCubit>();
    final detail = await deps.purchaseRepository.getPurchaseInvoiceDetail(billId);
    if (!context.mounted || detail == null) return;

    final items = (detail['items'] as List<dynamic>?) ?? [];
    final returnQtyControllers = <int, TextEditingController>{};
    for (final itm in items) {
      final pid = itm['product_id'] as int;
      returnQtyControllers[pid] = TextEditingController(text: '0');
    }
    final reasonController = TextEditingController(text: 'Defective goods return');
    int? refundAccountId;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            double totalReturnAmount = 0.0;
            final returnItems = <PurchaseReturnItemInput>[];

            for (final itm in items) {
              final pid = itm['product_id'] as int;
              final q = int.tryParse(returnQtyControllers[pid]?.text.trim() ?? '0') ?? 0;
              final unitCost = (itm['unit_cost'] as num? ?? 0.0).toDouble();
              final gstRate = (itm['gst_rate'] as num? ?? 0.0).toDouble();

              if (q > 0) {
                final lineTax = (q * unitCost * gstRate) / 100.0;
                final lineTotal = (q * unitCost) + lineTax;
                totalReturnAmount += lineTotal;
                returnItems.add(
                  PurchaseReturnItemInput(
                    productId: pid,
                    batchNumber: itm['batch_number'] as String?,
                    quantity: q,
                    unitCost: unitCost,
                    gstRate: gstRate,
                    taxAmount: lineTax,
                    total: lineTotal,
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text('Purchase Return / Debit Note • Bill #${detail['invoice_number']}'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Specify quantities to return to supplier:', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                      const SizedBox(height: AppSpacing.sm),
                      ...items.map((itm) {
                        final pid = itm['product_id'] as int;
                        final purchasedQty = itm['quantity'] as int;
                        final retQty = itm['returned_qty'] as int? ?? 0;
                        final maxAvailable = purchasedQty - retQty;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(itm['product_name'] ?? 'Product', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('Available: $maxAvailable units • Unit cost: ₹${(itm['unit_cost'] as num? ?? 0.0).toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: returnQtyControllers[pid],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(),
                      AppFormField(
                        label: 'Return Reason *',
                        required: true,
                        child: AppTextField(controller: reasonController, hint: 'Reason for debit note'),
                      ),
                      AppFormField(
                        label: 'Settlement Option',
                        child: AppDropdown<int?>(
                          value: refundAccountId,
                          items: const [
                            DropdownMenuItem(value: null, child: Text('Supplier Credit Note (Reduces Payable)')),
                            DropdownMenuItem(value: 1, child: Text('Immediate Cash Refund (Cash Drawer)')),
                            DropdownMenuItem(value: 2, child: Text('Immediate Bank Refund (Company Bank)')),
                          ],
                          onChanged: (id) => setDialogState(() => refundAccountId = id),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.warningContainer,
                          borderRadius: AppRadii.sm,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Debit Note Value: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              AppFormatters.money(totalReturnAmount),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.warningText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: totalReturnAmount <= 0
                      ? null
                      : () async {
                          final debitNoteNo = 'DN-${DateTime.now().millisecondsSinceEpoch % 100000}';
                          try {
                            await cubit.createReturn(
                              PurchaseReturnInput(
                                purchaseInvoiceId: billId,
                                supplierId: detail['supplier_id'] as int,
                                debitNoteNumber: debitNoteNo,
                                items: returnItems,
                                subtotal: totalReturnAmount,
                                totalAmount: totalReturnAmount,
                                reason: reasonController.text.trim(),
                                refundAccountId: refundAccountId,
                              ),
                            );
                            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Debit Note $debitNoteNo created successfully')),
                              );
                            }
                          } catch (e) {
                            if (dialogCtx.mounted) {
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(SnackBar(content: Text(e.toString())));
                            }
                          }
                        },
                  child: const Text('Issue Debit Note & Return Stock'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Cancel Invoice Dialog ─────────────────────────────────────────────
  void _confirmCancelInvoice(BuildContext context, int billId) {
    final cubit = context.read<PurchasesCubit>();
    final reasonController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(TablerIcons.alertTriangle, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text('Cancel Purchase Invoice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel this purchase invoice?'),
            const SizedBox(height: 6),
            const Text('This will deduct inward inventory quantities and reverse financial ledger payables atomically.',
                style: TextStyle(fontSize: 12, color: AppColors.error)),
            const SizedBox(height: AppSpacing.md),
            AppFormField(
              label: 'Cancellation Reason *',
              required: true,
              child: AppTextField(controller: reasonController, hint: 'Reason for cancellation'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Back')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              try {
                await cubit.cancelInvoice(billId, reason: reasonController.text.trim());
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase invoice cancelled and stock reversed')));
                }
              } catch (e) {
                if (dialogCtx.mounted) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );
  }

  // ── Purchase Analytics & GST Summary Dialog ───────────────────────────
  void _openPurchaseReports(BuildContext context) async {
    final deps = AppScope.of(context);
    final report = await deps.purchaseRepository.getPurchaseReport();
    if (!context.mounted) return;

    final supSummary = (report['supplier_summary'] as List<dynamic>?) ?? [];
    final prodSummary = (report['product_summary'] as List<dynamic>?) ?? [];
    final gstSummary = (report['gst_summary'] as Map<String, dynamic>?) ?? {};

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Purchase Analytics & GST Summary'),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('GST Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: AppRadii.sm),
                  child: Column(
                    children: [
                      _summaryRow('Taxable Value:', AppFormatters.money((gstSummary['taxable_total'] as num? ?? 0.0).toDouble())),
                      _summaryRow('CGST Inward:', AppFormatters.money((gstSummary['cgst_total'] as num? ?? 0.0).toDouble())),
                      _summaryRow('SGST Inward:', AppFormatters.money((gstSummary['sgst_total'] as num? ?? 0.0).toDouble())),
                      _summaryRow('IGST Inward:', AppFormatters.money((gstSummary['igst_total'] as num? ?? 0.0).toDouble())),
                      const Divider(),
                      _summaryRow('Total Inward GST ITC:', AppFormatters.money((gstSummary['total_tax'] as num? ?? 0.0).toDouble()), isBold: true),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('Top Suppliers by Purchase Value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                ...supSummary.take(5).map((s) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(s['supplier_name'] ?? 'Supplier', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${s['invoice_count']} bills recorded'),
                      trailing: Text(AppFormatters.money((s['total_amount'] as num? ?? 0.0).toDouble()), style: const TextStyle(fontWeight: FontWeight.bold)),
                    )),
                const SizedBox(height: AppSpacing.sm),
                const Text('Top Procured Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                ...prodSummary.take(5).map((p) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(p['product_name'] ?? 'Product', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Qty: ${p['total_qty']}'),
                      trailing: Text(AppFormatters.money((p['total_spend'] as num? ?? 0.0).toDouble()), style: const TextStyle(fontWeight: FontWeight.bold)),
                    )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  // ── Debit Notes Bottom Sheet ──────────────────────────────────────────
  void _openDebitNotesSheet(BuildContext context, PurchasesState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: AppRadii.radiusXl),
          ),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            MediaQuery.of(sheetCtx).padding.bottom + AppSpacing.lg,
          ),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * 0.8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Purchase Returns & Debit Notes (${state.returns.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: state.returns.isEmpty
                    ? const Center(child: Text('No debit notes issued yet', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        itemCount: state.returns.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final ret = state.returns[idx];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppColors.warningContainer, borderRadius: AppRadii.sm),
                              child: const Icon(TablerIcons.receiptRefund, color: AppColors.warning, size: 20),
                            ),
                            title: Text('Debit Note #${ret.debitNoteNumber} • ${ret.supplierName ?? "Supplier"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Original Bill: #${ret.invoiceNumber ?? "N/A"}\nReason: ${ret.reason ?? "Return to supplier"}'),
                            trailing: Text(
                              AppFormatters.money(ret.totalAmount),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.warningText, fontSize: 14),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Purchase Bill Creation & Editing Modal ────────────────────────────
  void _openPurchaseBillEditor(BuildContext context, PurchasesState state) {
    if (state.suppliers.isEmpty) {
      _showRegisterSupplierDialog(context, onSaved: (newSup) {
        _openPurchaseBillEditor(context, context.read<PurchasesCubit>().state);
      });
      return;
    }
    if (state.products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add products before entering purchase bills.')));
      return;
    }

    final cubit = context.read<PurchasesCubit>();
    final billNoController = TextEditingController(text: 'BILL-${DateTime.now().millisecondsSinceEpoch % 100000}');
    int selectedSupplierId = state.suppliers.first.id;
    bool isGstInclusive = false;
    bool isInterState = false;
    final discountController = TextEditingController(text: '0');
    final paidController = TextEditingController(text: '0.00');
    final refController = TextEditingController();
    int selectedAccountId = 2; // Bank default

    // Multi-item builder state
    final lineItems = <_PurchaseLineItemDraft>[
      _PurchaseLineItemDraft(
        productId: state.products.first.id,
        qty: 10,
        unitCost: state.products.first.cost > 0 ? state.products.first.cost : 100.0,
        gstRate: 18.0,
        batchNumber: 'BAT-${DateTime.now().millisecondsSinceEpoch % 1000}',
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            // Compute invoice calculations
            double grossSubtotal = 0.0;
            double itemDiscountTotal = 0.0;
            double taxableValue = 0.0;
            double cgst = 0.0, sgst = 0.0, igst = 0.0;

            for (final item in lineItems) {
              final lineGross = item.qty * item.unitCost;
              grossSubtotal += lineGross;
              itemDiscountTotal += item.discount;
              final netLine = lineGross - item.discount;

              if (isGstInclusive) {
                final basePrice = netLine / (1 + (item.gstRate / 100.0));
                taxableValue += basePrice;
                final tax = netLine - basePrice;
                if (isInterState) {
                  igst += tax;
                } else {
                  cgst += tax / 2;
                  sgst += tax / 2;
                }
              } else {
                taxableValue += netLine;
                final tax = (netLine * item.gstRate) / 100.0;
                if (isInterState) {
                  igst += tax;
                } else {
                  cgst += tax / 2;
                  sgst += tax / 2;
                }
              }
            }

            final totalTax = cgst + sgst + igst;
            final invoiceDisc = double.tryParse(discountController.text.trim()) ?? 0.0;
            final unroundedGrandTotal = (taxableValue + totalTax) - invoiceDisc;
            final grandTotal = (unroundedGrandTotal * 100).roundToDouble() / 100;
            final roundOff = (grandTotal - unroundedGrandTotal * 100).roundToDouble() / 100;

            final paidNow = double.tryParse(paidController.text.trim()) ?? 0.0;
            final dueBalance = grandTotal - paidNow;

            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: AppRadii.radiusXl),
              ),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
              ),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * 0.92),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Record Multi-Item Purchase Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                        IconButton(icon: const Icon(TablerIcons.x, size: 20), onPressed: () => Navigator.of(sheetCtx).pop()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Supplier row + Inline Supplier Registration
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppFormField(
                            label: 'Supplier *',
                            required: true,
                            child: AppDropdown<int>(
                              value: selectedSupplierId,
                              items: state.suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                              onChanged: (id) {
                                if (id != null) setSheetState(() => selectedSupplierId = id);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: AppButton.secondary(
                            label: '+ Supplier',
                            icon: TablerIcons.userPlus,
                            size: AppButtonSize.compact,
                            onPressed: () {
                              _showRegisterSupplierDialog(context, onSaved: (newSup) {
                                setSheetState(() => selectedSupplierId = newSup.id);
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: AppFormField(
                            label: 'Supplier Bill # *',
                            required: true,
                            child: AppTextField(controller: billNoController),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppFormField(
                            label: 'Internal Reference',
                            child: AppTextField(controller: refController, hint: 'PO Ref / DC No.'),
                          ),
                        ),
                      ],
                    ),

                    // Tax Mode Toggles
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: isGstInclusive,
                              onChanged: (v) => setSheetState(() => isGstInclusive = v ?? false),
                            ),
                            const Text('Prices are GST Inclusive', style: TextStyle(fontSize: 12.5)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: isInterState,
                              onChanged: (v) => setSheetState(() => isInterState = v ?? false),
                            ),
                            const Text('Inter-state (IGST)', style: TextStyle(fontSize: 12.5)),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Items Header & Add Item Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Line Items (${lineItems.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        AppButton.secondary(
                          label: 'Add Line Item',
                          icon: TablerIcons.plus,
                          size: AppButtonSize.compact,
                          onPressed: () {
                            setSheetState(() {
                              lineItems.add(
                                _PurchaseLineItemDraft(
                                  productId: state.products.first.id,
                                  qty: 1,
                                  unitCost: state.products.first.cost > 0 ? state.products.first.cost : 100.0,
                                  gstRate: 18.0,
                                  batchNumber: 'BAT-${DateTime.now().millisecondsSinceEpoch % 1000}',
                                ),
                              );
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Line Items list
                    ...lineItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;

                      return AppCard.bordered(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: AppFormField(
                                    label: 'Product',
                                    child: AppDropdown<int>(
                                      value: item.productId,
                                      items: state.products
                                          .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)))
                                          .toList(),
                                      onChanged: (pid) {
                                        if (pid != null) {
                                          final p = state.products.firstWhere((prod) => prod.id == pid);
                                          setSheetState(() {
                                            item.productId = pid;
                                            item.unitCost = p.cost;
                                            item.gstRate = p.gstRate;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  flex: 2,
                                  child: AppFormField(
                                    label: 'Batch #',
                                    child: AppTextField(
                                      controller: TextEditingController(text: item.batchNumber)
                                        ..selection = TextSelection.collapsed(offset: item.batchNumber?.length ?? 0),
                                      hint: 'Batch',
                                      onChanged: (v) => item.batchNumber = v,
                                    ),
                                  ),
                                ),
                                if (lineItems.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: IconButton(
                                      icon: const Icon(TablerIcons.trash, color: AppColors.error, size: 20),
                                      onPressed: () => setSheetState(() => lineItems.removeAt(idx)),
                                    ),
                                  ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: AppFormField(
                                    label: 'Qty',
                                    child: AppTextField(
                                      controller: TextEditingController(text: '${item.qty}')
                                        ..selection = TextSelection.collapsed(offset: '${item.qty}'.length),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) => setSheetState(() => item.qty = int.tryParse(v) ?? 1),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: AppFormField(
                                    label: 'Unit Cost',
                                    child: AmountField(
                                      controller: TextEditingController(text: item.unitCost.toStringAsFixed(2))
                                        ..selection = TextSelection.collapsed(offset: item.unitCost.toStringAsFixed(2).length),
                                      onChanged: (v) => setSheetState(() => item.unitCost = v),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: AppFormField(
                                    label: 'GST %',
                                    child: AppDropdown<double>(
                                      value: item.gstRate,
                                      items: const [
                                        DropdownMenuItem(value: 0.0, child: Text('0%')),
                                        DropdownMenuItem(value: 5.0, child: Text('5%')),
                                        DropdownMenuItem(value: 12.0, child: Text('12%')),
                                        DropdownMenuItem(value: 18.0, child: Text('18%')),
                                        DropdownMenuItem(value: 28.0, child: Text('28%')),
                                      ],
                                      onChanged: (r) {
                                        if (r != null) setSheetState(() => item.gstRate = r);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: AppSpacing.md),

                    // Calculations Summary Card
                    AppCard.bordered(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: [
                          _summaryRow('Gross Subtotal:', AppFormatters.money(grossSubtotal)),
                          _summaryRow('Item Discount Total:', AppFormatters.money(itemDiscountTotal)),
                          _summaryRow('Taxable Value:', AppFormatters.money(taxableValue)),
                          if (isInterState)
                            _summaryRow('IGST Total:', AppFormatters.money(igst))
                          else ...[
                            _summaryRow('CGST (50%):', AppFormatters.money(cgst)),
                            _summaryRow('SGST (50%):', AppFormatters.money(sgst)),
                          ],
                          _summaryRow('Total GST Tax:', AppFormatters.money(totalTax)),
                          const Divider(),
                          _summaryRow('Grand Total:', AppFormatters.money(grandTotal), isBold: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Immediate Payment Section
                    Row(
                      children: [
                        Expanded(
                          child: AppFormField(
                            label: 'Immediate Paid Amount',
                            child: AmountField(
                              controller: paidController,
                              onChanged: (_) => setSheetState(() {}),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppFormField(
                            label: 'Payment Account',
                            child: AppDropdown<int>(
                              value: selectedAccountId,
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('Store Cash')),
                                DropdownMenuItem(value: 2, child: Text('Company Bank')),
                                DropdownMenuItem(value: 3, child: Text('Store UPI')),
                              ],
                              onChanged: (id) {
                                if (id != null) setSheetState(() => selectedAccountId = id);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: dueBalance > 0 ? AppColors.errorContainer : AppColors.successContainer,
                        borderRadius: AppRadii.sm,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              dueBalance > 0 ? 'Remaining Balance Due to Supplier:' : 'Invoice Fully Settled:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: dueBalance > 0 ? AppColors.error : AppColors.successText),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            AppFormatters.money(dueBalance > 0 ? dueBalance : 0.0),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: dueBalance > 0 ? AppColors.error : AppColors.successText,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    AppButton.primary(
                      label: 'Save & Inward Purchase Bill (${AppFormatters.money(grandTotal)})',
                      expanded: true,
                      icon: TablerIcons.check,
                      onPressed: () async {
                        final billNo = billNoController.text.trim();
                        if (billNo.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter supplier invoice number.')));
                          return;
                        }

                        final invoiceItems = lineItems.map((itm) {
                          final lineGross = itm.qty * itm.unitCost;
                          final netLine = lineGross - itm.discount;
                          final tax = isGstInclusive
                              ? (netLine - (netLine / (1 + (itm.gstRate / 100.0))))
                              : (netLine * itm.gstRate) / 100.0;

                          return PurchaseInvoiceItemInput(
                            productId: itm.productId,
                            qty: itm.qty,
                            unitCost: itm.unitCost,
                            discount: itm.discount,
                            gstRate: itm.gstRate,
                            lineTotal: netLine + (isGstInclusive ? 0 : tax),
                            batchNumber: itm.batchNumber,
                            purchaseUnit: 'unit',
                            cgst: isInterState ? 0.0 : tax / 2,
                            sgst: isInterState ? 0.0 : tax / 2,
                            igst: isInterState ? tax : 0.0,
                          );
                        }).toList();

                        try {
                          await cubit.createInvoice(
                            PurchaseInvoiceInput(
                              supplierId: selectedSupplierId,
                              supplierInvoiceNo: billNo,
                              internalReference: refController.text.trim().isEmpty ? null : refController.text.trim(),
                              supplierInvoiceDate: DateTime.now(),
                              grossSubtotal: grossSubtotal,
                              itemDiscountTotal: itemDiscountTotal,
                              invoiceDiscount: invoiceDisc,
                              taxableValue: taxableValue,
                              cgst: cgst,
                              sgst: sgst,
                              igst: igst,
                              taxTotal: totalTax,
                              roundOff: roundOff,
                              subtotal: taxableValue,
                              total: grandTotal,
                              paid: paidNow,
                              accountId: paidNow > 0 ? selectedAccountId : null,
                              isGstInclusive: isGstInclusive,
                              items: invoiceItems,
                            ),
                          );
                          if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Purchase Bill #$billNo recorded successfully')));
                          }
                        } catch (e) {
                          if (sheetCtx.mounted) {
                            ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(content: Text(e.toString())));
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Inline Supplier Registration Dialog ───────────────────────────────
  void _showRegisterSupplierDialog(BuildContext context, {required ValueChanged<SupplierModel> onSaved}) {
    final cubit = context.read<PurchasesCubit>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final gstinController = TextEditingController();
    final addressController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (diagCtx) => AlertDialog(
        title: const Text('Add New Supplier'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppFormField(
                label: 'Business / Supplier Name *',
                required: true,
                child: AppTextField(controller: nameController, hint: 'e.g. Agri Chemicals Ltd'),
              ),
              AppFormField(
                label: 'Phone Number',
                child: AppTextField(controller: phoneController, hint: '10-digit mobile', keyboardType: TextInputType.phone),
              ),
              AppFormField(
                label: 'GSTIN',
                child: AppTextField(controller: gstinController, hint: '15-digit GSTIN'),
              ),
              AppFormField(
                label: 'Billing Address',
                child: AppTextField(controller: addressController, hint: 'City, State'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(diagCtx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              try {
                final sup = await cubit.createSupplierInline(
                  name: name,
                  phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                  gstin: gstinController.text.trim().isEmpty ? null : gstinController.text.trim(),
                  address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                );
                if (diagCtx.mounted) Navigator.of(diagCtx).pop();
                onSaved(sup);
              } catch (e) {
                if (diagCtx.mounted) {
                  ScaffoldMessenger.of(diagCtx).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Save Supplier'),
          ),
        ],
      ),
    );
  }

  // ── Edit Purchase Invoice Dialog ──────────────────────────────────────
  void _openEditInvoiceDialog(BuildContext context, int billId, PurchasesState state) async {
    final deps = AppScope.of(context);
    final cubit = context.read<PurchasesCubit>();
    final detail = await deps.purchaseRepository.getPurchaseInvoiceDetail(billId);
    if (!context.mounted || detail == null) return;

    final billNoController = TextEditingController(text: detail['invoice_number'] as String? ?? '');
    final refController = TextEditingController(text: detail['internal_reference'] as String? ?? '');
    final notesController = TextEditingController(text: detail['notes'] as String? ?? '');

    showDialog<void>(
      context: context,
      builder: (diagCtx) => AlertDialog(
        title: Text('Edit Invoice #${detail['invoice_number']}'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppFormField(
                label: 'Supplier Bill # *',
                required: true,
                child: AppTextField(controller: billNoController),
              ),
              AppFormField(
                label: 'Internal Reference',
                child: AppTextField(controller: refController),
              ),
              AppFormField(
                label: 'Notes / Remarks',
                child: AppTextField(controller: notesController, maxLines: 2),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(diagCtx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              try {
                await cubit.editInvoice(
                  billId,
                  PurchaseInvoiceInput(
                    supplierId: detail['supplier_id'] as int,
                    supplierInvoiceNo: billNoController.text.trim(),
                    internalReference: refController.text.trim().isEmpty ? null : refController.text.trim(),
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                    subtotal: (detail['taxable_value'] as num? ?? 0.0).toDouble(),
                    total: (detail['total_amount'] as num? ?? 0.0).toDouble(),
                    items: const [],
                  ),
                );
                if (diagCtx.mounted) Navigator.of(diagCtx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice details updated')));
                }
              } catch (e) {
                if (diagCtx.mounted) {
                  ScaffoldMessenger.of(diagCtx).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

class _PurchaseLineItemDraft {
  _PurchaseLineItemDraft({
    required this.productId,
    required this.qty,
    required this.unitCost,
    this.gstRate = 18.0,
    this.batchNumber,
  });

  int productId;
  int qty;
  double unitCost;
  double discount = 0.0;
  double gstRate;
  String? batchNumber;
}
