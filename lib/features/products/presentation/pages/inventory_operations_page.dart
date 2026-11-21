import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/entities/app_entities.dart';
import '../cubit/products_cubit.dart';

class InventoryOperationsPage extends StatelessWidget {
  const InventoryOperationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    return BlocProvider(
      create: (_) => ProductsCubit(deps.productRepository)..load(),
      child: const _InventoryOperationsView(),
    );
  }
}

class _InventoryOperationsView extends StatefulWidget {
  const _InventoryOperationsView();

  @override
  State<_InventoryOperationsView> createState() => _InventoryOperationsViewState();
}

class _InventoryOperationsViewState extends State<_InventoryOperationsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Filter state for Movement Ledger tab
  final TextEditingController _movementSearchController = TextEditingController();
  String _selectedMovementType = 'all';

  // Filter state for Batches tab
  String _selectedBatchFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _movementSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductsCubit, ProductsState>(
      builder: (context, state) {
        final totalCostValuation = state.products.fold<double>(
          0.0,
          (sum, p) => sum + (p.stockQty * p.cost),
        );
        final totalSalesValuation = state.products.fold<double>(
          0.0,
          (sum, p) => sum + (p.stockQty * p.price),
        );
        final expiringSoonCount = state.batches.where((b) {
          if (b.expiryDate == null) return false;
          final diff = b.expiryDate!.difference(DateTime.now()).inDays;
          return diff <= 60 && diff >= 0;
        }).length;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppHeader(
            title: 'Stock & Inventory Central',
            breadcrumbs: const ['Products'],
            subtitle: 'Real-time inventory levels, FIFO/FEFO batches & stock ledger',
            actions: [
              IconButton(
                tooltip: 'Refresh Ledger',
                icon: const Icon(TablerIcons.refresh, color: AppColors.textPrimary),
                onPressed: () => context.read<ProductsCubit>().load(),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
              tabs: [
                const Tab(
                  icon: Icon(TablerIcons.dashboard, size: 18),
                  text: 'Overview & Stock',
                ),
                Tab(
                  icon: const Icon(TablerIcons.layersLinked, size: 18),
                  text: expiringSoonCount > 0
                      ? 'Batches ($expiringSoonCount alerts)'
                      : 'Batches & Expiry',
                ),
                const Tab(
                  icon: Icon(TablerIcons.history, size: 18),
                  text: 'Movement Ledger',
                ),
                Tab(
                  icon: const Icon(TablerIcons.alertTriangle, size: 18),
                  text: 'Reorder Alerts (${state.lowStockCount})',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Overview & Stock List
              _buildOverviewTab(context, state, totalCostValuation, totalSalesValuation),

              // Tab 2: Batches & Expiry Management
              _buildBatchesTab(context, state),

              // Tab 3: Movement Ledger Table
              _buildMovementLedgerTab(context, state),

              // Tab 4: Reorder / Low Stock Alerts
              _buildLowStockTab(context, state),
            ],
          ),
        );
      },
    );
  }

  // ── Tab 1: Overview & Stock Registry ─────────────────────────────────
  Widget _buildOverviewTab(
    BuildContext context,
    ProductsState state,
    double costValuation,
    double salesValuation,
  ) {
    if (state.loading && state.products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: AppLoadingSkeleton(count: 8),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<ProductsCubit>().load(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // 8-KPI Responsive Stat Grid
          AppStatGrid(
            minTileWidth: 180,
            children: [
              AppStatCard(
                title: 'Total Catalog',
                value: '${state.totalProductsCount}',
                subtitle: 'Products in system',
                icon: TablerIcons.package,
                accentColor: AppColors.primary,
              ),
              AppStatCard(
                title: 'Active in Stock',
                value: '${state.activeProductsCount}',
                subtitle: 'Available for billing',
                icon: TablerIcons.circleCheck,
                accentColor: AppColors.success,
                trendBadge: 'Active',
                trendPositive: true,
              ),
              AppStatCard(
                title: 'Low Stock Items',
                value: '${state.lowStockCount}',
                subtitle: state.lowStockCount > 0 ? 'Below reorder point' : 'All items healthy',
                icon: TablerIcons.alertTriangle,
                accentColor: state.lowStockCount > 0 ? AppColors.warning : AppColors.success,
                trendBadge: state.lowStockCount > 0 ? 'Reorder' : 'Safe',
                trendPositive: state.lowStockCount == 0,
                onTap: () => _tabController.animateTo(3),
              ),
              AppStatCard(
                title: 'Out of Stock',
                value: '${state.outOfStockCount}',
                subtitle: state.outOfStockCount > 0 ? 'Zero inventory' : 'None depleted',
                icon: TablerIcons.circleX,
                accentColor: state.outOfStockCount > 0 ? AppColors.error : AppColors.success,
                trendBadge: state.outOfStockCount > 0 ? 'Depleted' : 'OK',
                trendPositive: state.outOfStockCount == 0,
              ),
              AppStatCard(
                title: 'Cost Valuation',
                value: AppFormatters.money(costValuation),
                subtitle: 'At purchase prices',
                icon: TablerIcons.wallet,
                accentColor: const Color(0xFF0D9488),
              ),
              AppStatCard(
                title: 'Retail Valuation',
                value: AppFormatters.money(salesValuation),
                subtitle: 'Potential sale revenue',
                icon: TablerIcons.buildingStore,
                accentColor: const Color(0xFF0284C7),
              ),
              AppStatCard(
                title: 'Active Batches',
                value: '${state.batches.length}',
                subtitle: 'With FEFO tracking',
                icon: TablerIcons.layersLinked,
                accentColor: const Color(0xFF8B5CF6),
                onTap: () => _tabController.animateTo(1),
              ),
              AppStatCard(
                title: 'Ledger Audit Logs',
                value: '${state.stockMovements.length}',
                subtitle: 'Movement transactions',
                icon: TablerIcons.history,
                accentColor: const Color(0xFFD97706),
                onTap: () => _tabController.animateTo(2),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Stock Registry Table
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Live Stock Registry',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                '${state.products.length} registered items',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 768;

              if (isDesktop) {
                return AppDataTable<ProductView>(
                  minWidth: 780,
                  columns: [
                    AppDataColumn<ProductView>(
                      title: 'Product Name & SKU',
                      cellBuilder: (ctx, p, idx) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'SKU: ${p.sku}${p.categoryName != null ? " • ${p.categoryName}" : ""}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    AppDataColumn<ProductView>(
                      title: 'Available Stock',
                      cellBuilder: (ctx, p, idx) {
                        if (p.isOutOfStock) {
                          return AppBadge.error(
                            label: 'Out: ${p.stockQty} ${p.unit}',
                            showDot: true,
                          );
                        }
                        if (p.isLowStock) {
                          return AppBadge.warning(
                            label: 'Low: ${p.stockQty} ${p.unit}',
                            showDot: true,
                          );
                        }
                        return AppBadge.success(
                          label: '${p.stockQty} ${p.unit}',
                          showDot: true,
                        );
                      },
                    ),
                    AppDataColumn<ProductView>(
                      title: 'Cost Price',
                      numeric: true,
                      cellBuilder: (ctx, p, idx) => Text(
                        AppFormatters.money(p.cost),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    AppDataColumn<ProductView>(
                      title: 'Selling Price',
                      numeric: true,
                      cellBuilder: (ctx, p, idx) => Text(
                        AppFormatters.money(p.price),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    AppDataColumn<ProductView>(
                      title: 'Valuation',
                      numeric: true,
                      cellBuilder: (ctx, p, idx) => Text(
                        AppFormatters.money(p.stockValuation),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    AppDataColumn<ProductView>(
                      title: 'Actions',
                      alignment: Alignment.centerRight,
                      cellBuilder: (ctx, p, idx) => AppButton.primary(
                        label: 'Inward',
                        size: AppButtonSize.compact,
                        icon: TablerIcons.plus,
                        onPressed: () => _showQuickAdjustModal(context, p),
                      ),
                    ),
                  ],
                  items: state.products,
                );
              }

              // Mobile card layout
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.products.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (ctx, idx) {
                  final p = state.products[idx];
                  return AppCard.bordered(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'SKU: ${p.sku} • Cost: ${AppFormatters.money(p.cost)} • Selling: ${AppFormatters.money(p.price)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Valuation: ${AppFormatters.money(p.stockValuation)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (p.isOutOfStock)
                              AppBadge.error(label: '${p.stockQty} ${p.unit}', showDot: true)
                            else if (p.isLowStock)
                              AppBadge.warning(label: '${p.stockQty} ${p.unit}', showDot: true)
                            else
                              AppBadge.success(label: '${p.stockQty} ${p.unit}', showDot: true),
                            const SizedBox(height: AppSpacing.xs),
                            AppButton.primary(
                              label: 'Inward',
                              size: AppButtonSize.compact,
                              icon: TablerIcons.plus,
                              onPressed: () => _showQuickAdjustModal(context, p),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  // ── Tab 2: Batches & Expiry (FEFO) ───────────────────────────────────
  Widget _buildBatchesTab(BuildContext context, ProductsState state) {
    if (state.batches.isEmpty) {
      return const Center(
        child: AppEmptyState(
          icon: TablerIcons.layersOff,
          title: 'No Product Batches Recorded',
          message:
              'Batches created during purchase inwarding or stock entry will appear here with FEFO expiry monitoring.',
        ),
      );
    }

    final filteredBatches = state.batches.where((b) {
      if (_selectedBatchFilter == 'expired') return b.isExpired;
      if (_selectedBatchFilter == 'expiring_soon') return b.isExpiringSoon;
      if (_selectedBatchFilter == 'active') return !b.isExpired && !b.isExpiringSoon;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Filter bar for batch status
        AppFilterBar(
          filterOptions: [
            FilterOption(id: 'all', label: 'All Batches', badge: '${state.batches.length}'),
            FilterOption(
              id: 'expiring_soon',
              label: 'Expiring Soon',
              badge: '${state.batches.where((b) => b.isExpiringSoon).length}',
            ),
            FilterOption(
              id: 'expired',
              label: 'Expired',
              badge: '${state.batches.where((b) => b.isExpired).length}',
            ),
            FilterOption(
              id: 'active',
              label: 'Active & Safe',
              badge: '${state.batches.where((b) => !b.isExpired && !b.isExpiringSoon).length}',
            ),
          ],
          selectedFilterId: _selectedBatchFilter,
          onFilterSelected: (id) => setState(() => _selectedBatchFilter = id),
          onClearFilters: () => setState(() => _selectedBatchFilter = 'all'),
          onRefresh: () => context.read<ProductsCubit>().load(),
        ),
        const SizedBox(height: AppSpacing.lg),

        if (filteredBatches.isEmpty)
          AppEmptyState(
            icon: TablerIcons.packages,
            title: 'No Batches in this Category',
            message: 'No product batches match the selected expiry status filter.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 768;

              if (isDesktop) {
                return AppDataTable<ProductBatchView>(
                  minWidth: 800,
                  columns: [
                    AppDataColumn<ProductBatchView>(
                      title: 'Batch Number',
                      cellBuilder: (ctx, b, idx) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            b.batchNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'Product ID #${b.productId}${b.supplierName != null ? " • ${b.supplierName}" : ""}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    AppDataColumn<ProductBatchView>(
                      title: 'Expiry Status',
                      cellBuilder: (ctx, b, idx) {
                        if (b.isExpired) {
                          return const AppBadge.error(label: 'EXPIRED', showDot: true);
                        }
                        if (b.isExpiringSoon) {
                          return const AppBadge.warning(label: 'EXPIRING SOON', showDot: true);
                        }
                        return const AppBadge.success(label: 'ACTIVE', showDot: true);
                      },
                    ),
                    AppDataColumn<ProductBatchView>(
                      title: 'Expiry Date',
                      cellBuilder: (ctx, b, idx) => Text(
                        b.expiryDate != null ? AppFormatters.date(b.expiryDate!) : 'No Expiry Set',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: b.isExpired || b.isExpiringSoon ? FontWeight.bold : FontWeight.normal,
                          color: b.isExpired
                              ? AppColors.error
                              : b.isExpiringSoon
                                  ? AppColors.warning
                                  : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    AppDataColumn<ProductBatchView>(
                      title: 'Cost Price',
                      numeric: true,
                      cellBuilder: (ctx, b, idx) => Text(
                        AppFormatters.money(b.costPrice),
                        style: const TextStyle(fontSize: 12.5, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ),
                    AppDataColumn<ProductBatchView>(
                      title: 'Selling Price',
                      numeric: true,
                      cellBuilder: (ctx, b, idx) => Text(
                        AppFormatters.money(b.sellingPrice),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    AppDataColumn<ProductBatchView>(
                      title: 'Remaining Qty',
                      numeric: true,
                      cellBuilder: (ctx, b, idx) => Text(
                        '${b.quantity} / ${b.initialQuantity}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                  items: filteredBatches,
                );
              }

              // Mobile card list
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredBatches.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (ctx, idx) {
                  final b = filteredBatches[idx];
                  return AppCard.bordered(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: b.isExpired
                                ? AppColors.errorContainer
                                : b.isExpiringSoon
                                    ? AppColors.warningContainer
                                    : AppColors.primaryContainer,
                            borderRadius: AppRadii.sm,
                          ),
                          child: Icon(
                            b.isExpired
                                ? TablerIcons.alertCircle
                                : b.isExpiringSoon
                                    ? TablerIcons.alertTriangle
                                    : TablerIcons.box,
                            color: b.isExpired
                                ? AppColors.error
                                : b.isExpiringSoon
                                    ? AppColors.warning
                                    : AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    b.batchNumber,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  if (b.isExpired)
                                    const AppBadge.error(label: 'EXPIRED')
                                  else if (b.isExpiringSoon)
                                    const AppBadge.warning(label: 'EXPIRING SOON')
                                  else
                                    const AppBadge.success(label: 'ACTIVE'),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Product ID #${b.productId} • Cost: ${AppFormatters.money(b.costPrice)} • Selling: ${AppFormatters.money(b.sellingPrice)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                              if (b.expiryDate != null)
                                Text(
                                  'Expires: ${AppFormatters.date(b.expiryDate!)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: b.isExpired || b.isExpiringSoon ? FontWeight.bold : FontWeight.normal,
                                    color: b.isExpired
                                        ? AppColors.error
                                        : b.isExpiringSoon
                                            ? AppColors.warning
                                            : AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${b.quantity} Left',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Init: ${b.initialQuantity}',
                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  // ── Tab 3: Movement Ledger Table ─────────────────────────────────────
  Widget _buildMovementLedgerTab(BuildContext context, ProductsState state) {
    if (state.stockMovements.isEmpty) {
      return const Center(
        child: AppEmptyState(
          icon: TablerIcons.historyOff,
          title: 'No Movements Recorded',
          message: 'Stock inwarding, POS sales, write-offs, and count adjustments will log here.',
        ),
      );
    }

    final query = _movementSearchController.text.trim().toLowerCase();
    final filteredMovements = state.stockMovements.where((m) {
      final matchesSearch = query.isEmpty ||
          m.productName.toLowerCase().contains(query) ||
          m.productSku.toLowerCase().contains(query) ||
          (m.reason?.toLowerCase().contains(query) ?? false) ||
          (m.batchNumber?.toLowerCase().contains(query) ?? false);

      final matchesType = _selectedMovementType == 'all' ||
          m.type.toLowerCase() == _selectedMovementType.toLowerCase();

      return matchesSearch && matchesType;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Filter toolbar
        AppFilterBar(
          searchController: _movementSearchController,
          searchHint: 'Search by product, SKU, or reason...',
          onSearchChanged: (_) => setState(() {}),
          onSearchClear: () {
            _movementSearchController.clear();
            setState(() {});
          },
          filterOptions: [
            FilterOption(id: 'all', label: 'All Operations', badge: '${state.stockMovements.length}'),
            FilterOption(
              id: 'inward',
              label: 'Inward (+)',
              badge: '${state.stockMovements.where((m) => m.type.toLowerCase() == "inward").length}',
            ),
            FilterOption(
              id: 'sale',
              label: 'Sales (-)',
              badge: '${state.stockMovements.where((m) => m.type.toLowerCase() == "sale").length}',
            ),
            FilterOption(
              id: 'adjustment',
              label: 'Adjustments',
              badge: '${state.stockMovements.where((m) => m.type.toLowerCase() == "adjustment").length}',
            ),
            FilterOption(
              id: 'damage',
              label: 'Damage / Write-Off',
              badge: '${state.stockMovements.where((m) => m.type.toLowerCase() == "damage").length}',
            ),
          ],
          selectedFilterId: _selectedMovementType,
          onFilterSelected: (id) => setState(() => _selectedMovementType = id),
          onClearFilters: () {
            _movementSearchController.clear();
            setState(() => _selectedMovementType = 'all');
          },
          onRefresh: () => context.read<ProductsCubit>().load(),
        ),
        const SizedBox(height: AppSpacing.lg),

        if (filteredMovements.isEmpty)
          const AppEmptyState(
            icon: TablerIcons.fileSearch,
            title: 'No Matching Stock Logs',
            message: 'No movement ledger entries match your active search and filter parameters.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 768;

              if (isDesktop) {
                return AppDataTable<StockMovementView>(
                  minWidth: 840,
                  columns: [
                    AppDataColumn<StockMovementView>(
                      title: 'Timestamp',
                      cellBuilder: (ctx, m, idx) => Text(
                        AppFormatters.date(m.createdAt),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    AppDataColumn<StockMovementView>(
                      title: 'Product & SKU',
                      cellBuilder: (ctx, m, idx) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            m.productName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          Text(
                            'SKU: ${m.productSku}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    AppDataColumn<StockMovementView>(
                      title: 'Operation Type',
                      cellBuilder: (ctx, m, idx) {
                        final type = m.type.toLowerCase();
                        if (type == 'inward') {
                          return const AppBadge.success(label: 'INWARD (+)');
                        }
                        if (type == 'sale') {
                          return const AppBadge.info(label: 'SALE (-)');
                        }
                        if (type == 'damage') {
                          return const AppBadge.error(label: 'DAMAGE (-)');
                        }
                        return const AppBadge.neutral(label: 'ADJUSTMENT');
                      },
                    ),
                    AppDataColumn<StockMovementView>(
                      title: 'Quantity Change',
                      numeric: true,
                      cellBuilder: (ctx, m, idx) {
                        final isPositive = m.qtyChange >= 0;
                        return Text(
                          '${isPositive ? "+" : ""}${m.qtyChange}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isPositive ? AppColors.successText : AppColors.error,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        );
                      },
                    ),
                    AppDataColumn<StockMovementView>(
                      title: 'Balance After',
                      numeric: true,
                      cellBuilder: (ctx, m, idx) => Text(
                        m.balanceAfter != null ? '${m.balanceAfter}' : '-',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    AppDataColumn<StockMovementView>(
                      title: 'Reference / Reason',
                      cellBuilder: (ctx, m, idx) => Text(
                        m.reason ?? (m.batchNumber != null ? 'Batch: ${m.batchNumber}' : 'Operational Record'),
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  items: filteredMovements,
                );
              }

              // Mobile card layout
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredMovements.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (ctx, idx) {
                  final m = filteredMovements[idx];
                  final isPositive = m.qtyChange >= 0;

                  return AppCard.bordered(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: isPositive ? AppColors.successContainer : AppColors.errorContainer,
                            borderRadius: AppRadii.sm,
                          ),
                          child: Icon(
                            isPositive ? TablerIcons.arrowDownLeft : TablerIcons.arrowUpRight,
                            color: isPositive ? AppColors.successText : AppColors.error,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.productName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                '${m.type.toUpperCase()} • ${m.productSku}${m.reason != null ? " • ${m.reason}" : ""}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                              Text(
                                AppFormatters.date(m.createdAt),
                                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${isPositive ? "+" : ""}${m.qtyChange}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isPositive ? AppColors.successText : AppColors.error,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            if (m.balanceAfter != null)
                              Text(
                                'Bal: ${m.balanceAfter}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  // ── Tab 4: Reorder & Low Stock Alerts ────────────────────────────────
  Widget _buildLowStockTab(BuildContext context, ProductsState state) {
    final lowStock = state.products.where((p) => p.isLowStock || p.isOutOfStock).toList();

    if (lowStock.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: AppEmptyState(
            icon: TablerIcons.thumbUp,
            title: 'All Product Stock Levels Healthy!',
            message: 'No products are currently at or below their minimum reorder thresholds.',
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Urgent alert banner
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.errorContainer,
            borderRadius: AppRadii.md,
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(TablerIcons.alertTriangle, color: AppColors.error, size: 24),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${lowStock.length} Item(s) Require Replenishment',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 14),
                    ),
                    const Text(
                      'Stock is at or below recommended thresholds. Initiate purchase inwarding to prevent retail POS stockouts.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lowStock.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (ctx, idx) {
            final p = lowStock[idx];
            final reorderQty = (p.lowStockThreshold * 2) - p.stockQty;

            return AppCard.bordered(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: p.isOutOfStock ? AppColors.errorContainer : AppColors.warningContainer,
                      borderRadius: AppRadii.sm,
                    ),
                    child: Icon(
                      p.isOutOfStock ? TablerIcons.circleX : TablerIcons.alertTriangle,
                      color: p.isOutOfStock ? AppColors.error : AppColors.warning,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Stock: ${p.stockQty} ${p.unit} (Threshold: ${p.lowStockThreshold})',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                        Text(
                          'Recommended Reorder: ${reorderQty > 0 ? reorderQty : p.lowStockThreshold} ${p.unit}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  AppButton.primary(
                    label: 'Inward',
                    size: AppButtonSize.compact,
                    icon: TablerIcons.plus,
                    onPressed: () => _showQuickAdjustModal(context, p),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  // ── Quick Inward Modal Dialog ────────────────────────────────────────
  Future<void> _showQuickAdjustModal(BuildContext context, ProductView product) async {
    final cubit = context.read<ProductsCubit>();
    final qtyController = TextEditingController(text: '20');
    final costController = TextEditingController(text: product.cost.toStringAsFixed(2));

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(TablerIcons.packageImport, color: AppColors.primary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Stock Inward • ${product.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppFormField(
                label: 'Quantity to Add (${product.unit})',
                required: true,
                child: AppTextField(
                  controller: qtyController,
                  hint: 'Enter quantity',
                  keyboardType: TextInputType.number,
                ),
              ),
              AppFormField(
                label: 'Unit Cost Price',
                required: true,
                child: AmountField(
                  controller: costController,
                  hint: '0.00',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final qty = int.tryParse(qtyController.text.trim()) ?? 0;
              final cost = double.tryParse(costController.text.trim()) ?? product.cost;
              if (qty > 0) {
                await cubit.inwardStock(
                  productId: product.id,
                  quantity: qty,
                  costPrice: cost,
                  notes: 'Quick reorder replenishment inward',
                );
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Confirm Inward'),
          ),
        ],
      ),
    );
  }
}
