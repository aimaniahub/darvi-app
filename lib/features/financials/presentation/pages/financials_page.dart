import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/app_models.dart';
import '../../../../core/widgets/widgets.dart';
import '../cubit/financials_cubit.dart';

/// Redesigned Financials & Accounts page for Darvi Billing & ERP.
/// Implements Phase 3 Design System (Kite UI / Flutter Templates architecture).
class FinancialsPage extends StatelessWidget {
  const FinancialsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    return BlocProvider(
      create: (_) => FinancialsCubit(
        accountRepository: deps.accountRepository,
        expenseRepository: deps.expenseRepository,
        ledgerRepository: deps.ledgerRepository,
      )..load(),
      child: const _FinancialsView(),
    );
  }
}

class _FinancialsView extends StatefulWidget {
  const _FinancialsView();

  @override
  State<_FinancialsView> createState() => _FinancialsViewState();
}

class _FinancialsViewState extends State<_FinancialsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _expenseSearchController = TextEditingController();
  final TextEditingController _ledgerSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _expenseSearchController.dispose();
    _ledgerSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FinancialsCubit, FinancialsState>(
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
        final cubit = context.read<FinancialsCubit>();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppHeader(
            title: 'Financial Management & Accounts',
            subtitle: 'Multi-account cashbook, double-entry ledger, expenses & P&L',
            actions: [
              IconButton(
                icon: const Icon(TablerIcons.arrowDownLeft, color: AppColors.success),
                tooltip: 'Record Money Received',
                onPressed: () => _openMoneyReceivedDialog(context, state),
              ),
              IconButton(
                icon: const Icon(TablerIcons.arrowUpRight, color: AppColors.error),
                tooltip: 'Record Money Paid',
                onPressed: () => _openMoneyPaidDialog(context, state),
              ),
              IconButton(
                icon: const Icon(TablerIcons.arrowsExchange, color: Colors.blue),
                tooltip: 'Inter-Account Transfer',
                onPressed: () => _openTransferDialog(context, state),
              ),
              IconButton(
                icon: const Icon(TablerIcons.receipt, color: Colors.orange),
                tooltip: 'Record Expense',
                onPressed: () => _openExpenseDialog(context, state),
              ),
              IconButton(
                icon: const Icon(TablerIcons.refresh, color: AppColors.textPrimary),
                tooltip: 'Refresh Financial Data',
                onPressed: () => cubit.load(),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(icon: Icon(TablerIcons.layoutDashboard, size: 16), text: 'Dashboard & Accounts'),
                    Tab(icon: Icon(TablerIcons.book, size: 16), text: 'Cashbook Journal'),
                    Tab(icon: Icon(TablerIcons.receipt, size: 16), text: 'Operating Expenses'),
                    Tab(icon: Icon(TablerIcons.books, size: 16), text: 'Double-Entry Ledger'),
                    Tab(icon: Icon(TablerIcons.checklist, size: 16), text: 'Reconciliation & P&L'),
                  ],
                ),
              ),
            ),
          ),
          body: state.loading && state.accounts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: AppLoadingSkeleton(count: 6),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDashboardAndAccountsTab(context, state),
                    _buildCashbookTab(context, state),
                    _buildExpensesTab(context, state),
                    _buildLedgerAuditTab(context, state),
                    _buildReconciliationTab(context, state),
                  ],
                ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 0: Dashboard & Accounts
  // ---------------------------------------------------------------------------
  Widget _buildDashboardAndAccountsTab(BuildContext context, FinancialsState state) {
    final metrics = state.metrics;

    return RefreshIndicator(
      onRefresh: () => context.read<FinancialsCubit>().load(),
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // KPI Grid
            AppStatGrid(
              children: [
                AppStatCard(
                  title: 'Store Cash Drawer',
                  value: '₹${state.totalCash.toStringAsFixed(2)}',
                  subtitle: 'Physical cash on hand',
                  icon: TablerIcons.cash,
                  accentColor: AppColors.success,
                ),
                AppStatCard(
                  title: 'Company Bank',
                  value: '₹${state.totalBank.toStringAsFixed(2)}',
                  subtitle: 'Current / Savings balance',
                  icon: TablerIcons.buildingBank,
                  accentColor: Colors.blue,
                ),
                AppStatCard(
                  title: 'Store UPI Account',
                  value: '₹${state.totalUpi.toStringAsFixed(2)}',
                  subtitle: 'Digital QR & merchant funds',
                  icon: TablerIcons.qrcode,
                  accentColor: Colors.purple,
                ),
                AppStatCard(
                  title: 'Net Liquid Funds',
                  value: '₹${state.netBalance.toStringAsFixed(2)}',
                  subtitle: 'Consolidated liquid capital',
                  icon: TablerIcons.wallet,
                  accentColor: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Operational Flow KPIs
            AppStatGrid(
              children: [
                AppStatCard(
                  title: "Today's Collections",
                  value: '₹${(metrics?.todayCollections ?? 0.0).toStringAsFixed(2)}',
                  subtitle: 'Incoming receipts & POS sales',
                  icon: TablerIcons.arrowDownLeft,
                  accentColor: AppColors.success,
                ),
                AppStatCard(
                  title: "Today's Payments",
                  value: '₹${(metrics?.todayPayments ?? 0.0).toStringAsFixed(2)}',
                  subtitle: 'Supplier payouts & expenses',
                  icon: TablerIcons.arrowUpRight,
                  accentColor: AppColors.error,
                ),
                AppStatCard(
                  title: 'Monthly Expenses',
                  value: '₹${(metrics?.monthlyExpenses ?? 0.0).toStringAsFixed(2)}',
                  subtitle: 'Rent, salaries, logistics & utilities',
                  icon: TablerIcons.receiptTax,
                  accentColor: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Receivables & Payables Summary
            AppStatGrid(
              children: [
                AppStatCard(
                  title: 'Customer Receivables',
                  value: '₹${(metrics?.customerReceivables ?? 0.0).toStringAsFixed(2)}',
                  subtitle: 'Outstanding customer credit',
                  icon: TablerIcons.users,
                  accentColor: AppColors.primary,
                ),
                AppStatCard(
                  title: 'Supplier Payables',
                  value: '₹${(metrics?.supplierPayables ?? 0.0).toStringAsFixed(2)}',
                  subtitle: 'Inward procurement due',
                  icon: TablerIcons.buildingWarehouse,
                  accentColor: AppColors.error,
                ),
                AppStatCard(
                  title: 'Payroll Disbursed',
                  value: '₹${(metrics?.payrollPaid ?? 0.0).toStringAsFixed(2)}',
                  subtitle: 'Incentives: ₹${(metrics?.incentivesPaid ?? 0.0).toStringAsFixed(0)}',
                  icon: TablerIcons.idBadge2,
                  accentColor: Colors.teal,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Configured Accounts Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Configured Payment Accounts (${state.accounts.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                AppButton.primary(
                  label: '+ New Account',
                  icon: TablerIcons.plus,
                  onPressed: () => _openAccountEditor(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Accounts Table
            LayoutBuilder(
              builder: (ctx, constraints) {
                final isDesktop = constraints.maxWidth >= 768;
                if (isDesktop) {
                  return AppDataTable<AccountModel>(
                    minWidth: 800,
                    columns: [
                      AppDataColumn<AccountModel>(
                        title: 'Account Name & Type',
                        cellBuilder: (c, acc, _) {
                          IconData icon = TablerIcons.cash;
                          Color iconColor = AppColors.success;
                          if (acc.type == 'bank') {
                            icon = TablerIcons.buildingBank;
                            iconColor = Colors.blue;
                          } else if (acc.type == 'upi') {
                            icon = TablerIcons.qrcode;
                            iconColor = Colors.purple;
                          }

                          return Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: iconColor.withValues(alpha: 0.12),
                                child: Icon(icon, color: iconColor, size: 16),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            acc.name,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (acc.isDefault) ...[
                                          const SizedBox(width: 6),
                                          const AppBadge.info(label: 'DEFAULT'),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      acc.type.toUpperCase(),
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      AppDataColumn<AccountModel>(
                        title: 'Identifiers & Details',
                        width: 220,
                        cellBuilder: (c, acc, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              acc.accountNumber != null && acc.accountNumber!.isNotEmpty
                                  ? 'A/C: ${acc.accountNumber}'
                                  : (acc.upiId != null ? 'UPI: ${acc.upiId}' : 'Cash Register'),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                            ),
                            if (acc.bankName != null && acc.bankName!.isNotEmpty)
                              Text(
                                '${acc.bankName}${acc.ifsc != null ? " • ${acc.ifsc}" : ""}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                      AppDataColumn<AccountModel>(
                        title: 'Current Balance',
                        width: 170,
                        numeric: true,
                        cellBuilder: (c, acc, _) => Text(
                          '₹${acc.balance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: acc.balance >= 0 ? AppColors.textPrimary : AppColors.error,
                          ),
                        ),
                      ),
                      AppDataColumn<AccountModel>(
                        title: 'Status',
                        width: 110,
                        cellBuilder: (c, acc, _) => acc.isActive
                            ? const AppBadge.success(label: 'ACTIVE')
                            : const AppBadge.neutral(label: 'INACTIVE'),
                      ),
                      AppDataColumn<AccountModel>(
                        title: 'Actions',
                        width: 100,
                        alignment: Alignment.centerRight,
                        cellBuilder: (c, acc, _) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(TablerIcons.edit, size: 18, color: AppColors.primary),
                              tooltip: 'Edit Account',
                              onPressed: () => _openAccountEditor(context, existing: acc),
                            ),
                            IconButton(
                              icon: const Icon(TablerIcons.ban, size: 18, color: AppColors.error),
                              tooltip: 'Deactivate Account',
                              onPressed: () => _confirmDeactivateAccount(context, acc),
                            ),
                          ],
                        ),
                      ),
                    ],
                    items: state.accounts,
                  );
                } else {
                  return Column(
                    children: state.accounts.map((acc) {
                      IconData icon = TablerIcons.cash;
                      Color iconColor = AppColors.success;
                      if (acc.type == 'bank') {
                        icon = TablerIcons.buildingBank;
                        iconColor = Colors.blue;
                      } else if (acc.type == 'upi') {
                        icon = TablerIcons.qrcode;
                        iconColor = Colors.purple;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard.bordered(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: iconColor.withValues(alpha: 0.12),
                                child: Icon(icon, color: iconColor),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(acc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        if (acc.isDefault) ...[
                                          const SizedBox(width: 6),
                                          const AppBadge.info(label: 'DEFAULT'),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      '${acc.type.toUpperCase()}${acc.accountNumber != null ? " • #${acc.accountNumber}" : ""}',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₹${acc.balance.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(TablerIcons.edit, size: 16, color: AppColors.primary),
                                        onPressed: () => _openAccountEditor(context, existing: acc),
                                      ),
                                      IconButton(
                                        icon: const Icon(TablerIcons.ban, size: 16, color: AppColors.error),
                                        onPressed: () => _confirmDeactivateAccount(context, acc),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: Cashbook Journal
  // ---------------------------------------------------------------------------
  Widget _buildCashbookTab(BuildContext context, FinancialsState state) {
    final cubit = context.read<FinancialsCubit>();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Toolbar
          AppCard.bordered(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: AppDropdown<int?>(
                    label: 'Filter by Account',
                    value: state.selectedAccountFilter,
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All Accounts (Consolidated)')),
                      ...state.accounts.map((a) => DropdownMenuItem<int?>(value: a.id, child: Text('${a.name} (${a.type.toUpperCase()})'))),
                    ],
                    onChanged: (id) => cubit.setAccountFilter(id),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                AppButton.outlined(
                  label: state.fromDate == null ? 'Filter Date Range' : 'Date Filter Active',
                  icon: TablerIcons.calendar,
                  onPressed: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (range != null) {
                      cubit.setDateRange(range.start, range.end);
                    } else {
                      cubit.setDateRange(null, null);
                    }
                  },
                ),
                if (state.selectedAccountFilter != null || state.fromDate != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    icon: const Icon(TablerIcons.filterOff, color: AppColors.error),
                    tooltip: 'Clear Filters',
                    onPressed: () {
                      cubit.setAccountFilter(null);
                      cubit.setDateRange(null, null);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Cashbook Records Table
          Expanded(
            child: state.cashbookEntries.isEmpty
                ? AppEmptyState(
                    title: 'No Cashbook Entries',
                    message: 'No receipts, payouts or account transfers match current filters.',
                    icon: TablerIcons.bookOff,
                    action: AppButton.primary(
                      label: 'Record First Receipt',
                      icon: TablerIcons.plus,
                      onPressed: () => _openMoneyReceivedDialog(context, state),
                    ),
                  )
                : AppDataTable<CashbookEntry>(
                    minWidth: 840,
                    columns: [
                      AppDataColumn<CashbookEntry>(
                        title: 'Date & Time',
                        width: 150,
                        cellBuilder: (c, e, _) => Text(
                          e.date.toString().split('.').first,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                        ),
                      ),
                      AppDataColumn<CashbookEntry>(
                        title: 'Type',
                        width: 120,
                        cellBuilder: (c, e, _) {
                          final isReceipt = e.type == 'receipt' || e.debit > 0;
                          final isTransfer = e.type == 'transfer';
                          if (isTransfer) {
                            return const AppBadge.info(label: 'TRANSFER');
                          } else if (isReceipt) {
                            return const AppBadge.success(label: 'RECEIPT');
                          } else {
                            return const AppBadge.error(label: 'PAYMENT');
                          }
                        },
                      ),
                      AppDataColumn<CashbookEntry>(
                        title: 'Narration & Details',
                        cellBuilder: (c, e, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              e.description,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (e.referenceNo != null && e.referenceNo!.isNotEmpty)
                              Text('Ref: ${e.referenceNo}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      AppDataColumn<CashbookEntry>(
                        title: 'Account',
                        width: 150,
                        cellBuilder: (c, e, _) => Text(e.accountName, style: const TextStyle(fontSize: 12.5)),
                      ),
                      AppDataColumn<CashbookEntry>(
                        title: 'Amount (In / Out)',
                        width: 140,
                        numeric: true,
                        cellBuilder: (c, e, _) {
                          final isReceipt = e.type == 'receipt' || e.debit > 0;
                          return Text(
                            isReceipt ? '+₹${e.debit.toStringAsFixed(2)}' : '-₹${e.credit.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: isReceipt ? AppColors.success : AppColors.error,
                            ),
                          );
                        },
                      ),
                      AppDataColumn<CashbookEntry>(
                        title: 'Running Bal',
                        width: 130,
                        numeric: true,
                        cellBuilder: (c, e, _) => Text(
                          '₹${e.runningBalance.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                    items: state.cashbookEntries,
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: Operating Expenses
  // ---------------------------------------------------------------------------
  Widget _buildExpensesTab(BuildContext context, FinancialsState state) {
    final cubit = context.read<FinancialsCubit>();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Toolbar
          AppFilterBar(
            searchController: _expenseSearchController,
            searchHint: 'Search expenses by description, payee or ref...',
            onSearchChanged: (v) => cubit.setSearchQuery(v),
            onSearchClear: () {
              _expenseSearchController.clear();
              cubit.setSearchQuery('');
            },
            filterOptions: const [
              FilterOption(id: 'ALL', label: 'All Expenses'),
              FilterOption(id: 'Rent', label: 'Rent'),
              FilterOption(id: 'Electricity', label: 'Electricity'),
              FilterOption(id: 'Internet', label: 'Internet'),
              FilterOption(id: 'Transport', label: 'Transport'),
              FilterOption(id: 'Fuel', label: 'Fuel'),
              FilterOption(id: 'Repairs', label: 'Repairs'),
              FilterOption(id: 'Office', label: 'Office'),
              FilterOption(id: 'Marketing', label: 'Marketing'),
              FilterOption(id: 'Other', label: 'Other'),
            ],
            selectedFilterId: state.selectedCategoryFilter ?? 'ALL',
            onFilterSelected: (cat) => cubit.setCategoryFilter(cat == 'ALL' ? null : cat),
            trailingAction: AppButton.primary(
              label: '+ Add Expense',
              icon: TablerIcons.receipt,
              onPressed: () => _openExpenseDialog(context, state),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Total Expense Bar
          AppCard.bordered(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(TablerIcons.receiptTax, size: 18, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Total Recorded Expenses: ${state.expenses.length}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
                Text(
                  '₹${state.totalExpenses.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.error),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Expense Table
          Expanded(
            child: state.expenses.isEmpty
                ? AppEmptyState(
                    title: 'No Operating Expenses Recorded',
                    message: 'Keep track of store rent, bills, supplies and overheads with tax input credits.',
                    icon: TablerIcons.receiptOff,
                    action: AppButton.primary(
                      label: 'Record Expense',
                      icon: TablerIcons.plus,
                      onPressed: () => _openExpenseDialog(context, state),
                    ),
                  )
                : AppDataTable<ExpenseModel>(
                    minWidth: 840,
                    columns: [
                      AppDataColumn<ExpenseModel>(
                        title: 'Date',
                        width: 120,
                        cellBuilder: (c, e, _) => Text(
                          e.expenseDate.toString().split(' ').first,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                      AppDataColumn<ExpenseModel>(
                        title: 'Category',
                        width: 140,
                        cellBuilder: (c, e, _) => AppBadge.neutral(
                          label: e.category.toUpperCase(),
                        ),
                      ),
                      AppDataColumn<ExpenseModel>(
                        title: 'Payee / Description',
                        cellBuilder: (c, e, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              e.vendorPayee ?? 'Store Expense',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                decoration: e.isCancelled ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            if (e.notes != null && e.notes!.isNotEmpty)
                              Text(e.notes!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      AppDataColumn<ExpenseModel>(
                        title: 'Total Amount',
                        width: 140,
                        numeric: true,
                        cellBuilder: (c, e, _) => Text(
                          '₹${e.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            decoration: e.isCancelled ? TextDecoration.lineThrough : null,
                            color: e.isCancelled ? AppColors.textSecondary : AppColors.error,
                          ),
                        ),
                      ),
                      AppDataColumn<ExpenseModel>(
                        title: 'Tax / ITC',
                        width: 110,
                        numeric: true,
                        cellBuilder: (c, e, _) => Text(
                          '₹${e.taxAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                      ),
                      AppDataColumn<ExpenseModel>(
                        title: 'Status',
                        width: 120,
                        cellBuilder: (c, e, _) => e.isCancelled
                            ? const AppBadge.error(label: 'CANCELLED')
                            : const AppBadge.success(label: 'POSTED'),
                      ),
                      AppDataColumn<ExpenseModel>(
                        title: 'Actions',
                        width: 90,
                        alignment: Alignment.centerRight,
                        cellBuilder: (c, e, _) => e.isCancelled
                            ? const SizedBox.shrink()
                            : PopupMenuButton<String>(
                                icon: const Icon(TablerIcons.dotsVertical, size: 18),
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _openExpenseDialog(context, state, existing: e);
                                  } else if (action == 'cancel') {
                                    _confirmCancelExpense(context, e);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(TablerIcons.edit, size: 18, color: AppColors.primary),
                                        SizedBox(width: 8),
                                        Text('Edit Expense'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'cancel',
                                    child: Row(
                                      children: [
                                        Icon(TablerIcons.arrowBackUp, size: 18, color: AppColors.error),
                                        SizedBox(width: 8),
                                        Text('Cancel / Reverse'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                    items: state.expenses,
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: Double-Entry Ledger Audit
  // ---------------------------------------------------------------------------
  Widget _buildLedgerAuditTab(BuildContext context, FinancialsState state) {
    final cubit = context.read<FinancialsCubit>();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Toolbar
          AppCard.bordered(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    hint: 'Search ledger narration or reference...',
                    controller: _ledgerSearchController,
                    prefixIcon: const Icon(TablerIcons.search, size: 18),
                    onChanged: (v) => cubit.setSearchQuery(v),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 220,
                  child: AppDropdown<String?>(
                    label: 'Transaction Type',
                    value: state.selectedTxTypeFilter,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Types (Consolidated)')),
                      DropdownMenuItem(value: 'sale', child: Text('Sales Invoices')),
                      DropdownMenuItem(value: 'purchase', child: Text('Purchases')),
                      DropdownMenuItem(value: 'payment_in', child: Text('Receipts (In)')),
                      DropdownMenuItem(value: 'payment_out', child: Text('Payments (Out)')),
                      DropdownMenuItem(value: 'transfer', child: Text('Transfers')),
                      DropdownMenuItem(value: 'expense', child: Text('Expenses')),
                      DropdownMenuItem(value: 'opening_balance', child: Text('Opening Balances')),
                    ],
                    onChanged: (t) => cubit.setTxTypeFilter(t),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Double-Entry Balance Strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Double-Entry Ledger Postings (${state.ledgerEntries.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Row(
                children: [
                  Icon(TablerIcons.circleCheck, color: AppColors.success, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Debit = Credit In Equilibrium',
                    style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Ledger Table
          Expanded(
            child: state.ledgerEntries.isEmpty
                ? const AppEmptyState(
                    title: 'No Ledger Transactions',
                    message: 'No double-entry journals match the selected filters.',
                    icon: TablerIcons.bookOff,
                  )
                : AppDataTable<LedgerEntryModel>(
                    minWidth: 840,
                    columns: [
                      AppDataColumn<LedgerEntryModel>(
                        title: 'Timestamp',
                        width: 150,
                        cellBuilder: (c, le, _) => Text(
                          le.createdAt.toString().split('.').first,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      AppDataColumn<LedgerEntryModel>(
                        title: 'Type',
                        width: 130,
                        cellBuilder: (c, le, _) => AppBadge.neutral(
                          label: le.transactionType.toUpperCase(),
                        ),
                      ),
                      AppDataColumn<LedgerEntryModel>(
                        title: 'Audit Narration & Reference',
                        cellBuilder: (c, le, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              le.narration ?? '${le.transactionType} posting',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (le.referenceType.isNotEmpty)
                              Text('Ref: ${le.referenceType} #${le.referenceId ?? ""}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      AppDataColumn<LedgerEntryModel>(
                        title: 'Debit (Dr)',
                        width: 140,
                        numeric: true,
                        cellBuilder: (c, le, _) => Text(
                          le.debit > 0 ? '₹${le.debit.toStringAsFixed(2)}' : '-',
                          style: TextStyle(
                            fontWeight: le.debit > 0 ? FontWeight.bold : FontWeight.normal,
                            color: le.debit > 0 ? Colors.blue.shade800 : AppColors.textSecondary,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      AppDataColumn<LedgerEntryModel>(
                        title: 'Credit (Cr)',
                        width: 140,
                        numeric: true,
                        cellBuilder: (c, le, _) => Text(
                          le.credit > 0 ? '₹${le.credit.toStringAsFixed(2)}' : '-',
                          style: TextStyle(
                            fontWeight: le.credit > 0 ? FontWeight.bold : FontWeight.normal,
                            color: le.credit > 0 ? Colors.teal.shade800 : AppColors.textSecondary,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                    items: state.ledgerEntries,
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 4: Reconciliation & P&L
  // ---------------------------------------------------------------------------
  Widget _buildReconciliationTab(BuildContext context, FinancialsState state) {
    final recon = state.reconciliation ?? {};
    final pnl = state.profitLoss ?? {};

    final isBalanced = recon['is_trial_balanced'] as bool? ?? true;
    final totalDebit = (recon['total_debit'] as num? ?? 0.0).toDouble();
    final totalCredit = (recon['total_credit'] as num? ?? 0.0).toDouble();
    final diff = (recon['trial_balance_diff'] as num? ?? 0.0).toDouble();

    final netSales = (pnl['net_sales'] as num? ?? 0.0).toDouble();
    final cogs = (pnl['cost_of_goods_sold'] as num? ?? 0.0).toDouble();
    final grossProfit = (pnl['gross_profit'] as num? ?? 0.0).toDouble();
    final opEx = (pnl['operating_expenses'] as num? ?? 0.0).toDouble();
    final netProfit = (pnl['net_profit'] as num? ?? 0.0).toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Trial Balance Banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: (isBalanced ? AppColors.successContainer : AppColors.errorContainer).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isBalanced ? AppColors.success : AppColors.error),
            ),
            child: Row(
              children: [
                Icon(
                  isBalanced ? TablerIcons.circleCheck : TablerIcons.alertTriangle,
                  color: isBalanced ? AppColors.success : AppColors.error,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBalanced
                            ? 'Double-Entry Trial Balance Reconciled & In Equilibrium'
                            : 'Trial Balance Inbalance Detected!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isBalanced ? AppColors.success : AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total Debits: ₹${totalDebit.toStringAsFixed(2)}  |  Total Credits: ₹${totalCredit.toStringAsFixed(2)}  |  Difference: ₹${diff.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Profit & Loss Card
          AppCard.bordered(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(TablerIcons.chartBar, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Profit & Loss Statement (Operating Summary)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _summaryRow('Net Operating Sales (Revenue excl. Tax):', '₹${netSales.toStringAsFixed(2)}'),
                _summaryRow('Cost of Goods Sold (COGS):', '₹${cogs.toStringAsFixed(2)}'),
                const Divider(height: 24),
                _summaryRow(
                  'Gross Profit:',
                  '₹${grossProfit.toStringAsFixed(2)}',
                  isBold: true,
                  color: grossProfit >= 0 ? AppColors.success : AppColors.error,
                ),
                _summaryRow('Operating Expenses:', '₹${opEx.toStringAsFixed(2)}'),
                const Divider(height: 24),
                _summaryRow(
                  'Net Profit / (Loss):',
                  '₹${netProfit.toStringAsFixed(2)}',
                  isBold: true,
                  fontSize: 16,
                  color: netProfit >= 0 ? AppColors.success : AppColors.error,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Balance Reconciliation Card
          AppCard.bordered(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(TablerIcons.scale, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Asset & Liability Reconciliation Overview',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _summaryRow(
                  'Customer Receivables (Current Asset):',
                  '₹${(recon['total_customer_receivables'] as num? ?? 0.0).toStringAsFixed(2)}',
                ),
                _summaryRow(
                  'Supplier Payables (Current Liability):',
                  '₹${(recon['total_supplier_payables'] as num? ?? 0.0).toStringAsFixed(2)}',
                ),
                _summaryRow(
                  'Consolidated Liquid Fund Assets:',
                  '₹${state.netBalance.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 13.5,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: fontSize,
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: fontSize,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: Record Expense
  // ---------------------------------------------------------------------------
  void _openExpenseDialog(BuildContext context, FinancialsState state, {ExpenseModel? existing}) {
    final cubit = context.read<FinancialsCubit>();
    final amountController = TextEditingController(text: existing != null ? existing.amount.toStringAsFixed(2) : '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final refController = TextEditingController(text: existing?.referenceNo ?? '');
    final payeeController = TextEditingController(text: existing?.vendorPayee ?? '');
    final taxController = TextEditingController(text: existing != null ? existing.taxAmount.toStringAsFixed(2) : '0.00');

    String selectedCategory = existing?.category ?? 'Office';
    int selectedAccountId = existing?.accountId ?? (state.accounts.isNotEmpty ? state.accounts.first.id : 1);

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(TablerIcons.receipt, size: 20, color: Colors.orange),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              existing != null ? 'Edit Expense' : 'Record Operating Expense',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppDropdown<String>(
                  label: 'Expense Category *',
                  value: selectedCategory,
                  items: const [
                    DropdownMenuItem(value: 'Rent', child: Text('Rent')),
                    DropdownMenuItem(value: 'Electricity', child: Text('Electricity')),
                    DropdownMenuItem(value: 'Internet', child: Text('Internet & Telecom')),
                    DropdownMenuItem(value: 'Transport', child: Text('Transport / Logistics')),
                    DropdownMenuItem(value: 'Fuel', child: Text('Fuel / Generator')),
                    DropdownMenuItem(value: 'Repairs', child: Text('Repairs & Maintenance')),
                    DropdownMenuItem(value: 'Office', child: Text('Office Expenses & Tea')),
                    DropdownMenuItem(value: 'Marketing', child: Text('Marketing & Ads')),
                    DropdownMenuItem(value: 'Other', child: Text('Other Miscellaneous')),
                  ],
                  onChanged: (cat) {
                    if (cat != null) selectedCategory = cat;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                AmountField(
                  label: 'Total Amount (INR)',
                  controller: amountController,
                ),
                const SizedBox(height: AppSpacing.sm),
                AmountField(
                  label: 'Recoverable Input GST (₹)',
                  controller: taxController,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppDropdown<int>(
                  label: 'Paid From Account *',
                  value: selectedAccountId,
                  items: state.accounts
                      .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (₹${a.balance.toStringAsFixed(0)})')))
                      .toList(),
                  onChanged: (id) {
                    if (id != null) selectedAccountId = id;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Vendor / Payee Name',
                  hint: 'e.g. BESCOM or Sri Balaji Stationers',
                  controller: payeeController,
                  prefixIcon: const Icon(TablerIcons.user, size: 18),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Receipt / Bill Ref No',
                  hint: 'e.g. Bill #10294',
                  controller: refController,
                  prefixIcon: const Icon(TablerIcons.tag, size: 18),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Expense Description / Notes',
                  hint: 'Details of the expense',
                  controller: notesController,
                  prefixIcon: const Icon(TablerIcons.notes, size: 18),
                ),
              ],
            ),
          ),
        ),
        actions: [
          AppButton.ghost(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogCtx).pop(),
          ),
          AppButton.primary(
            label: 'Save Expense',
            icon: TablerIcons.check,
            onPressed: () async {
              final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
              final tax = double.tryParse(taxController.text.trim()) ?? 0.0;
              if (amt <= 0) return;

              try {
                if (existing != null) {
                  await cubit.updateExpense(
                    id: existing.id,
                    accountId: selectedAccountId,
                    category: selectedCategory,
                    amount: amt,
                    referenceNo: refController.text.trim().isEmpty ? null : refController.text.trim(),
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                    vendorPayee: payeeController.text.trim().isEmpty ? null : payeeController.text.trim(),
                    taxAmount: tax,
                  );
                } else {
                  await cubit.addExpense(
                    accountId: selectedAccountId,
                    category: selectedCategory,
                    amount: amt,
                    referenceNo: refController.text.trim().isEmpty ? null : refController.text.trim(),
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                    vendorPayee: payeeController.text.trim().isEmpty ? null : payeeController.text.trim(),
                    taxAmount: tax,
                  );
                }
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Expense recorded and posted to double-entry ledger'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (dialogCtx.mounted) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: Cancel / Reverse Expense
  // ---------------------------------------------------------------------------
  void _confirmCancelExpense(BuildContext context, ExpenseModel e) {
    final cubit = context.read<FinancialsCubit>();
    final reasonController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(TablerIcons.alertTriangle, size: 20, color: AppColors.error),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text('Cancel & Reverse Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel expense #${e.id} (${e.category}: ₹${e.amount.toStringAsFixed(2)})?'),
            const SizedBox(height: 6),
            const Text(
              'This will post a balanced reversal entry returning funds to the payment account.',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Cancellation Reason *',
              controller: reasonController,
            ),
          ],
        ),
        actions: [
          AppButton.ghost(
            label: 'Back',
            onPressed: () => Navigator.of(dialogCtx).pop(),
          ),
          AppButton.danger(
            label: 'Confirm Reversal',
            icon: TablerIcons.arrowBackUp,
            onPressed: () async {
              try {
                await cubit.cancelExpense(e.id, reason: reasonController.text.trim());
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Expense reversed and funds credited back'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (err) {
                if (dialogCtx.mounted) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    SnackBar(content: Text(err.toString()), backgroundColor: AppColors.error),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: Inter-Account Transfer
  // ---------------------------------------------------------------------------
  void _openTransferDialog(BuildContext context, FinancialsState state) {
    final cubit = context.read<FinancialsCubit>();
    final amountController = TextEditingController();
    final narrationController = TextEditingController();

    int fromAccId = state.accounts.isNotEmpty ? state.accounts.first.id : 1;
    int toAccId = state.accounts.length > 1 ? state.accounts[1].id : 2;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(TablerIcons.arrowsExchange, size: 20, color: Colors.blue),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Text('Inter-Account Transfer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppDropdown<int>(
                      label: 'From Source Account',
                      value: fromAccId,
                      items: state.accounts
                          .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (Bal: ₹${a.balance.toStringAsFixed(0)})')))
                          .toList(),
                      onChanged: (id) {
                        if (id != null) setDialogState(() => fromAccId = id);
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppDropdown<int>(
                      label: 'To Destination Account',
                      value: toAccId,
                      items: state.accounts
                          .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (Bal: ₹${a.balance.toStringAsFixed(0)})')))
                          .toList(),
                      onChanged: (id) {
                        if (id != null) setDialogState(() => toAccId = id);
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AmountField(
                      label: 'Transfer Amount (INR)',
                      controller: amountController,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Transfer Note / Cheque Ref',
                      hint: 'e.g. Cash deposit to bank',
                      controller: narrationController,
                      prefixIcon: const Icon(TablerIcons.notes, size: 18),
                    ),
                  ],
                ),
              ),
              actions: [
                AppButton.ghost(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                ),
                AppButton.primary(
                  label: 'Confirm Transfer',
                  icon: TablerIcons.check,
                  onPressed: () async {
                    final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (amt <= 0) return;
                    try {
                      await cubit.transferFunds(
                        fromAccountId: fromAccId,
                        toAccountId: toAccId,
                        amount: amt,
                        narration: narrationController.text.trim().isEmpty ? null : narrationController.text.trim(),
                      );
                      if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Funds transferred and balanced in double-entry ledger'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (dialogCtx.mounted) {
                        ScaffoldMessenger.of(dialogCtx).showSnackBar(
                          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: Record Money Received
  // ---------------------------------------------------------------------------
  void _openMoneyReceivedDialog(BuildContext context, FinancialsState state) {
    final cubit = context.read<FinancialsCubit>();
    final amountController = TextEditingController();
    final refController = TextEditingController();
    final descController = TextEditingController();

    String category = 'other_income';
    int accountId = state.accounts.isNotEmpty ? state.accounts.first.id : 1;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.successContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(TablerIcons.arrowDownLeft, size: 20, color: AppColors.success),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text('Record Money Received', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppDropdown<String>(
                label: 'Receipt Category',
                value: category,
                items: const [
                  DropdownMenuItem(value: 'other_income', child: Text('Other Business Income')),
                  DropdownMenuItem(value: 'advance', child: Text('Customer Advance Receipt')),
                  DropdownMenuItem(value: 'scrap_sales', child: Text('Scrap / Sundry Sales')),
                  DropdownMenuItem(value: 'interest', child: Text('Bank Interest Received')),
                ],
                onChanged: (cat) {
                  if (cat != null) category = cat;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AmountField(
                label: 'Amount Received (INR)',
                controller: amountController,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppDropdown<int>(
                label: 'Deposit Into Account',
                value: accountId,
                items: state.accounts
                    .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.type.toUpperCase()})')))
                    .toList(),
                onChanged: (id) {
                  if (id != null) accountId = id;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Receipt / UTR Reference No',
                hint: 'e.g. UTR-829103 or Ref #',
                controller: refController,
                prefixIcon: const Icon(TablerIcons.tag, size: 18),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Receipt Description',
                hint: 'Source of funds / details',
                controller: descController,
                prefixIcon: const Icon(TablerIcons.notes, size: 18),
              ),
            ],
          ),
        ),
        actions: [
          AppButton.ghost(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogCtx).pop(),
          ),
          AppButton.primary(
            label: 'Save Receipt',
            icon: TablerIcons.check,
            onPressed: () async {
              final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
              if (amt <= 0) return;
              try {
                await cubit.recordMoneyReceived(
                  accountId: accountId,
                  amount: amt,
                  category: category,
                  referenceNo: refController.text.trim().isEmpty ? null : refController.text.trim(),
                  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                );
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Receipt recorded into ledger'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (dialogCtx.mounted) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: Record Money Paid
  // ---------------------------------------------------------------------------
  void _openMoneyPaidDialog(BuildContext context, FinancialsState state) {
    final cubit = context.read<FinancialsCubit>();
    final amountController = TextEditingController();
    final refController = TextEditingController();
    final descController = TextEditingController();

    String category = 'other_expense';
    int accountId = state.accounts.length > 1 ? state.accounts[1].id : 1;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(TablerIcons.arrowUpRight, size: 20, color: AppColors.error),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text('Record Money Paid', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppDropdown<String>(
                label: 'Payment Category',
                value: category,
                items: const [
                  DropdownMenuItem(value: 'other_expense', child: Text('General Business Payment')),
                  DropdownMenuItem(value: 'supplier_advance', child: Text('Supplier Advance Payment')),
                  DropdownMenuItem(value: 'equipment_purchase', child: Text('Asset / Equipment Purchase')),
                  DropdownMenuItem(value: 'loan_repayment', child: Text('Loan Repayment')),
                ],
                onChanged: (cat) {
                  if (cat != null) category = cat;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AmountField(
                label: 'Amount Paid (INR)',
                controller: amountController,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppDropdown<int>(
                label: 'Disburse From Account',
                value: accountId,
                items: state.accounts
                    .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.type.toUpperCase()})')))
                    .toList(),
                onChanged: (id) {
                  if (id != null) accountId = id;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Cheque / UTR Reference No',
                hint: 'e.g. Cheque #492810',
                controller: refController,
                prefixIcon: const Icon(TablerIcons.tag, size: 18),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Payment Description',
                hint: 'Purpose of disbursement',
                controller: descController,
                prefixIcon: const Icon(TablerIcons.notes, size: 18),
              ),
            ],
          ),
        ),
        actions: [
          AppButton.ghost(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogCtx).pop(),
          ),
          AppButton.primary(
            label: 'Save Disbursement',
            icon: TablerIcons.check,
            onPressed: () async {
              final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
              if (amt <= 0) return;
              try {
                await cubit.recordMoneyPaid(
                  accountId: accountId,
                  amount: amt,
                  category: category,
                  referenceNo: refController.text.trim().isEmpty ? null : refController.text.trim(),
                  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                );
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Disbursement recorded into double-entry ledger'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (dialogCtx.mounted) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: Create or Edit Account
  // ---------------------------------------------------------------------------
  void _openAccountEditor(BuildContext context, {AccountModel? existing}) {
    final cubit = context.read<FinancialsCubit>();
    final nameController = TextEditingController(text: existing?.name ?? '');
    final accNoController = TextEditingController(text: existing?.accountNumber ?? '');
    final bankNameController = TextEditingController(text: existing?.bankName ?? '');
    final ifscController = TextEditingController(text: existing?.ifsc ?? '');
    final upiIdController = TextEditingController(text: existing?.upiId ?? '');
    final balController = TextEditingController(text: existing != null ? existing.balance.toStringAsFixed(2) : '0.00');

    String selectedType = existing?.type ?? 'bank';
    bool isDefault = existing?.isDefault ?? false;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(TablerIcons.buildingBank, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  existing != null ? 'Edit Account' : 'Create Payment Account',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTextField(
                      label: 'Account Name *',
                      hint: 'e.g. HDFC Main Current A/C',
                      controller: nameController,
                      prefixIcon: const Icon(TablerIcons.id, size: 18),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppDropdown<String>(
                      label: 'Account Type',
                      value: selectedType,
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash Drawer / Cash Box')),
                        DropdownMenuItem(value: 'bank', child: Text('Bank Account (Current/Savings)')),
                        DropdownMenuItem(value: 'upi', child: Text('UPI / Digital Merchant Wallet')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (selectedType == 'bank') ...[
                      AppTextField(
                        label: 'Bank Name',
                        hint: 'e.g. State Bank of India',
                        controller: bankNameController,
                        prefixIcon: const Icon(TablerIcons.building, size: 18),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        label: 'Account Number',
                        hint: 'Bank Account Number',
                        controller: accNoController,
                        prefixIcon: const Icon(TablerIcons.numbers, size: 18),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        label: 'IFSC Code',
                        hint: '11-character code',
                        controller: ifscController,
                        prefixIcon: const Icon(TablerIcons.barcode, size: 18),
                      ),
                    ] else if (selectedType == 'upi') ...[
                      AppTextField(
                        label: 'UPI VPA / Handle',
                        hint: 'e.g. darvigrain@upi',
                        controller: upiIdController,
                        prefixIcon: const Icon(TablerIcons.qrcode, size: 18),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    if (existing == null) ...[
                      AmountField(
                        label: 'Opening Balance (INR)',
                        controller: balController,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Set as Default Account', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Used as primary checkout payment destination', style: TextStyle(fontSize: 12)),
                      value: isDefault,
                      activeTrackColor: AppColors.primary,
                      onChanged: (v) => setDialogState(() => isDefault = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              AppButton.ghost(
                label: 'Cancel',
                onPressed: () => Navigator.of(dialogCtx).pop(),
              ),
              AppButton.primary(
                label: 'Save Account',
                icon: TablerIcons.check,
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;

                  try {
                    if (existing != null) {
                      await cubit.updateAccount(
                        id: existing.id,
                        name: name,
                        type: selectedType,
                        accountNumber: accNoController.text.trim().isEmpty ? null : accNoController.text.trim(),
                        bankName: bankNameController.text.trim().isEmpty ? null : bankNameController.text.trim(),
                        ifsc: ifscController.text.trim().isEmpty ? null : ifscController.text.trim(),
                        upiId: upiIdController.text.trim().isEmpty ? null : upiIdController.text.trim(),
                        isDefault: isDefault,
                      );
                    } else {
                      await cubit.createAccount(
                        name: name,
                        type: selectedType,
                        accountNumber: accNoController.text.trim().isEmpty ? null : accNoController.text.trim(),
                        bankName: bankNameController.text.trim().isEmpty ? null : bankNameController.text.trim(),
                        ifsc: ifscController.text.trim().isEmpty ? null : ifscController.text.trim(),
                        upiId: upiIdController.text.trim().isEmpty ? null : upiIdController.text.trim(),
                        initialBalance: double.tryParse(balController.text.trim()) ?? 0.0,
                        isDefault: isDefault,
                      );
                    }
                    if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Account configuration saved successfully'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (dialogCtx.mounted) {
                      ScaffoldMessenger.of(dialogCtx).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: Deactivate Account
  // ---------------------------------------------------------------------------
  void _confirmDeactivateAccount(BuildContext context, AccountModel a) async {
    final cubit = context.read<FinancialsCubit>();
    final confirmed = await AppDialog.showDestructive(
      context: context,
      title: 'Deactivate ${a.name}',
      message: 'Are you sure you want to deactivate "${a.name}"?\nCurrent Balance: ₹${a.balance.toStringAsFixed(2)}. If balance is non-zero, please transfer funds first.',
      confirmLabel: 'Deactivate',
    );

    if (confirmed == true && context.mounted) {
      try {
        await cubit.deactivateAccount(a.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account deactivated successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}
