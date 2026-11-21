import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/models/app_models.dart';
import '../../../../core/state/app_cubit.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/entities/app_entities.dart';
import '../../../pos/presentation/widgets/product_tile.dart' show ProductImageWidget;
import '../cubit/products_cubit.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    return BlocProvider(
      create: (_) => ProductsCubit(deps.productRepository)..load(),
      child: const _ProductsView(),
    );
  }
}

class _ProductsView extends StatefulWidget {
  const _ProductsView();

  @override
  State<_ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<_ProductsView> {
  final TextEditingController _searchController = TextEditingController();
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

  List<ProductView> _getSortedProducts(List<ProductView> products) {
    if (_sortColumnIndex == null) return products;
    final sorted = List<ProductView>.from(products);
    sorted.sort((a, b) {
      int comparison;
      switch (_sortColumnIndex) {
        case 0:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 1:
          comparison = (a.categoryName ?? '').compareTo(b.categoryName ?? '');
          break;
        case 2:
          comparison = a.stockQty.compareTo(b.stockQty);
          break;
        case 3:
          comparison = a.cost.compareTo(b.cost);
          break;
        case 4:
          comparison = a.price.compareTo(b.price);
          break;
        case 5:
          comparison = a.gstRate.compareTo(b.gstRate);
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
    final l10n = context.l10n;
    final appState = context.watch<AppCubit>().state;
    final isAdmin = appState.session?.role == UserRole.admin;
    final currency = appState.settings.currency;

    return BlocConsumer<ProductsCubit, ProductsState>(
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
        final sortedProducts = _getSortedProducts(state.filteredProducts);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppHeader(
            title: l10n.tr('products'),
            subtitle:
                '${state.products.length} products • Valuation: ${AppFormatters.money(state.totalStockValuation, currency: currency)}',
            actions: [
              IconButton(
                tooltip: state.isGridView ? 'List/Table view' : 'Grid view',
                icon: Icon(
                  state.isGridView ? TablerIcons.layoutList : TablerIcons.layoutGrid,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => context.read<ProductsCubit>().toggleViewMode(),
              ),
              if (isAdmin)
                IconButton(
                  tooltip: 'Manage Categories',
                  icon: const Icon(TablerIcons.category, color: AppColors.textPrimary),
                  onPressed: () => _showCategoryManager(context),
                ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(TablerIcons.refresh, color: AppColors.textPrimary),
                onPressed: () => context.read<ProductsCubit>().load(),
              ),
            ],
          ),
          floatingActionButton: isAdmin
              ? FloatingActionButton.extended(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  onPressed: () => _showProductEditor(context),
                  icon: const Icon(TablerIcons.plus, size: 20),
                  label: Text(
                    l10n.tr('addProduct'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: () => context.read<ProductsCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // 1. KPI Summary Cards via AppStatGrid
                _buildKpiSummary(context, state, currency),
                const SizedBox(height: AppSpacing.lg),

                // 2. Search & Filter Bar via AppFilterBar
                _buildFilterBar(context, state, l10n),
                const SizedBox(height: AppSpacing.lg),

                // 3. Main Products Presentation
                if (state.loading && state.products.isEmpty)
                  const AppLoadingSkeleton(count: 8)
                else if (sortedProducts.isEmpty)
                  AppEmptyState(
                    icon: TablerIcons.packageOff,
                    title: 'No Products Found',
                    message: state.filter.search.isNotEmpty
                        ? 'No products match "${state.filter.search}".'
                        : state.filter.lowStockOnly
                            ? 'All products are currently well-stocked!'
                            : 'No catalog products registered in this workspace yet.',
                    action: isAdmin
                        ? AppButton.primary(
                            label: l10n.tr('addProduct'),
                            icon: TablerIcons.plus,
                            onPressed: () => _showProductEditor(context),
                          )
                        : null,
                  )
                else if (state.isGridView)
                  _buildProductGrid(context, sortedProducts, currency, isAdmin)
                else
                  _buildProductAdaptiveView(context, sortedProducts, currency, isAdmin),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 1. KPI Summary Section ───────────────────────────────────────────
  Widget _buildKpiSummary(BuildContext context, ProductsState state, String currency) {
    return AppStatGrid(
      minTileWidth: 190,
      children: [
        AppStatCard(
          title: 'Total Products',
          value: '${state.totalProductsCount}',
          subtitle: 'Catalog items registered',
          icon: TablerIcons.package,
          accentColor: AppColors.primary,
        ),
        AppStatCard(
          title: 'Active in Stock',
          value: '${state.activeProductsCount}',
          subtitle: 'Available for retail POS',
          icon: TablerIcons.circleCheck,
          accentColor: AppColors.success,
          trendBadge: 'Active',
          trendPositive: true,
        ),
        AppStatCard(
          title: 'Low Stock Items',
          value: '${state.lowStockCount}',
          subtitle: state.lowStockCount > 0 ? 'Urgent reorder required' : 'Stock levels healthy',
          icon: TablerIcons.alertTriangle,
          accentColor: state.lowStockCount > 0 ? AppColors.warning : AppColors.success,
          trendBadge: state.lowStockCount > 0 ? 'Reorder' : 'OK',
          trendPositive: state.lowStockCount == 0,
          onTap: () => context.read<ProductsCubit>().applyFilter(lowStockOnly: true),
        ),
        AppStatCard(
          title: 'Out of Stock',
          value: '${state.outOfStockCount}',
          subtitle: state.outOfStockCount > 0 ? 'Zero inventory remaining' : 'No items depleted',
          icon: TablerIcons.circleX,
          accentColor: state.outOfStockCount > 0 ? AppColors.error : AppColors.success,
          trendBadge: state.outOfStockCount > 0 ? 'Depleted' : 'Safe',
          trendPositive: state.outOfStockCount == 0,
        ),
        AppStatCard(
          title: 'Inventory Valuation',
          value: AppFormatters.money(state.totalStockValuation, currency: currency),
          subtitle: 'Calculated at purchase cost',
          icon: TablerIcons.wallet,
          accentColor: const Color(0xFF0D9488),
        ),
      ],
    );
  }

  // ── 2. Filter Bar Section ────────────────────────────────────────────
  Widget _buildFilterBar(BuildContext context, ProductsState state, AppLocalizations l10n) {
    final cubit = context.read<ProductsCubit>();

    // Build filter options list: All, Low Stock, plus each Category
    final filterOptions = <FilterOption>[
      FilterOption(
        id: 'all',
        label: 'All Items',
        badge: '${state.totalProductsCount}',
      ),
      FilterOption(
        id: 'low_stock',
        label: 'Low Stock',
        badge: '${state.lowStockCount}',
      ),
      for (final cat in state.categories)
        FilterOption(
          id: 'cat_${cat.id}',
          label: cat.name,
        ),
    ];

    String selectedFilterId = 'all';
    if (state.filter.lowStockOnly) {
      selectedFilterId = 'low_stock';
    } else if (state.filter.categoryId != null) {
      selectedFilterId = 'cat_${state.filter.categoryId}';
    }

    return AppFilterBar(
      searchController: _searchController,
      searchHint: l10n.tr('searchProducts'),
      onSearchChanged: (query) => cubit.applyFilter(search: query),
      onSearchClear: () {
        _searchController.clear();
        cubit.applyFilter(search: '');
      },
      filterOptions: filterOptions,
      selectedFilterId: selectedFilterId,
      onFilterSelected: (id) {
        if (id == 'all') {
          cubit.applyFilter(categoryId: -1, lowStockOnly: false);
        } else if (id == 'low_stock') {
          cubit.applyFilter(lowStockOnly: true, categoryId: -1);
        } else if (id.startsWith('cat_')) {
          final catId = int.tryParse(id.replaceFirst('cat_', ''));
          if (catId != null) {
            cubit.applyFilter(categoryId: catId, lowStockOnly: false);
          }
        }
      },
      onClearFilters: () {
        _searchController.clear();
        cubit.applyFilter(search: '', categoryId: -1, lowStockOnly: false);
      },
      onRefresh: () => cubit.load(),
      trailingAction: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: state.isGridView ? 'Switch to Table View' : 'Switch to Grid View',
            icon: Icon(
              state.isGridView ? TablerIcons.layoutList : TablerIcons.layoutGrid,
              size: 20,
              color: AppColors.textPrimary,
            ),
            onPressed: () => cubit.toggleViewMode(),
          ),
        ],
      ),
    );
  }

  // ── 3. Adaptive Table / Card List ────────────────────────────────────
  Widget _buildProductAdaptiveView(
    BuildContext context,
    List<ProductView> products,
    String currency,
    bool isAdmin,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktopOrTablet = constraints.maxWidth >= 768;

        if (isDesktopOrTablet) {
          return AppDataTable<ProductView>(
            minWidth: 860,
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            onSort: _onSort,
            columns: [
              AppDataColumn<ProductView>(
                title: 'Product & SKU',
                sortable: true,
                cellBuilder: (ctx, p, idx) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: AppRadii.sm,
                      child: ProductImageWidget(imagePath: p.imagePath, size: 36),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Column(
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'SKU: ${p.sku}${p.brand != null ? " • ${p.brand}" : ""}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AppDataColumn<ProductView>(
                title: 'Category',
                sortable: true,
                cellBuilder: (ctx, p, idx) => Text(
                  p.categoryName ?? 'General',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ),
              AppDataColumn<ProductView>(
                title: 'Stock Status',
                sortable: true,
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
                title: 'Cost',
                numeric: true,
                sortable: true,
                cellBuilder: (ctx, p, idx) => Text(
                  AppFormatters.money(p.cost, currency: currency),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              AppDataColumn<ProductView>(
                title: 'Selling Price',
                numeric: true,
                sortable: true,
                cellBuilder: (ctx, p, idx) {
                  final margin = p.price > 0 ? (((p.price - p.cost) / p.price) * 100) : 0.0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppFormatters.money(p.price, currency: currency),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        '${margin.toStringAsFixed(0)}% margin',
                        style: TextStyle(
                          fontSize: 10,
                          color: margin >= 0 ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                  );
                },
              ),
              AppDataColumn<ProductView>(
                title: 'GST Slab',
                sortable: true,
                cellBuilder: (ctx, p, idx) => Text(
                  '${p.gstRate.toStringAsFixed(0)}%${p.hsnCode != null ? " (${p.hsnCode})" : ""}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
              AppDataColumn<ProductView>(
                title: 'Actions',
                alignment: Alignment.centerRight,
                cellBuilder: (ctx, p, idx) => Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(TablerIcons.adjustments, size: 18, color: AppColors.primary),
                      tooltip: 'Adjust Stock',
                      onPressed: () => _showStockActionSheet(context, p),
                    ),
                    IconButton(
                      icon: const Icon(TablerIcons.edit, size: 18, color: AppColors.textSecondary),
                      tooltip: 'Edit Product',
                      onPressed: () => _showProductEditor(context, existing: p),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(TablerIcons.dotsVertical, size: 18, color: AppColors.textMuted),
                      tooltip: 'More actions',
                      onSelected: (val) async {
                        final cubit = context.read<ProductsCubit>();
                        if (val == 'details') {
                          _showProductDetails(context, p, currency, isAdmin);
                        } else if (val == 'archive') {
                          final confirm = await AppDialog.showConfirmation(
                            context: context,
                            title: p.isActive ? 'Deactivate Product' : 'Activate Product',
                            message: p.isActive
                                ? 'Deactivate "${p.name}"? It will be hidden from the active POS billing catalog.'
                                : 'Reactivate "${p.name}" for retail POS operations?',
                            confirmLabel: p.isActive ? 'Deactivate' : 'Activate',
                          );
                          if (confirm == true) {
                            await cubit.archiveProduct(p.id, !p.isActive);
                          }
                        } else if (val == 'delete') {
                          final confirm = await AppDialog.showDestructive(
                            context: context,
                            title: 'Delete Product',
                            message: 'Delete "${p.name}"? Historical orders and transaction records will be verified.',
                            confirmLabel: 'Delete Product',
                          );
                          if (confirm == true) {
                            await cubit.deleteProduct(p.id);
                          }
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'details',
                          child: Row(
                            children: [
                              Icon(TablerIcons.infoCircle, size: 16),
                              SizedBox(width: 8),
                              Text('View Full Profile'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(p.isActive ? TablerIcons.archive : TablerIcons.archiveOff, size: 16),
                              SizedBox(width: 8),
                              Text(p.isActive ? 'Deactivate' : 'Reactivate'),
                            ],
                          ),
                        ),
                        if (isAdmin)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(TablerIcons.trash, size: 16, color: AppColors.error),
                                SizedBox(width: 8),
                                Text('Delete Product', style: TextStyle(color: AppColors.error)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            items: products,
            onRowTap: (p) => _showProductDetails(context, p, currency, isAdmin),
          );
        }

        // Mobile fallback: Card-based list
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final product = products[index];
            return _ProductListCard(
              product: product,
              currency: currency,
              isAdmin: isAdmin,
              onTap: () => _showProductDetails(context, product, currency, isAdmin),
              onEdit: () => _showProductEditor(context, existing: product),
              onStockAction: () => _showStockActionSheet(context, product),
            );
          },
        );
      },
    );
  }

  // ── 4. Grid View Presentation ─────────────────────────────────────────
  Widget _buildProductGrid(
    BuildContext context,
    List<ProductView> products,
    String currency,
    bool isAdmin,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1200
            ? 5
            : constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 600
                    ? 3
                    : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.72,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return _ProductGridCard(
              product: product,
              currency: currency,
              isAdmin: isAdmin,
              onTap: () => _showProductDetails(context, product, currency, isAdmin),
            );
          },
        );
      },
    );
  }

  // ── 5. Product Details Modal Drawer ──────────────────────────────────
  Future<void> _showProductDetails(
    BuildContext context,
    ProductView product,
    String currency,
    bool isAdmin,
  ) async {
    final cubit = context.read<ProductsCubit>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: AppRadii.radiusXl),
          ),
          padding: EdgeInsets.only(
            top: AppSpacing.md,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: MediaQuery.of(sheetContext).padding.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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

              // Header: Image + Basic Info + Status Badges
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: AppRadii.md,
                    child: ProductImageWidget(imagePath: product.imagePath, size: 76),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (product.brand != null && product.brand!.isNotEmpty)
                          Text(
                            'Brand: ${product.brand}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        Text(
                          'SKU: ${product.sku}${product.barcode != null ? ' • Barcode: ${product.barcode}' : ''}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            if (product.isActive)
                              const AppBadge.success(label: 'Active')
                            else
                              const AppBadge.error(label: 'Archived'),
                            const SizedBox(width: AppSpacing.xs),
                            if (product.categoryName != null)
                              AppBadge.neutral(label: product.categoryName!),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),

              // Financial & Stock Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: _buildDetailMetricTile(
                      label: 'Selling Price',
                      value: AppFormatters.money(product.price, currency: currency),
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildDetailMetricTile(
                      label: 'Cost Price',
                      value: AppFormatters.money(product.cost, currency: currency),
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildDetailMetricTile(
                      label: 'Stock Quantity',
                      value: '${product.stockQty} ${product.unit}',
                      color: product.isOutOfStock
                          ? AppColors.error
                          : product.isLowStock
                              ? AppColors.warning
                              : AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailMetricTile(
                      label: 'GST Slab',
                      value: '${product.gstRate.toStringAsFixed(0)}% (HSN: ${product.hsnCode ?? "-"})',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildDetailMetricTile(
                      label: 'Gross Margin',
                      value: product.price > 0
                          ? '${(((product.price - product.cost) / product.price) * 100).toStringAsFixed(1)}%'
                          : '0%',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildDetailMetricTile(
                      label: 'Stock Valuation',
                      value: AppFormatters.money(product.stockValuation, currency: currency),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Action Buttons
              if (isAdmin) ...[
                Row(
                  children: [
                    Expanded(
                      child: AppButton.outlined(
                        label: 'Adjust Stock',
                        icon: TablerIcons.adjustments,
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _showStockActionSheet(context, product);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton.primary(
                        label: 'Edit Product',
                        icon: TablerIcons.edit,
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _showProductEditor(context, existing: product);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.secondary(
                        label: product.isActive ? 'Deactivate' : 'Reactivate',
                        icon: product.isActive ? TablerIcons.archive : TablerIcons.archiveOff,
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          final confirm = await AppDialog.showConfirmation(
                            context: context,
                            title: product.isActive ? 'Deactivate Product' : 'Reactivate Product',
                            message: product.isActive
                                ? 'Deactivate "${product.name}"? It will no longer appear in POS.'
                                : 'Reactivate "${product.name}" for retail operations?',
                            confirmLabel: product.isActive ? 'Deactivate' : 'Reactivate',
                          );
                          if (confirm == true) {
                            await cubit.archiveProduct(product.id, !product.isActive);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton.danger(
                        label: 'Delete Product',
                        icon: TablerIcons.trash,
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          final confirm = await AppDialog.showDestructive(
                            context: context,
                            title: 'Delete Product',
                            message: 'Delete "${product.name}"? Historical transactions will be verified before deletion.',
                            confirmLabel: 'Delete Product',
                          );
                          if (confirm == true) {
                            await cubit.deleteProduct(product.id);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailMetricTile({
    required String label,
    required String value,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadii.md,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── 6. Stock Action / Adjustment Modal ───────────────────────────────
  Future<void> _showStockActionSheet(BuildContext context, ProductView product) async {
    final cubit = context.read<ProductsCubit>();
    final qtyController = TextEditingController(text: '10');
    final physicalCountController = TextEditingController(text: '${product.stockQty}');
    final unitCostController = TextEditingController(text: product.cost.toStringAsFixed(2));
    final batchNoController = TextEditingController();
    final reasonController = TextEditingController();
    int selectedMode = 0; // 0: Inward, 1: Physical Count Adjustment, 2: Damage/Write-off

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: AppRadii.radiusXl),
          ),
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: StatefulBuilder(
            builder: (ctx, setState) {
              final physicalCount = int.tryParse(physicalCountController.text.trim()) ?? product.stockQty;
              final diff = physicalCount - product.stockQty;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock Operation • ${product.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Current Available Stock: ${product.stockQty} ${product.unit}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Operation Mode Toggle Segmented Button
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Inward (+)')),
                        ButtonSegment(value: 1, label: Text('Adjustment')),
                        ButtonSegment(value: 2, label: Text('Damage (-)')),
                      ],
                      selected: {selectedMode},
                      onSelectionChanged: (set) => setState(() => selectedMode = set.first),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    if (selectedMode == 0) ...[
                      // Inward Form
                      AppFormField(
                        label: 'Inward Quantity',
                        required: true,
                        child: AppTextField(
                          controller: qtyController,
                          hint: 'Enter inward quantity',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      AppFormField(
                        label: 'Unit Cost Price',
                        required: true,
                        child: AmountField(
                          controller: unitCostController,
                          hint: '0.00',
                        ),
                      ),
                      AppFormField(
                        label: 'Batch Number (Optional)',
                        child: AppTextField(
                          controller: batchNoController,
                          hint: 'e.g. BATCH-2026-001',
                        ),
                      ),
                      AppFormField(
                        label: 'Remarks / Supplier Notes',
                        child: AppTextField(
                          controller: reasonController,
                          hint: 'Optional invoice or supplier reference',
                        ),
                      ),
                    ] else if (selectedMode == 1) ...[
                      // Physical Count Adjustment
                      AppFormField(
                        label: 'Actual Physical Count Verified',
                        required: true,
                        child: AppTextField(
                          controller: physicalCountController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: diff == 0
                              ? AppColors.surfaceElevated
                              : diff > 0
                                  ? AppColors.successContainer
                                  : AppColors.errorContainer,
                          borderRadius: AppRadii.md,
                          border: Border.all(
                            color: diff == 0
                                ? AppColors.border
                                : diff > 0
                                    ? AppColors.successText.withValues(alpha: 0.3)
                                    : AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Stock Reconciliation:',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            Text(
                              diff > 0
                                  ? '+$diff ${product.unit} (Surplus)'
                                  : diff < 0
                                      ? '$diff ${product.unit} (Shortage)'
                                      : 'No discrepancy (0)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: diff > 0
                                    ? AppColors.successText
                                    : diff < 0
                                        ? AppColors.error
                                        : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppFormField(
                        label: 'Adjustment Reason',
                        child: AppTextField(
                          controller: reasonController,
                          hint: 'e.g. Audit reconciliation, breakage, miscount',
                        ),
                      ),
                    ] else ...[
                      // Damage / Write-off
                      AppFormField(
                        label: 'Quantity to Write-Off / Scrap',
                        required: true,
                        child: AppTextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          hint: 'Enter quantity',
                        ),
                      ),
                      AppFormField(
                        label: 'Damage Reason',
                        required: true,
                        child: AppTextField(
                          controller: reasonController,
                          hint: 'e.g. Broken seal, expired batch, water damage',
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    AppButton.primary(
                      label: 'Commit Stock Operation',
                      expanded: true,
                      icon: TablerIcons.check,
                      onPressed: () async {
                        if (selectedMode == 0) {
                          final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                          final cost = double.tryParse(unitCostController.text.trim()) ?? product.cost;
                          final batchNo = batchNoController.text.trim();
                          if (qty <= 0) return;
                          await cubit.inwardStock(
                            productId: product.id,
                            quantity: qty,
                            costPrice: cost,
                            batchNumber: batchNo.isNotEmpty ? batchNo : null,
                            notes: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null,
                          );
                        } else if (selectedMode == 1) {
                          final count = int.tryParse(physicalCountController.text.trim()) ?? product.stockQty;
                          final reason = reasonController.text.trim().isNotEmpty
                              ? reasonController.text.trim()
                              : 'Physical Count Audit Reconciliation';
                          await cubit.adjustStock(
                            productId: product.id,
                            newQuantity: count,
                            reason: reason,
                          );
                        } else {
                          final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                          final reason = reasonController.text.trim().isNotEmpty
                              ? reasonController.text.trim()
                              : 'Damaged Goods Write-Off';
                          if (qty <= 0) return;
                          await cubit.writeOffStock(
                            productId: product.id,
                            quantity: qty,
                            reason: reason,
                          );
                        }
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── 7. Manage Categories Dialog ─────────────────────────────────────
  Future<void> _showCategoryManager(BuildContext context) async {
    final cubit = context.read<ProductsCubit>();
    final newCatController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return BlocBuilder<ProductsCubit, ProductsState>(
          bloc: cubit,
          builder: (ctx, state) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(TablerIcons.category, color: AppColors.primary, size: 22),
                  SizedBox(width: 8),
                  Text('Categories & Departments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: newCatController,
                            hint: 'New category name...',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                          onPressed: () async {
                            if (newCatController.text.trim().isNotEmpty) {
                              await cubit.saveCategory(newCatController.text.trim());
                              newCatController.clear();
                            }
                          },
                          icon: const Icon(TablerIcons.plus, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: state.categories.isEmpty
                          ? const Center(
                              child: Text('No categories created yet', style: TextStyle(color: AppColors.textMuted)),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: state.categories.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, index) {
                                final cat = state.categories[index];
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  trailing: IconButton(
                                    icon: const Icon(TablerIcons.trash, size: 18, color: AppColors.error),
                                    onPressed: () async {
                                      final confirm = await AppDialog.showDestructive(
                                        context: context,
                                        title: 'Delete Category',
                                        message: 'Delete category "${cat.name}"? Products in this category will become unassigned.',
                                      );
                                      if (confirm == true) {
                                        await cubit.deleteCategory(cat.id);
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
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
      },
    );
  }

  // ── 8. Add / Edit Product Modal ──────────────────────────────────────
  Future<void> _showProductEditor(BuildContext context, {ProductView? existing}) async {
    final cubit = context.read<ProductsCubit>();
    final state = cubit.state;

    final name = TextEditingController(text: existing?.name ?? '');
    final brand = TextEditingController(text: existing?.brand ?? '');
    final sku = TextEditingController(text: existing?.sku ?? '');
    final barcode = TextEditingController(text: existing?.barcode ?? '');
    final cost = TextEditingController(text: (existing?.cost ?? 0).toStringAsFixed(2));
    final price = TextEditingController(text: (existing?.price ?? 0).toStringAsFixed(2));
    final mrp = TextEditingController(text: (existing?.mrp ?? existing?.price ?? 0).toStringAsFixed(2));
    final stock = TextEditingController(text: '${existing?.stockQty ?? 0}');
    final low = TextEditingController(text: '${existing?.lowStockThreshold ?? 5}');
    final unit = TextEditingController(text: existing?.unit ?? 'piece');
    final notes = TextEditingController(text: existing?.notes ?? '');
    final hsnCode = TextEditingController(text: existing?.hsnCode ?? '');
    double gstRate = existing?.gstRate ?? 18.0;
    bool isActive = existing?.isActive ?? true;
    final imageUrlController = TextEditingController(
      text: (existing?.imagePath?.startsWith('http') ?? false) ? existing!.imagePath! : '',
    );
    int? categoryId = existing?.categoryId;
    String? pickedImagePath = existing?.imagePath;

    final picker = ImagePicker();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: AppRadii.radiusXl),
          ),
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              Future<void> pickImage(ImageSource source) async {
                final picked = await picker.pickImage(
                  source: source,
                  maxWidth: 600,
                  maxHeight: 600,
                  imageQuality: 85,
                );
                if (picked != null) {
                  setState(() => pickedImagePath = picked.path);
                }
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existing == null ? 'Add New Product' : 'Edit Product Profile',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
                        ),
                        Row(
                          children: [
                            const Text('Active: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Switch(
                              value: isActive,
                              activeThumbColor: AppColors.primary,
                              onChanged: (val) => setState(() => isActive = val),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Image selector row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            builder: (ctx) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(TablerIcons.photo),
                                    title: const Text('Choose from gallery'),
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      pickImage(ImageSource.gallery);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(TablerIcons.camera),
                                    title: const Text('Take a photo'),
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      pickImage(ImageSource.camera);
                                    },
                                  ),
                                  if (pickedImagePath != null)
                                    ListTile(
                                      leading: const Icon(TablerIcons.trash, color: AppColors.error),
                                      title: const Text('Remove image', style: TextStyle(color: AppColors.error)),
                                      onTap: () {
                                        Navigator.of(ctx).pop();
                                        setState(() {
                                          pickedImagePath = null;
                                          imageUrlController.clear();
                                        });
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                          child: pickedImagePath != null
                              ? ClipRRect(
                                  borderRadius: AppRadii.lg,
                                  child: ProductImageWidget(
                                    imagePath: pickedImagePath,
                                    size: 80,
                                  ),
                                )
                              : _ImagePickerPlaceholder(
                                  colorScheme: Theme.of(context).colorScheme,
                                ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppFormField(
                                label: 'Image URL',
                                child: AppTextField(
                                  controller: imageUrlController,
                                  hint: 'https://...',
                                  onChanged: (url) {
                                    final trimmed = url.trim();
                                    if (trimmed.startsWith('http')) {
                                      setState(() => pickedImagePath = trimmed);
                                    }
                                  },
                                ),
                              ),
                              const Text(
                                'Tap thumbnail to open camera/gallery, or paste URL',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    Row(
                      children: [
                        Expanded(
                          child: AppFormField(
                            label: 'Product Name',
                            required: true,
                            child: AppTextField(controller: name, hint: 'e.g. Urea 50kg Bag'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppFormField(
                            label: 'Brand / Manufacturer',
                            child: AppTextField(controller: brand, hint: 'e.g. Darvi Agri'),
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: AppFormField(
                            label: 'SKU Code',
                            required: true,
                            child: AppTextField(controller: sku, hint: 'e.g. DAR-UREA-01'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppFormField(
                            label: 'Barcode / EAN',
                            child: AppTextField(controller: barcode, hint: 'Scannable barcode'),
                          ),
                        ),
                      ],
                    ),

                    AppFormField(
                      label: 'Category / Department',
                      child: AppDropdown<int?>(
                        value: categoryId,
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('No Category (General)')),
                          ...state.categories.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                        ],
                        onChanged: (value) => setState(() => categoryId = value),
                      ),
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: AppFormField(
                            label: 'Cost Price',
                            child: AmountField(controller: cost, hint: '0.00'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppFormField(
                            label: 'Selling Price',
                            required: true,
                            child: AmountField(controller: price, hint: '0.00'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppFormField(
                            label: 'MRP',
                            child: AmountField(controller: mrp, hint: '0.00'),
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: AppFormField(
                            label: 'Initial / Current Stock',
                            child: AppTextField(controller: stock, keyboardType: TextInputType.number),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppFormField(
                            label: 'Low Stock Alert Limit',
                            child: AppTextField(controller: low, keyboardType: TextInputType.number),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppFormField(
                            label: 'Unit of Measure',
                            child: AppTextField(controller: unit, hint: 'piece / kg / ltr / bag'),
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: AppFormField(
                            label: 'HSN / SAC Code',
                            child: AppTextField(controller: hsnCode, hint: 'e.g. 3102'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppFormField(
                            label: 'GST Slab',
                            child: AppDropdown<double>(
                              value: gstRate,
                              items: const [
                                DropdownMenuItem(value: 0.0, child: Text('0% (Exempt / Nil)')),
                                DropdownMenuItem(value: 5.0, child: Text('5% GST')),
                                DropdownMenuItem(value: 12.0, child: Text('12% GST')),
                                DropdownMenuItem(value: 18.0, child: Text('18% GST')),
                                DropdownMenuItem(value: 28.0, child: Text('28% GST')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => gstRate = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    AppFormField(
                      label: 'Description / Notes',
                      child: AppTextField(
                        controller: notes,
                        hint: 'Additional notes or specifications',
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    AppButton.primary(
                      label: context.l10n.tr('save'),
                      expanded: true,
                      icon: TablerIcons.check,
                      onPressed: () async {
                        final trimmedName = name.text.trim();
                        final trimmedSku = sku.text.trim();
                        if (trimmedName.isEmpty || trimmedSku.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter product name and SKU.')),
                          );
                          return;
                        }

                        final input = ProductUpsertInput(
                          id: existing?.id,
                          name: trimmedName,
                          sku: trimmedSku,
                          barcode: barcode.text.trim().isEmpty ? null : barcode.text.trim(),
                          categoryId: categoryId,
                          cost: double.tryParse(cost.text.trim()) ?? 0,
                          price: double.tryParse(price.text.trim()) ?? 0,
                          stockQty: int.tryParse(stock.text.trim()) ?? 0,
                          lowStockThreshold: int.tryParse(low.text.trim()) ?? 5,
                          unit: unit.text.trim().isEmpty ? 'piece' : unit.text.trim(),
                          notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
                          imagePath: pickedImagePath,
                          hsnCode: hsnCode.text.trim().isEmpty ? null : hsnCode.text.trim(),
                          gstRate: gstRate,
                          isActive: isActive,
                          mrp: double.tryParse(mrp.text.trim()),
                          brand: brand.text.trim().isNotEmpty ? brand.text.trim() : null,
                        );
                        await cubit.saveProduct(input);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ImagePickerPlaceholder extends StatelessWidget {
  const _ImagePickerPlaceholder({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: AppRadii.lg,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(TablerIcons.cameraPlus, color: AppColors.primary, size: 26),
          SizedBox(height: 2),
          Text(
            'Photo',
            style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ProductListCard extends StatelessWidget {
  const _ProductListCard({
    required this.product,
    required this.currency,
    required this.isAdmin,
    required this.onTap,
    required this.onEdit,
    required this.onStockAction,
  });

  final ProductView product;
  final String currency;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onStockAction;

  @override
  Widget build(BuildContext context) {
    final low = product.isLowStock;
    final outOfStock = product.isOutOfStock;

    return AppCard.bordered(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadii.sm,
            child: ProductImageWidget(imagePath: product.imagePath, size: 52),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.sku} • ${product.categoryName ?? 'General'}'
                  '${product.hsnCode != null && product.hsnCode!.isNotEmpty ? ' • HSN ${product.hsnCode}' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  AppFormatters.money(product.price, currency: currency),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 13,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (outOfStock)
                AppBadge.error(label: 'Out: ${product.stockQty}', showDot: true)
              else if (low)
                AppBadge.warning(label: 'Low: ${product.stockQty}', showDot: true)
              else
                AppBadge.success(label: 'Qty: ${product.stockQty}', showDot: true),
              const SizedBox(height: 4),
              Text(
                'GST ${product.gstRate.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductGridCard extends StatelessWidget {
  const _ProductGridCard({
    required this.product,
    required this.currency,
    required this.isAdmin,
    required this.onTap,
  });

  final ProductView product;
  final String currency;
  final bool isAdmin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final low = product.isLowStock;
    final outOfStock = product.isOutOfStock;

    return AppCard.bordered(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: ClipRRect(
                borderRadius: AppRadii.sm,
                child: ProductImageWidget(imagePath: product.imagePath, size: 84),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            product.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            product.sku,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppFormatters.money(product.price, currency: currency),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.primary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (outOfStock)
                AppBadge.error(label: '${product.stockQty}')
              else if (low)
                AppBadge.warning(label: '${product.stockQty}')
              else
                AppBadge.success(label: '${product.stockQty}'),
            ],
          ),
        ],
      ),
    );
  }
}
