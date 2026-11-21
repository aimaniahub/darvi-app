import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/app_models.dart';
import '../../../../core/widgets/widgets.dart';
import '../cubit/parties_cubit.dart';

/// Redesigned Parties (Customers & Suppliers) Management page for Darvi Billing & ERP.
/// Implements Phase 3 Design System (Kite UI / Flutter Templates architecture).
class PartiesPage extends StatelessWidget {
  const PartiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    return BlocProvider(
      create: (_) => PartiesCubit(
        partyRepository: deps.partyRepository,
        ledgerRepository: deps.ledgerRepository,
        accountRepository: deps.accountRepository,
      )..load(),
      child: const _PartiesView(),
    );
  }
}

class _PartiesView extends StatefulWidget {
  const _PartiesView();

  @override
  State<_PartiesView> createState() => _PartiesViewState();
}

class _PartiesViewState extends State<_PartiesView> {
  final TextEditingController _searchController = TextEditingController();
  String _activeFilter = 'ALL';
  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CustomerModel> _getFilteredCustomers(List<CustomerModel> customers) {
    var list = customers;
    if (_activeFilter == 'WITH_BALANCE') {
      list = list.where((c) => c.balance > 0).toList();
    } else if (_activeFilter == 'ACTIVE') {
      list = list.where((c) => c.isActive).toList();
    } else if (_activeFilter == 'INACTIVE') {
      list = list.where((c) => !c.isActive).toList();
    }

    if (_sortColumnIndex != null) {
      list.sort((a, b) {
        int comparison;
        switch (_sortColumnIndex) {
          case 0:
            comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            break;
          case 4:
            comparison = a.creditLimit.compareTo(b.creditLimit);
            break;
          case 5:
            comparison = a.balance.compareTo(b.balance);
            break;
          default:
            comparison = 0;
        }
        return _sortAscending ? comparison : -comparison;
      });
    }
    return list;
  }

  List<SupplierModel> _getFilteredSuppliers(List<SupplierModel> suppliers) {
    var list = suppliers;
    if (_activeFilter == 'WITH_BALANCE') {
      list = list.where((s) => s.balance > 0).toList();
    } else if (_activeFilter == 'ACTIVE') {
      list = list.where((s) => s.isActive).toList();
    } else if (_activeFilter == 'INACTIVE') {
      list = list.where((s) => !s.isActive).toList();
    }

    if (_sortColumnIndex != null) {
      list.sort((a, b) {
        int comparison;
        switch (_sortColumnIndex) {
          case 0:
            comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            break;
          case 5:
            comparison = a.balance.compareTo(b.balance);
            break;
          default:
            comparison = 0;
        }
        return _sortAscending ? comparison : -comparison;
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PartiesCubit, PartiesState>(
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
        final cubit = context.read<PartiesCubit>();
        final isCustomers = state.selectedTab == 0;
        final filteredCustomers = _getFilteredCustomers(state.filteredCustomers);
        final filteredSuppliers = _getFilteredSuppliers(state.filteredSuppliers);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppHeader(
            title: isCustomers ? 'Customer & Receivables' : 'Supplier & Payables',
            subtitle: isCustomers
                ? 'Client balances, credit management & receivables tracking'
                : 'Vendor profiles, inward procurement & payable disbursement',
            actions: [
              IconButton(
                icon: const Icon(TablerIcons.refresh, color: AppColors.textPrimary),
                tooltip: 'Refresh Parties Directory',
                onPressed: () => cubit.load(),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    _buildTabButton(
                      context,
                      label: 'Customers (${state.customers.length})',
                      icon: TablerIcons.users,
                      isSelected: isCustomers,
                      onTap: () {
                        if (!isCustomers) cubit.setTab(0);
                      },
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _buildTabButton(
                      context,
                      label: 'Suppliers (${state.suppliers.length})',
                      icon: TablerIcons.buildingStore,
                      isSelected: !isCustomers,
                      onTap: () {
                        if (isCustomers) cubit.setTab(1);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 768;

              return RefreshIndicator(
                onRefresh: () => cubit.load(),
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Overview KPI Grid
                      if (isCustomers)
                        _buildCustomerKpiGrid(context, state)
                      else
                        _buildSupplierKpiGrid(context, state),
                      const SizedBox(height: AppSpacing.lg),

                      // Filter Bar & Action Strip
                      AppFilterBar(
                        searchController: _searchController,
                        searchHint: isCustomers
                            ? 'Search customer by legal name, code, phone, GSTIN...'
                            : 'Search supplier by vendor name, code, contact person, phone...',
                        onSearchChanged: (query) => cubit.search(query),
                        onSearchClear: () {
                          _searchController.clear();
                          cubit.search('');
                        },
                        filterOptions: [
                          const FilterOption(id: 'ALL', label: 'All Parties'),
                          FilterOption(
                            id: 'WITH_BALANCE',
                            label: isCustomers ? 'With Dues' : 'With Payables',
                          ),
                          const FilterOption(id: 'ACTIVE', label: 'Active'),
                          const FilterOption(id: 'INACTIVE', label: 'Inactive'),
                        ],
                        selectedFilterId: _activeFilter,
                        onFilterSelected: (id) => setState(() => _activeFilter = id),
                        trailingAction: AppButton.primary(
                          label: isCustomers ? '+ New Customer' : '+ New Supplier',
                          icon: isCustomers ? TablerIcons.userPlus : TablerIcons.buildingPlus,
                          onPressed: () => _openPartyEditor(context, isCustomer: isCustomers),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Main Content Directory (Desktop Table vs Mobile Cards)
                      if (state.loading && state.customers.isEmpty && state.suppliers.isEmpty)
                        const AppLoadingSkeleton(count: 6)
                      else if (isCustomers)
                        filteredCustomers.isEmpty
                            ? AppEmptyState(
                                title: 'No Customers Found',
                                message: _searchController.text.isNotEmpty || _activeFilter != 'ALL'
                                    ? 'No customer records match your current search and filter criteria.'
                                    : 'Start registering customers to track credit limits and receivables.',
                                icon: TablerIcons.userOff,
                                action: _searchController.text.isNotEmpty || _activeFilter != 'ALL'
                                    ? AppButton.outlined(
                                        label: 'Clear Filters',
                                        onPressed: () {
                                          _searchController.clear();
                                          cubit.search('');
                                          setState(() => _activeFilter = 'ALL');
                                        },
                                      )
                                    : AppButton.primary(
                                        label: 'Register First Customer',
                                        icon: TablerIcons.userPlus,
                                        onPressed: () => _openPartyEditor(context, isCustomer: true),
                                      ),
                              )
                            : isDesktop
                                ? _buildCustomerDesktopTable(context, filteredCustomers)
                                : _buildCustomerMobileList(context, filteredCustomers)
                      else
                        filteredSuppliers.isEmpty
                            ? AppEmptyState(
                                title: 'No Suppliers Found',
                                message: _searchController.text.isNotEmpty || _activeFilter != 'ALL'
                                    ? 'No supplier records match your current search and filter criteria.'
                                    : 'Register inward suppliers to manage purchase orders and payables.',
                                icon: TablerIcons.buildingOff,
                                action: _searchController.text.isNotEmpty || _activeFilter != 'ALL'
                                    ? AppButton.outlined(
                                        label: 'Clear Filters',
                                        onPressed: () {
                                          _searchController.clear();
                                          cubit.search('');
                                          setState(() => _activeFilter = 'ALL');
                                        },
                                      )
                                    : AppButton.primary(
                                        label: 'Register First Supplier',
                                        icon: TablerIcons.buildingPlus,
                                        onPressed: () => _openPartyEditor(context, isCustomer: false),
                                      ),
                              )
                            : isDesktop
                                ? _buildSupplierDesktopTable(context, filteredSuppliers)
                                : _buildSupplierMobileList(context, filteredSuppliers),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTabButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerKpiGrid(BuildContext context, PartiesState state) {
    double totalDue = 0.0;
    double totalAdvance = 0.0;
    int countWithDue = 0;
    int activeCount = 0;

    for (final c in state.customers) {
      if (c.isActive) activeCount++;
      if (c.balance > 0) {
        totalDue += c.balance;
        countWithDue++;
      } else if (c.balance < 0) {
        totalAdvance += c.balance.abs();
      }
    }

    return AppStatGrid(
      children: [
        AppStatCard(
          title: 'Total Customers',
          value: '${state.customers.length}',
          subtitle: '$activeCount active accounts',
          icon: TablerIcons.users,
          accentColor: AppColors.primary,
        ),
        AppStatCard(
          title: 'Total Receivables',
          value: '₹${totalDue.toStringAsFixed(2)}',
          subtitle: '$countWithDue customers with balance',
          icon: TablerIcons.arrowDownLeft,
          accentColor: totalDue > 0 ? AppColors.error : AppColors.success,
        ),
        AppStatCard(
          title: 'Advance Credits',
          value: '₹${totalAdvance.toStringAsFixed(2)}',
          subtitle: 'Prepaid customer balances',
          icon: TablerIcons.wallet,
          accentColor: AppColors.leafAccent,
        ),
        AppStatCard(
          title: 'Settled Accounts',
          value: '${state.customers.length - countWithDue}',
          subtitle: 'Zero outstanding dues',
          icon: TablerIcons.circleCheck,
          accentColor: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildSupplierKpiGrid(BuildContext context, PartiesState state) {
    double totalPayable = 0.0;
    double totalAdvance = 0.0;
    int countWithDue = 0;
    int activeCount = 0;

    for (final s in state.suppliers) {
      if (s.isActive) activeCount++;
      if (s.balance > 0) {
        totalPayable += s.balance;
        countWithDue++;
      } else if (s.balance < 0) {
        totalAdvance += s.balance.abs();
      }
    }

    return AppStatGrid(
      children: [
        AppStatCard(
          title: 'Total Suppliers',
          value: '${state.suppliers.length}',
          subtitle: '$activeCount active vendors',
          icon: TablerIcons.buildingStore,
          accentColor: AppColors.primary,
        ),
        AppStatCard(
          title: 'Total Payables',
          value: '₹${totalPayable.toStringAsFixed(2)}',
          subtitle: '$countWithDue pending disbursements',
          icon: TablerIcons.arrowUpRight,
          accentColor: totalPayable > 0 ? AppColors.error : AppColors.success,
        ),
        AppStatCard(
          title: 'Advance Disbursed',
          value: '₹${totalAdvance.toStringAsFixed(2)}',
          subtitle: 'Advance supplier payouts',
          icon: TablerIcons.cash,
          accentColor: AppColors.leafAccent,
        ),
        AppStatCard(
          title: 'Settled Vendors',
          value: '${state.suppliers.length - countWithDue}',
          subtitle: 'Zero outstanding balance',
          icon: TablerIcons.circleCheck,
          accentColor: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildCustomerDesktopTable(BuildContext context, List<CustomerModel> customers) {
    return AppDataTable<CustomerModel>(
      minWidth: 980,
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      onSort: (columnIndex, ascending) {
        setState(() {
          _sortColumnIndex = columnIndex;
          _sortAscending = ascending;
        });
      },
      onRowTap: (c) => _openCustomerProfileSheet(context, c.id),
      columns: [
        AppDataColumn<CustomerModel>(
          title: 'Customer Name & Code',
          sortable: true,
          cellBuilder: (ctx, c, _) => Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: c.balance > 0
                    ? AppColors.error.withValues(alpha: 0.12)
                    : AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: c.balance > 0 ? AppColors.error : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (c.code != null && c.code!.isNotEmpty)
                      Text(
                        'Code: ${c.code}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        AppDataColumn<CustomerModel>(
          title: 'Contact Details',
          width: 170,
          cellBuilder: (ctx, c, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                c.phone ?? 'No phone',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              if (c.email != null && c.email!.isNotEmpty)
                Text(
                  c.email!,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        AppDataColumn<CustomerModel>(
          title: 'Classification',
          width: 140,
          cellBuilder: (ctx, c, _) => AppBadge(
            label: c.customerType.toUpperCase(),
            tone: c.customerType == 'business'
                ? AppBadgeTone.info
                : c.customerType == 'gst_registered'
                    ? AppBadgeTone.success
                    : AppBadgeTone.neutral,
          ),
        ),
        AppDataColumn<CustomerModel>(
          title: 'Credit Terms',
          width: 140,
          sortable: true,
          cellBuilder: (ctx, c, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Limit: ₹${c.creditLimit.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              Text(
                'Period: ${c.creditPeriodDays}d',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        AppDataColumn<CustomerModel>(
          title: 'Balance & Status',
          width: 170,
          sortable: true,
          cellBuilder: (ctx, c, _) {
            if (c.balance > 0) {
              return AppBadge.error(label: 'Due: ₹${c.balance.toStringAsFixed(2)}');
            } else if (c.balance < 0) {
              return AppBadge.info(label: 'Advance: ₹${c.balance.abs().toStringAsFixed(2)}');
            } else {
              return const AppBadge.success(label: 'Settled (₹0.00)');
            }
          },
        ),
        AppDataColumn<CustomerModel>(
          title: 'Actions',
          width: 110,
          alignment: Alignment.centerRight,
          cellBuilder: (ctx, c, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(TablerIcons.eye, size: 18, color: AppColors.primary),
                tooltip: 'Profile & Statement',
                onPressed: () => _openCustomerProfileSheet(context, c.id),
              ),
              PopupMenuButton<String>(
                icon: const Icon(TablerIcons.dotsVertical, size: 18, color: AppColors.textSecondary),
                tooltip: 'Customer Actions',
                onSelected: (action) {
                  if (action == 'collect') {
                    _openCollectionDialog(context, c);
                  } else if (action == 'edit') {
                    _openPartyEditor(context, isCustomer: true, existingCustomer: c);
                  } else if (action == 'adjust') {
                    _openOpeningBalanceDialog(
                      context,
                      isCustomer: true,
                      partyId: c.id,
                      currentOpeningBalance: c.openingBalance,
                      partyName: c.name,
                    );
                  } else if (action == 'delete') {
                    _confirmDeleteParty(context, isCustomer: true, id: c.id, name: c.name);
                  }
                },
                itemBuilder: (popCtx) => [
                  if (c.balance > 0)
                    const PopupMenuItem(
                      value: 'collect',
                      child: Row(
                        children: [
                          Icon(TablerIcons.cashBanknote, size: 18, color: AppColors.success),
                          SizedBox(width: 8),
                          Text('Collect Receivable'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(TablerIcons.edit, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Edit Customer'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'adjust',
                    child: Row(
                      children: [
                        Icon(TablerIcons.adjustments, size: 18, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Adjust Opening Bal'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(TablerIcons.trash, size: 18, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Deactivate / Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      items: customers,
    );
  }

  Widget _buildCustomerMobileList(BuildContext context, List<CustomerModel> customers) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: customers.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (ctx, index) {
        final c = customers[index];
        final hasDue = c.balance > 0;
        final isAdvance = c.balance < 0;

        return AppCard.bordered(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: InkWell(
            onTap: () => _openCustomerProfileSheet(context, c.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: hasDue
                          ? AppColors.error.withValues(alpha: 0.12)
                          : AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: hasDue ? AppColors.error : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              if (c.code != null && c.code!.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                AppBadge.neutral(label: c.code!),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${c.phone ?? "No mobile"} • ${c.address ?? "No address"}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Credit Limit: ₹${c.creditLimit.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                        Text(
                          'Class: ${c.customerType.toUpperCase()}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (hasDue)
                          AppBadge.error(label: 'Due: ₹${c.balance.toStringAsFixed(2)}')
                        else if (isAdvance)
                          AppBadge.info(label: 'Advance: ₹${c.balance.abs().toStringAsFixed(2)}')
                        else
                          const AppBadge.success(label: 'Settled'),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          icon: const Icon(TablerIcons.dotsVertical, size: 18),
                          onSelected: (action) {
                            if (action == 'profile') {
                              _openCustomerProfileSheet(context, c.id);
                            } else if (action == 'collect') {
                              _openCollectionDialog(context, c);
                            } else if (action == 'edit') {
                              _openPartyEditor(context, isCustomer: true, existingCustomer: c);
                            } else if (action == 'adjust') {
                              _openOpeningBalanceDialog(
                                context,
                                isCustomer: true,
                                partyId: c.id,
                                currentOpeningBalance: c.openingBalance,
                                partyName: c.name,
                              );
                            } else if (action == 'delete') {
                              _confirmDeleteParty(context, isCustomer: true, id: c.id, name: c.name);
                            }
                          },
                          itemBuilder: (popCtx) => [
                            const PopupMenuItem(
                              value: 'profile',
                              child: Row(
                                children: [
                                  Icon(TablerIcons.fileInvoice, size: 18),
                                  SizedBox(width: 8),
                                  Text('Statement & History'),
                                ],
                              ),
                            ),
                            if (hasDue)
                              const PopupMenuItem(
                                value: 'collect',
                                child: Row(
                                  children: [
                                    Icon(TablerIcons.cashBanknote, size: 18, color: AppColors.success),
                                    SizedBox(width: 8),
                                    Text('Collect Receivable'),
                                  ],
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(TablerIcons.edit, size: 18, color: AppColors.primary),
                                  SizedBox(width: 8),
                                  Text('Edit Profile'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'adjust',
                              child: Row(
                                children: [
                                  Icon(TablerIcons.adjustments, size: 18, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text('Adjust Opening Bal'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(TablerIcons.trash, size: 18, color: AppColors.error),
                                  SizedBox(width: 8),
                                  Text('Deactivate / Delete'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildSupplierDesktopTable(BuildContext context, List<SupplierModel> suppliers) {
    return AppDataTable<SupplierModel>(
      minWidth: 980,
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      onSort: (columnIndex, ascending) {
        setState(() {
          _sortColumnIndex = columnIndex;
          _sortAscending = ascending;
        });
      },
      onRowTap: (s) => _openSupplierProfileSheet(context, s.id),
      columns: [
        AppDataColumn<SupplierModel>(
          title: 'Supplier Name & Code',
          sortable: true,
          cellBuilder: (ctx, s, _) => Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: s.balance > 0
                    ? AppColors.error.withValues(alpha: 0.12)
                    : AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: s.balance > 0 ? AppColors.error : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (s.code != null && s.code!.isNotEmpty)
                      Text(
                        'Code: ${s.code}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        AppDataColumn<SupplierModel>(
          title: 'Contact Person & Phone',
          width: 180,
          cellBuilder: (ctx, s, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.contactPerson ?? 'Direct Supplier',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                s.phone ?? 'No phone',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        AppDataColumn<SupplierModel>(
          title: 'GSTIN / State',
          width: 160,
          cellBuilder: (ctx, s, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.gstin ?? 'Unregistered',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                s.state,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        AppDataColumn<SupplierModel>(
          title: 'Payment Terms',
          width: 140,
          cellBuilder: (ctx, s, _) => AppBadge.neutral(
            label: s.paymentTerms.isNotEmpty ? s.paymentTerms : 'Immediate',
          ),
        ),
        AppDataColumn<SupplierModel>(
          title: 'Payable Due',
          width: 170,
          sortable: true,
          cellBuilder: (ctx, s, _) {
            if (s.balance > 0) {
              return AppBadge.error(label: 'Due: ₹${s.balance.toStringAsFixed(2)}');
            } else if (s.balance < 0) {
              return AppBadge.info(label: 'Advance: ₹${s.balance.abs().toStringAsFixed(2)}');
            } else {
              return const AppBadge.success(label: 'Settled (₹0.00)');
            }
          },
        ),
        AppDataColumn<SupplierModel>(
          title: 'Actions',
          width: 110,
          alignment: Alignment.centerRight,
          cellBuilder: (ctx, s, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(TablerIcons.eye, size: 18, color: AppColors.primary),
                tooltip: 'Profile & Statement',
                onPressed: () => _openSupplierProfileSheet(context, s.id),
              ),
              PopupMenuButton<String>(
                icon: const Icon(TablerIcons.dotsVertical, size: 18, color: AppColors.textSecondary),
                tooltip: 'Supplier Actions',
                onSelected: (action) {
                  if (action == 'pay') {
                    _openPayoutDialog(context, s);
                  } else if (action == 'edit') {
                    _openPartyEditor(context, isCustomer: false, existingSupplier: s);
                  } else if (action == 'adjust') {
                    _openOpeningBalanceDialog(
                      context,
                      isCustomer: false,
                      partyId: s.id,
                      currentOpeningBalance: s.openingBalance,
                      partyName: s.name,
                    );
                  } else if (action == 'delete') {
                    _confirmDeleteParty(context, isCustomer: false, id: s.id, name: s.name);
                  }
                },
                itemBuilder: (popCtx) => [
                  if (s.balance > 0)
                    const PopupMenuItem(
                      value: 'pay',
                      child: Row(
                        children: [
                          Icon(TablerIcons.cashBanknote, size: 18, color: AppColors.success),
                          SizedBox(width: 8),
                          Text('Pay Supplier'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(TablerIcons.edit, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Edit Supplier'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'adjust',
                    child: Row(
                      children: [
                        Icon(TablerIcons.adjustments, size: 18, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Adjust Opening Bal'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(TablerIcons.trash, size: 18, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Deactivate / Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      items: suppliers,
    );
  }

  Widget _buildSupplierMobileList(BuildContext context, List<SupplierModel> suppliers) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: suppliers.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (ctx, index) {
        final s = suppliers[index];
        final hasDue = s.balance > 0;
        final isAdvance = s.balance < 0;

        return AppCard.bordered(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: InkWell(
            onTap: () => _openSupplierProfileSheet(context, s.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: hasDue
                          ? AppColors.error.withValues(alpha: 0.12)
                          : AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: hasDue ? AppColors.error : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              if (s.code != null && s.code!.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                AppBadge.neutral(label: s.code!),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s.contactPerson != null ? "${s.contactPerson} • " : ""}${s.phone ?? "No mobile"}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terms: ${s.paymentTerms}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                        Text(
                          'GST: ${s.gstin ?? "Unregistered"}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (hasDue)
                          AppBadge.error(label: 'Due: ₹${s.balance.toStringAsFixed(2)}')
                        else if (isAdvance)
                          AppBadge.info(label: 'Advance: ₹${s.balance.abs().toStringAsFixed(2)}')
                        else
                          const AppBadge.success(label: 'Settled'),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          icon: const Icon(TablerIcons.dotsVertical, size: 18),
                          onSelected: (action) {
                            if (action == 'profile') {
                              _openSupplierProfileSheet(context, s.id);
                            } else if (action == 'pay') {
                              _openPayoutDialog(context, s);
                            } else if (action == 'edit') {
                              _openPartyEditor(context, isCustomer: false, existingSupplier: s);
                            } else if (action == 'adjust') {
                              _openOpeningBalanceDialog(
                                context,
                                isCustomer: false,
                                partyId: s.id,
                                currentOpeningBalance: s.openingBalance,
                                partyName: s.name,
                              );
                            } else if (action == 'delete') {
                              _confirmDeleteParty(context, isCustomer: false, id: s.id, name: s.name);
                            }
                          },
                          itemBuilder: (popCtx) => [
                            const PopupMenuItem(
                              value: 'profile',
                              child: Row(
                                children: [
                                  Icon(TablerIcons.fileInvoice, size: 18),
                                  SizedBox(width: 8),
                                  Text('Statement & Inward History'),
                                ],
                              ),
                            ),
                            if (hasDue)
                              const PopupMenuItem(
                                value: 'pay',
                                child: Row(
                                  children: [
                                    Icon(TablerIcons.cashBanknote, size: 18, color: AppColors.success),
                                    SizedBox(width: 8),
                                    Text('Disburse Payment'),
                                  ],
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(TablerIcons.edit, size: 18, color: AppColors.primary),
                                  SizedBox(width: 8),
                                  Text('Edit Supplier'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'adjust',
                              child: Row(
                                children: [
                                  Icon(TablerIcons.adjustments, size: 18, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text('Adjust Opening Bal'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(TablerIcons.trash, size: 18, color: AppColors.error),
                                  SizedBox(width: 8),
                                  Text('Deactivate / Delete'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
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

  // ---------------------------------------------------------------------------
  // Profile Drawer: Customer
  // ---------------------------------------------------------------------------
  void _openCustomerProfileSheet(BuildContext context, int customerId) async {
    final deps = AppScope.of(context);
    final profile = await deps.partyRepository.getCustomerProfile(customerId);
    if (!context.mounted) return;

    final customer = profile['customer'] as CustomerModel;
    final sales = (profile['sales'] as List<dynamic>?) ?? [];
    final payments = (profile['payments'] as List<dynamic>?) ?? [];
    final statement = (profile['statement'] as List<LedgerEntryModel>?) ?? [];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return DefaultTabController(
          length: 4,
          child: Container(
            height: MediaQuery.of(sheetCtx).size.height * 0.9,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: customer.balance > 0
                            ? AppColors.error.withValues(alpha: 0.12)
                            : AppColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: customer.balance > 0 ? AppColors.error : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    customer.name,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AppBadge.neutral(
                                  label: customer.customerType.toUpperCase(),
                                ),
                              ],
                            ),
                            Text(
                              'Code: ${customer.code ?? "N/A"} • ${customer.phone ?? "No mobile"} • ${customer.state}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(TablerIcons.x),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                      ),
                    ],
                  ),
                ),

                // Metrics Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: customer.balance > 0
                                ? AppColors.errorContainer.withValues(alpha: 0.3)
                                : AppColors.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: customer.balance > 0
                                  ? AppColors.error.withValues(alpha: 0.2)
                                  : AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Outstanding Due', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              Text(
                                '₹${customer.balance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: customer.balance > 0 ? AppColors.error : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Credit Limit', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              Text(
                                '₹${customer.creditLimit.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Invoiced', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              Text(
                                '₹${(profile['total_sales'] as num? ?? 0.0).toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Tab Bar
                const TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  isScrollable: true,
                  tabs: [
                    Tab(icon: Icon(TablerIcons.infoCircle, size: 16), text: 'Overview'),
                    Tab(icon: Icon(TablerIcons.fileInvoice, size: 16), text: 'Invoices'),
                    Tab(icon: Icon(TablerIcons.cashBanknote, size: 16), text: 'Receipts'),
                    Tab(icon: Icon(TablerIcons.book, size: 16), text: 'Ledger Audit'),
                  ],
                ),
                const Divider(height: 1),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    children: [
                      // Overview
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            _buildDrawerRow('Customer Code:', customer.code ?? 'N/A'),
                            _buildDrawerRow('Mobile Phone:', customer.phone ?? 'N/A'),
                            _buildDrawerRow('Alternate Contact:', customer.alternatePhone ?? 'N/A'),
                            _buildDrawerRow('Email:', customer.email ?? 'N/A'),
                            _buildDrawerRow('Address:', customer.address ?? 'N/A'),
                            _buildDrawerRow('State:', customer.state),
                            _buildDrawerRow('GSTIN:', customer.gstin ?? 'Unregistered'),
                            _buildDrawerRow('Customer Type:', customer.customerType.toUpperCase()),
                            _buildDrawerRow('Credit Limit:', '₹${customer.creditLimit.toStringAsFixed(2)}'),
                            _buildDrawerRow('Credit Period:', '${customer.creditPeriodDays} Days'),
                            _buildDrawerRow('Opening Balance:', '₹${customer.openingBalance.toStringAsFixed(2)}'),
                            _buildDrawerRow('Total Purchases Made:', '₹${(profile['total_sales'] as num? ?? 0.0).toStringAsFixed(2)}'),
                            _buildDrawerRow('Total Collected:', '₹${(profile['total_collected'] as num? ?? 0.0).toStringAsFixed(2)}'),
                          ],
                        ),
                      ),
                      // Invoices
                      sales.isEmpty
                          ? const Center(child: Text('No sales invoices found for this customer'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: sales.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, idx) {
                                final s = sales[idx] as Map<String, dynamic>;
                                return ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: AppColors.primaryContainer,
                                    child: Icon(TablerIcons.fileInvoice, size: 18, color: AppColors.primary),
                                  ),
                                  title: Text('Invoice #${s['invoice_no']}'),
                                  subtitle: Text('Mode: ${s['payment_method']} • Date: ${s['created_at']?.toString().split("T").first ?? ""}'),
                                  trailing: Text(
                                    '₹${(s['total'] as num? ?? 0.0).toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                );
                              },
                            ),
                      // Receipts
                      payments.isEmpty
                          ? const Center(child: Text('No payment collections recorded'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: payments.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, idx) {
                                final p = payments[idx] as Map<String, dynamic>;
                                return ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: AppColors.successContainer,
                                    child: Icon(TablerIcons.circleCheck, size: 18, color: AppColors.success),
                                  ),
                                  title: Text('Receipt: ₹${(p['amount'] as num? ?? 0.0).toStringAsFixed(2)}'),
                                  subtitle: Text('Into: ${p['account_name'] ?? "Account"} • Ref: ${p['reference_no'] ?? "N/A"}\n${p['narration'] ?? ""}'),
                                );
                              },
                            ),
                      // Ledger Statement
                      statement.isEmpty
                          ? const Center(child: Text('No ledger entries recorded'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: statement.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, idx) {
                                final entry = statement[idx];
                                return ListTile(
                                  title: Text(entry.narration ?? '${entry.transactionType} entry'),
                                  subtitle: Text('${entry.createdAt.toString().split(".").first} • Type: ${entry.transactionType}'),
                                  trailing: Text(
                                    entry.debit > 0 ? '+Dr ₹${entry.debit.toStringAsFixed(2)}' : '-Cr ₹${entry.credit.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: entry.debit > 0 ? AppColors.error : AppColors.success,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),

                // Bottom Action
                if (customer.balance > 0)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: AppButton.primary(
                      label: 'Collect Outstanding Receivable (₹${customer.balance.toStringAsFixed(2)})',
                      icon: TablerIcons.cashBanknote,
                      expanded: true,
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        _openCollectionDialog(context, customer);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Profile Drawer: Supplier
  // ---------------------------------------------------------------------------
  void _openSupplierProfileSheet(BuildContext context, int supplierId) async {
    final deps = AppScope.of(context);
    final profile = await deps.partyRepository.getSupplierProfile(supplierId);
    if (!context.mounted) return;

    final supplier = profile['supplier'] as SupplierModel;
    final purchases = (profile['purchases'] as List<dynamic>?) ?? [];
    final payments = (profile['payments'] as List<dynamic>?) ?? [];
    final returns = (profile['returns'] as List<dynamic>?) ?? [];
    final statement = (profile['statement'] as List<LedgerEntryModel>?) ?? [];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return DefaultTabController(
          length: 5,
          child: Container(
            height: MediaQuery.of(sheetCtx).size.height * 0.9,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: supplier.balance > 0
                            ? AppColors.error.withValues(alpha: 0.12)
                            : AppColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : 'S',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: supplier.balance > 0 ? AppColors.error : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supplier.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Code: ${supplier.code ?? "N/A"} • Contact: ${supplier.contactPerson ?? "N/A"} • ${supplier.phone ?? "No mobile"}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(TablerIcons.x),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                      ),
                    ],
                  ),
                ),

                // Metrics Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: supplier.balance > 0
                                ? AppColors.errorContainer.withValues(alpha: 0.3)
                                : AppColors.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: supplier.balance > 0
                                  ? AppColors.error.withValues(alpha: 0.2)
                                  : AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Outstanding Payable', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              Text(
                                '₹${supplier.balance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: supplier.balance > 0 ? AppColors.error : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Inward Invoices', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              Text(
                                '₹${(profile['total_purchases'] as num? ?? 0.0).toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Disbursed', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              Text(
                                '₹${(profile['total_paid'] as num? ?? 0.0).toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.success),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Tab Bar
                const TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  isScrollable: true,
                  tabs: [
                    Tab(icon: Icon(TablerIcons.infoCircle, size: 16), text: 'Overview'),
                    Tab(icon: Icon(TablerIcons.buildingWarehouse, size: 16), text: 'Purchases'),
                    Tab(icon: Icon(TablerIcons.cashBanknote, size: 16), text: 'Payments'),
                    Tab(icon: Icon(TablerIcons.arrowBackUp, size: 16), text: 'Debit Notes'),
                    Tab(icon: Icon(TablerIcons.book, size: 16), text: 'Statement'),
                  ],
                ),
                const Divider(height: 1),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    children: [
                      // Overview
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            _buildDrawerRow('Supplier Code:', supplier.code ?? 'N/A'),
                            _buildDrawerRow('Contact Person:', supplier.contactPerson ?? 'N/A'),
                            _buildDrawerRow('Phone:', supplier.phone ?? 'N/A'),
                            _buildDrawerRow('Email:', supplier.email ?? 'N/A'),
                            _buildDrawerRow('GSTIN:', supplier.gstin ?? 'Unregistered'),
                            _buildDrawerRow('Address:', supplier.address ?? 'N/A'),
                            _buildDrawerRow('State:', supplier.state),
                            _buildDrawerRow('Payment Terms:', supplier.paymentTerms),
                            _buildDrawerRow('Opening Balance:', '₹${supplier.openingBalance.toStringAsFixed(2)}'),
                            _buildDrawerRow('Total Inward Invoices:', '₹${(profile['total_purchases'] as num? ?? 0.0).toStringAsFixed(2)}'),
                            _buildDrawerRow('Total Paid:', '₹${(profile['total_paid'] as num? ?? 0.0).toStringAsFixed(2)}'),
                          ],
                        ),
                      ),
                      // Purchases
                      purchases.isEmpty
                          ? const Center(child: Text('No inward bills recorded'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: purchases.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, idx) {
                                final p = purchases[idx] as Map<String, dynamic>;
                                return ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: AppColors.primaryContainer,
                                    child: Icon(TablerIcons.buildingWarehouse, size: 18, color: AppColors.primary),
                                  ),
                                  title: Text('Bill #${p['invoice_number']}'),
                                  subtitle: Text('Status: ${(p['status'] as String? ?? "unpaid").toUpperCase()} • Paid: ₹${(p['paid_amount'] as num? ?? 0.0).toStringAsFixed(0)}'),
                                  trailing: Text(
                                    '₹${(p['total_amount'] as num? ?? 0.0).toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                );
                              },
                            ),
                      // Payments
                      payments.isEmpty
                          ? const Center(child: Text('No disbursements recorded'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: payments.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, idx) {
                                final p = payments[idx] as Map<String, dynamic>;
                                return ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: AppColors.infoContainer,
                                    child: Icon(TablerIcons.arrowUpRight, size: 18, color: AppColors.info),
                                  ),
                                  title: Text('Paid: ₹${(p['amount'] as num? ?? 0.0).toStringAsFixed(2)}'),
                                  subtitle: Text('From: ${p['account_name'] ?? "Account"} • Ref: ${p['reference_no'] ?? "N/A"}'),
                                );
                              },
                            ),
                      // Debit Notes
                      returns.isEmpty
                          ? const Center(child: Text('No debit notes / returns'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: returns.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, idx) {
                                final r = returns[idx] as Map<String, dynamic>;
                                return ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: AppColors.warningContainer,
                                    child: Icon(TablerIcons.arrowBackUp, size: 18, color: AppColors.warning),
                                  ),
                                  title: Text('Debit Note #${r['debit_note_number']}'),
                                  subtitle: Text('Reason: ${r['reason'] ?? "N/A"}'),
                                  trailing: Text(
                                    '₹${(r['total_amount'] as num? ?? 0.0).toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.warning),
                                  ),
                                );
                              },
                            ),
                      // Statement
                      statement.isEmpty
                          ? const Center(child: Text('No ledger transactions recorded'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: statement.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, idx) {
                                final entry = statement[idx];
                                return ListTile(
                                  title: Text(entry.narration ?? '${entry.transactionType} entry'),
                                  subtitle: Text('${entry.createdAt.toString().split(".").first} • Type: ${entry.transactionType}'),
                                  trailing: Text(
                                    entry.credit > 0 ? '+Cr ₹${entry.credit.toStringAsFixed(2)}' : '-Dr ₹${entry.debit.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: entry.credit > 0 ? AppColors.error : AppColors.success,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),

                // Bottom Action
                if (supplier.balance > 0)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: AppButton.primary(
                      label: 'Pay Supplier Payable (₹${supplier.balance.toStringAsFixed(2)})',
                      icon: TablerIcons.cashBanknote,
                      expanded: true,
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        _openPayoutDialog(context, supplier);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawerRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: Collect Customer Receivable
  // ---------------------------------------------------------------------------
  void _openCollectionDialog(BuildContext context, CustomerModel customer) {
    final cubit = context.read<PartiesCubit>();
    final amountController = TextEditingController(text: customer.balance.toStringAsFixed(2));
    final refController = TextEditingController();
    int accountId = cubit.state.accounts.isNotEmpty ? cubit.state.accounts.first.id : 1;

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
              child: const Icon(TablerIcons.cashBanknote, size: 20, color: AppColors.success),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Collect From ${customer.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Outstanding Due:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(
                      '₹${customer.balance.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AmountField(
                label: 'Collection Amount (INR)',
                controller: amountController,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppDropdown<int>(
                label: 'Deposit Into Account',
                value: accountId,
                items: cubit.state.accounts.isNotEmpty
                    ? cubit.state.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (₹${a.balance.toStringAsFixed(0)})'))).toList()
                    : const [
                        DropdownMenuItem(value: 1, child: Text('Store Cash Drawer')),
                        DropdownMenuItem(value: 2, child: Text('Company Bank Account')),
                        DropdownMenuItem(value: 3, child: Text('Store UPI Account')),
                      ],
                onChanged: (val) {
                  if (val != null) accountId = val;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Receipt / UTR Reference No',
                hint: 'e.g. UTR-92841094 or Cheque #',
                controller: refController,
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
            label: 'Confirm Collection',
            icon: TablerIcons.check,
            onPressed: () async {
              final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
              if (amt <= 0) return;
              try {
                await cubit.recordCustomerReceipt(
                  customerId: customer.id,
                  accountId: accountId,
                  amount: amt,
                  referenceNo: refController.text.trim().isEmpty ? null : refController.text.trim(),
                  narration: 'Receipt collection from ${customer.name}',
                );
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Collection recorded and credited to customer ledger'),
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
  // Dialog: Pay Supplier Payable
  // ---------------------------------------------------------------------------
  void _openPayoutDialog(BuildContext context, SupplierModel supplier) {
    final cubit = context.read<PartiesCubit>();
    final amountController = TextEditingController(text: supplier.balance.toStringAsFixed(2));
    final refController = TextEditingController();
    int accountId = cubit.state.accounts.length > 1 ? cubit.state.accounts[1].id : 1;

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
            Expanded(
              child: Text(
                'Disburse to ${supplier.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Outstanding Payable:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(
                      '₹${supplier.balance.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AmountField(
                label: 'Disbursement Amount (INR)',
                controller: amountController,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppDropdown<int>(
                label: 'Disburse From Account',
                value: accountId,
                items: cubit.state.accounts.isNotEmpty
                    ? cubit.state.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (Bal: ₹${a.balance.toStringAsFixed(0)})'))).toList()
                    : const [
                        DropdownMenuItem(value: 1, child: Text('Store Cash Drawer')),
                        DropdownMenuItem(value: 2, child: Text('Company Bank Account')),
                        DropdownMenuItem(value: 3, child: Text('Store UPI Account')),
                      ],
                onChanged: (val) {
                  if (val != null) accountId = val;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Cheque / UTR Reference No',
                hint: 'e.g. UTR-4910284 or Cheque #',
                controller: refController,
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
            label: 'Confirm Disbursement',
            icon: TablerIcons.check,
            onPressed: () async {
              final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
              if (amt <= 0) return;
              try {
                await cubit.recordSupplierPayment(
                  supplierId: supplier.id,
                  accountId: accountId,
                  amount: amt,
                  referenceNo: refController.text.trim().isEmpty ? null : refController.text.trim(),
                  narration: 'Disbursement payment to ${supplier.name}',
                );
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Supplier disbursement recorded successfully in ledger'),
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
  // Dialog: Adjust Opening Balance
  // ---------------------------------------------------------------------------
  void _openOpeningBalanceDialog(
    BuildContext context, {
    required bool isCustomer,
    required int partyId,
    required double currentOpeningBalance,
    required String partyName,
  }) {
    final cubit = context.read<PartiesCubit>();
    final balController = TextEditingController(text: currentOpeningBalance.toStringAsFixed(2));
    final reasonController = TextEditingController(text: 'Audited balance reconciliation correction');

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
              child: const Icon(TablerIcons.adjustments, size: 20, color: Colors.orange),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Adjust Opening Balance • $partyName',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Corrections will generate an auditable ledger adjustment entry rather than destructively erasing ledger history.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              AmountField(
                label: 'New Opening Balance (INR)',
                controller: balController,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Audit Adjustment Reason',
                controller: reasonController,
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
            label: 'Post Adjustment',
            icon: TablerIcons.check,
            onPressed: () async {
              final newBal = double.tryParse(balController.text.trim()) ?? 0.0;
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;

              try {
                await cubit.adjustOpeningBalance(
                  partyType: isCustomer ? 'customer' : 'supplier',
                  partyId: partyId,
                  newOpeningBalance: newBal,
                  reason: reason,
                );
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Opening balance adjustment posted to double-entry ledger'),
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
  // Dialog: Deactivate / Delete Party
  // ---------------------------------------------------------------------------
  void _confirmDeleteParty(
    BuildContext context, {
    required bool isCustomer,
    required int id,
    required String name,
  }) async {
    final cubit = context.read<PartiesCubit>();
    final confirmed = await AppDialog.showDestructive(
      context: context,
      title: 'Deactivate ${isCustomer ? "Customer" : "Supplier"}',
      message: 'Are you sure you want to deactivate or remove "$name"?\nIf transactions exist in the ledger, the party will be safely deactivated to protect the audit trail.',
      confirmLabel: 'Confirm Deactivate',
    );

    if (confirmed == true && context.mounted) {
      try {
        if (isCustomer) {
          await cubit.deleteCustomer(id);
        } else {
          await cubit.deleteSupplier(id);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$name removed/deactivated successfully'),
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

  // ---------------------------------------------------------------------------
  // Modal Drawer / Sheet: Add or Edit Party
  // ---------------------------------------------------------------------------
  void _openPartyEditor(
    BuildContext context, {
    required bool isCustomer,
    CustomerModel? existingCustomer,
    SupplierModel? existingSupplier,
  }) {
    final cubit = context.read<PartiesCubit>();
    final isEditing = (isCustomer && existingCustomer != null) || (!isCustomer && existingSupplier != null);

    final nameController = TextEditingController(text: isCustomer ? existingCustomer?.name ?? '' : existingSupplier?.name ?? '');
    final codeController = TextEditingController(text: isCustomer ? existingCustomer?.code ?? '' : existingSupplier?.code ?? '');
    final phoneController = TextEditingController(text: isCustomer ? existingCustomer?.phone ?? '' : existingSupplier?.phone ?? '');
    final altPhoneController = TextEditingController(text: isCustomer ? existingCustomer?.alternatePhone ?? '' : '');
    final emailController = TextEditingController(text: isCustomer ? existingCustomer?.email ?? '' : existingSupplier?.email ?? '');
    final addressController = TextEditingController(text: isCustomer ? existingCustomer?.address ?? '' : existingSupplier?.address ?? '');
    final stateController = TextEditingController(text: isCustomer ? existingCustomer?.state ?? 'Karnataka' : existingSupplier?.state ?? 'Karnataka');
    final gstinController = TextEditingController(text: isCustomer ? existingCustomer?.gstin ?? '' : existingSupplier?.gstin ?? '');
    final contactPersonController = TextEditingController(text: !isCustomer ? existingSupplier?.contactPerson ?? '' : '');
    final paymentTermsController = TextEditingController(text: !isCustomer ? existingSupplier?.paymentTerms ?? '30 Days' : '');
    final creditLimitController = TextEditingController(text: isCustomer ? (existingCustomer?.creditLimit ?? 10000.0).toStringAsFixed(0) : '');
    final creditPeriodController = TextEditingController(text: isCustomer ? (existingCustomer?.creditPeriodDays ?? 30).toString() : '');
    final openingBalController = TextEditingController(
      text: isCustomer ? (existingCustomer?.openingBalance ?? 0.0).toStringAsFixed(0) : (existingSupplier?.openingBalance ?? 0.0).toStringAsFixed(0),
    );
    final notesController = TextEditingController(text: isCustomer ? existingCustomer?.notes ?? '' : existingSupplier?.notes ?? '');

    String customerType = existingCustomer?.customerType ?? 'individual';
    bool isActive = isCustomer ? (existingCustomer?.isActive ?? true) : (existingSupplier?.isActive ?? true);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Material(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: MediaQuery.of(sheetCtx).size.height * 0.92,
                child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isCustomer ? TablerIcons.user : TablerIcons.buildingStore,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              isEditing
                                  ? 'Edit ${isCustomer ? "Customer" : "Supplier"}'
                                  : 'Register New ${isCustomer ? "Customer" : "Supplier"}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(TablerIcons.x),
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Form Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextField(
                            label: 'Legal / Business Name *',
                            hint: isCustomer ? 'e.g. Ramesh Patel or Sri Krishna Traders' : 'e.g. Agro Chemical Supplies Pvt Ltd',
                            controller: nameController,
                            prefixIcon: const Icon(TablerIcons.id, size: 18),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  label: 'Party Code (Auto if blank)',
                                  hint: isCustomer ? 'e.g. CUST-001' : 'e.g. SUP-001',
                                  controller: codeController,
                                  prefixIcon: const Icon(TablerIcons.tag, size: 18),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: AppTextField(
                                  label: 'Primary Mobile *',
                                  hint: '10-digit number',
                                  controller: phoneController,
                                  keyboardType: TextInputType.phone,
                                  prefixIcon: const Icon(TablerIcons.phone, size: 18),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),

                          if (isCustomer) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    label: 'Alternate Contact',
                                    hint: 'Optional phone',
                                    controller: altPhoneController,
                                    keyboardType: TextInputType.phone,
                                    prefixIcon: const Icon(TablerIcons.phoneCall, size: 18),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: AppTextField(
                                    label: 'Email Address',
                                    hint: 'customer@example.com',
                                    controller: emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    prefixIcon: const Icon(TablerIcons.mail, size: 18),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppDropdown<String>(
                              label: 'Customer Classification',
                              value: customerType,
                              items: const [
                                DropdownMenuItem(value: 'individual', child: Text('Individual Customer / Retail')),
                                DropdownMenuItem(value: 'business', child: Text('Commercial Business Account')),
                                DropdownMenuItem(value: 'gst_registered', child: Text('GST-Registered Entity (B2B)')),
                                DropdownMenuItem(value: 'walk_in', child: Text('Walk-In / Retail Counter')),
                              ],
                              onChanged: (val) {
                                if (val != null) setSheetState(() => customerType = val);
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: AmountField(
                                    label: 'Credit Limit (INR)',
                                    controller: creditLimitController,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: AppTextField(
                                    label: 'Credit Period (Days)',
                                    hint: 'e.g. 30',
                                    controller: creditPeriodController,
                                    keyboardType: TextInputType.number,
                                    prefixIcon: const Icon(TablerIcons.calendar, size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    label: 'Contact Person Name',
                                    hint: 'e.g. Anand Kumar',
                                    controller: contactPersonController,
                                    prefixIcon: const Icon(TablerIcons.user, size: 18),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: AppTextField(
                                    label: 'Email Address',
                                    hint: 'supplier@vendor.com',
                                    controller: emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    prefixIcon: const Icon(TablerIcons.mail, size: 18),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              label: 'Payment Terms',
                              hint: 'e.g. Net 30 Days, Due on Receipt',
                              controller: paymentTermsController,
                              prefixIcon: const Icon(TablerIcons.calendarTime, size: 18),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),

                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  label: 'GSTIN (Tax ID)',
                                  hint: '15-digit GSTIN (Optional)',
                                  controller: gstinController,
                                  prefixIcon: const Icon(TablerIcons.receiptTax, size: 18),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: AppTextField(
                                  label: 'State',
                                  hint: 'Karnataka',
                                  controller: stateController,
                                  prefixIcon: const Icon(TablerIcons.mapPin, size: 18),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),

                          AppTextField(
                            label: 'Billing / Shipping Address',
                            hint: 'Street address, City, Pincode',
                            controller: addressController,
                            maxLines: 2,
                            prefixIcon: const Icon(TablerIcons.building, size: 18),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          if (!isEditing) ...[
                            AmountField(
                              label: 'Opening Balance (INR)',
                              controller: openingBalController,
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],

                          AppTextField(
                            label: 'Internal Notes',
                            hint: 'Additional details or preferences',
                            controller: notesController,
                            maxLines: 2,
                            prefixIcon: const Icon(TablerIcons.notes, size: 18),
                          ),
                          const SizedBox(height: AppSpacing.sm),

                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Active Party Status', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('Inactive parties are hidden from rapid POS selection', style: TextStyle(fontSize: 12)),
                            value: isActive,
                            activeTrackColor: AppColors.primary,
                            onChanged: (v) => setSheetState(() => isActive = v),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer Actions
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppButton.ghost(
                          label: 'Cancel',
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppButton.primary(
                          label: isEditing ? 'Save Changes' : 'Register Party',
                          icon: TablerIcons.check,
                          onPressed: () async {
                            final name = nameController.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                const SnackBar(content: Text('Please enter party name')),
                              );
                              return;
                            }

                            try {
                              if (isCustomer) {
                                await cubit.saveCustomer(
                                  id: existingCustomer?.id,
                                  name: name,
                                  phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                                  code: codeController.text.trim().isEmpty ? null : codeController.text.trim(),
                                  alternatePhone: altPhoneController.text.trim().isEmpty ? null : altPhoneController.text.trim(),
                                  email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                                  address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                                  state: stateController.text.trim().isEmpty ? 'Karnataka' : stateController.text.trim(),
                                  gstin: gstinController.text.trim().isEmpty ? null : gstinController.text.trim().toUpperCase(),
                                  customerType: customerType,
                                  creditLimit: double.tryParse(creditLimitController.text.trim()) ?? 10000.0,
                                  creditPeriodDays: int.tryParse(creditPeriodController.text.trim()) ?? 30,
                                  openingBalance: double.tryParse(openingBalController.text.trim()) ?? 0.0,
                                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                                  isActive: isActive,
                                );
                              } else {
                                await cubit.saveSupplier(
                                  id: existingSupplier?.id,
                                  name: name,
                                  phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                                  code: codeController.text.trim().isEmpty ? null : codeController.text.trim(),
                                  contactPerson: contactPersonController.text.trim().isEmpty ? null : contactPersonController.text.trim(),
                                  email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                                  address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                                  state: stateController.text.trim().isEmpty ? 'Karnataka' : stateController.text.trim(),
                                  gstin: gstinController.text.trim().isEmpty ? null : gstinController.text.trim().toUpperCase(),
                                  paymentTerms: paymentTermsController.text.trim().isEmpty ? '30 Days' : paymentTermsController.text.trim(),
                                  openingBalance: double.tryParse(openingBalController.text.trim()) ?? 0.0,
                                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                                  isActive: isActive,
                                );
                              }
                              if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${isCustomer ? "Customer" : "Supplier"} saved successfully'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (sheetCtx.mounted) {
                                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                  SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
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
}
