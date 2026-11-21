import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/states.dart';
import '../../../../domain/entities/app_entities.dart';
import '../cubit/pos_cubit.dart';
import 'cart_item_tile.dart';
import 'pos_batch_selector_dialog.dart';
import 'pos_customer_card.dart';
import 'pos_header.dart';
import 'product_tile.dart';

class PosWorkspaceView extends StatelessWidget {
  const PosWorkspaceView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PosCubit>();

    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        return Scaffold(
          appBar: const PosHeader(),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 960;

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LEFT PANEL: Product Discovery
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: [
                            _buildDiscoveryBar(context, cubit, state),
                            const SizedBox(height: AppSpacing.sm),
                            _buildCategoryChips(context, cubit, state),
                            const SizedBox(height: AppSpacing.sm),
                            Expanded(child: _buildProductList(context, cubit, state)),
                          ],
                        ),
                      ),
                    ),

                    const VerticalDivider(width: 1, thickness: 1),

                    // RIGHT PANEL: Active Cart & Checkout Trigger
                    SizedBox(
                      width: min(440, constraints.maxWidth * 0.42),
                      child: Container(
                        color: Colors.grey.shade50,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: [
                            const PosCustomerCard(),
                            const SizedBox(height: AppSpacing.sm),
                            Expanded(child: _buildCartList(context, cubit, state)),
                            const SizedBox(height: AppSpacing.sm),
                            _buildCartBillingSummary(context, cubit, state),
                            const SizedBox(height: AppSpacing.md),
                            PrimaryButton(
                              label: 'Proceed to Checkout (${state.totalQuantityCount} items)',
                              icon: TablerIcons.arrowRight,
                              minHeight: 50,
                              onPressed: state.cart.isEmpty
                                  ? null
                                  : () => cubit.setViewMode(PosViewMode.checkoutReview),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              // MOBILE / COMPACT LAYOUT
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                    child: _buildDiscoveryBar(context, cubit, state),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: _buildCategoryChips(context, cubit, state),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Expanded(child: _buildProductList(context, cubit, state)),
                  _buildMobileBottomCartBar(context, cubit, state),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDiscoveryBar(BuildContext context, PosCubit cubit, PosState state) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search product, SKU, barcode...',
                prefixIcon: const Icon(TablerIcons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: AppRadii.md),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (val) => cubit.updateFilter(search: val),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF135D44),
            shape: RoundedRectangleBorder(borderRadius: AppRadii.md),
            minimumSize: const Size(48, 48),
          ),
          icon: const Icon(TablerIcons.scan, color: Colors.white),
          tooltip: 'Scan Barcode',
          onPressed: () => cubit.scanAndAdd(),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          tooltip: state.layoutMode == ProductLayoutMode.grid ? 'List View' : 'Grid View',
          icon: Icon(
            state.layoutMode == ProductLayoutMode.grid ? TablerIcons.layoutList : TablerIcons.layoutGrid,
            color: const Color(0xFF135D44),
          ),
          onPressed: () => cubit.setLayoutMode(
            state.layoutMode == ProductLayoutMode.grid ? ProductLayoutMode.list : ProductLayoutMode.grid,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips(BuildContext context, PosCubit cubit, PosState state) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ChoiceChip(
            label: Text('All Products (${state.products.length})'),
            selected: state.filter.categoryId == null,
            onSelected: (_) => cubit.updateFilter(categoryId: -1),
          ),
          const SizedBox(width: AppSpacing.sm),
          ...state.categories.map((cat) {
            final count = state.products.where((p) => p.categoryId == cat.id).length;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text('${cat.name} ($count)'),
                selected: state.filter.categoryId == cat.id,
                onSelected: (_) => cubit.updateFilter(categoryId: cat.id),
              ),
            );
          }),
          FilterChip(
            label: const Text('Low Stock'),
            selected: state.filter.lowStockOnly,
            onSelected: (_) => cubit.updateFilter(lowStockOnly: !state.filter.lowStockOnly),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(BuildContext context, PosCubit cubit, PosState state) {
    final products = state.filteredProducts;

    if (products.isEmpty) {
      return const EmptyState(message: 'No matching products found.');
    }

    if (state.layoutMode == ProductLayoutMode.list) {
      return ListView.separated(
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) {
          final product = products[index];
          final cartItem = state.cart.where((c) => c.productId == product.id).firstOrNull;
          final cartQty = cartItem?.qty ?? 0;

          return ProductTile(
            product: product,
            currency: 'INR',
            cartQty: cartQty,
            onTap: () => _handleProductSelection(context, cubit, product),
            onIncrease: () {
              if (cartQty == 0) {
                _handleProductSelection(context, cubit, product);
              } else {
                cubit.updateItemQty(product.id, cartQty + 1);
              }
            },
            onDecrease: () {
              if (cartQty <= 1) {
                cubit.removeFromCart(product.id);
              } else {
                cubit.updateItemQty(product.id, cartQty - 1);
              }
            },
          );
        },
      );
    }

    return GridView.builder(
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.74,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        final isLowStock = product.isLowStock;
        final isOutOfStock = product.stockQty <= 0;
        final cartItem = state.cart.where((c) => c.productId == product.id).firstOrNull;
        final cartQty = cartItem?.qty ?? 0;

        return InkWell(
          borderRadius: AppRadii.md,
          onTap: () => _handleProductSelection(context, cubit, product),
          child: Card(
            elevation: cartQty > 0 ? 2 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadii.md,
              side: BorderSide(
                color: cartQty > 0 ? const Color(0xFF135D44).withValues(alpha: 0.6) : Colors.grey.shade200,
                width: cartQty > 0 ? 1.5 : 1.0,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Center(
                      child: ProductImageWidget(
                        imagePath: product.imagePath,
                        size: 64,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    '${product.sku} • ${product.categoryName ?? ""}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppFormatters.money(product.price, currency: 'INR'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF135D44),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isOutOfStock
                              ? Colors.red.shade100
                              : (isLowStock ? Colors.orange.shade100 : Colors.green.shade100),
                          borderRadius: AppRadii.sm,
                        ),
                        child: Text(
                          '${product.stockQty}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isOutOfStock
                                ? Colors.red.shade900
                                : (isLowStock ? Colors.orange.shade900 : Colors.green.shade900),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Zomato Math Stepper in Grid
                  if (cartQty > 0)
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF135D44),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () {
                              if (cartQty <= 1) {
                                cubit.removeFromCart(product.id);
                              } else {
                                cubit.updateItemQty(product.id, cartQty - 1);
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.remove, size: 14, color: Colors.white),
                            ),
                          ),
                          Text(
                            '$cartQty',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          InkWell(
                            onTap: () => cubit.updateItemQty(product.id, cartQty + 1),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.add, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    InkWell(
                      onTap: () => _handleProductSelection(context, cubit, product),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF135D44)),
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'ADD',
                              style: TextStyle(
                                color: Color(0xFF135D44),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.add, size: 12, color: Color(0xFF135D44)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleProductSelection(BuildContext context, PosCubit cubit, ProductView product) async {
    await cubit.loadBatchesForProduct(product.id);
    final batches = cubit.state.productBatches[product.id] ?? [];

    if (batches.length > 1 && context.mounted) {
      showDialog<void>(
        context: context,
        builder: (_) => PosBatchSelectorDialog(
          product: product,
          batches: batches,
          onBatchSelected: (selectedBatch) {
            cubit.addProductToCart(
              product,
              batchId: selectedBatch.id,
              batchNumber: selectedBatch.batchNumber,
              customPrice: selectedBatch.sellingPrice > 0 ? selectedBatch.sellingPrice : product.price,
            );
          },
        ),
      );
    } else if (batches.length == 1) {
      final b = batches.first;
      cubit.addProductToCart(
        product,
        batchId: b.id,
        batchNumber: b.batchNumber,
        customPrice: b.sellingPrice > 0 ? b.sellingPrice : product.price,
      );
    } else {
      cubit.addProductToCart(product);
    }
  }

  Widget _buildCartList(BuildContext context, PosCubit cubit, PosState state) {
    if (state.cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(TablerIcons.shoppingCart, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Cart is empty',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Select products or scan barcodes to begin',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: state.cart.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final item = state.cart[index];
        return CartItemTile(
          item: item,
          currency: 'INR',
          canEditPrice: true,
          onIncrease: () => cubit.updateItemQty(item.productId, item.qty + 1),
          onDecrease: () => cubit.updateItemQty(item.productId, item.qty - 1),
          onRemove: () => cubit.removeFromCart(item.productId),
          onDiscountEdit: (disc) => cubit.setItemDiscount(item.productId, disc),
          onPriceEdit: (price) => cubit.setItemPrice(item.productId, price),
        );
      },
    );
  }

  Widget _buildCartBillingSummary(BuildContext context, PosCubit cubit, PosState state) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadii.md,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal (${state.totalQuantityCount} items):', style: const TextStyle(fontSize: 12)),
              Text(
                AppFormatters.money(state.subtotal, currency: 'INR'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => _showDiscountDialog(context, cubit, state),
                child: Row(
                  children: [
                    const Icon(TablerIcons.discount, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      'Bill Discount ${state.orderDiscount > 0 ? "(-${AppFormatters.money(state.orderDiscount, currency: "INR")})" : ""}:',
                      style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Text(
                '-${AppFormatters.money(state.orderDiscount, currency: "INR")}',
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('GST (18%):', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Switch(
                    value: state.taxEnabled,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) => cubit.setTaxEnabled(val),
                  ),
                ],
              ),
              Text(
                AppFormatters.money(state.tax, currency: 'INR'),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          if (state.roundOff != 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Round-Off:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  state.roundOff.toStringAsFixed(2),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grand Total:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                AppFormatters.money(state.total, currency: 'INR'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF135D44),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDiscountDialog(BuildContext context, PosCubit cubit, PosState state) {
    final controller = TextEditingController(text: state.discountInput.toStringAsFixed(2));
    var selectedType = state.discountType;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          return AlertDialog(
            title: const Text('Apply Bill Discount'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<DiscountType>(
                  segments: const [
                    ButtonSegment(value: DiscountType.fixed, label: Text('Fixed (₹)')),
                    ButtonSegment(value: DiscountType.percentage, label: Text('Percent (%)')),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (set) => setModalState(() => selectedType = set.first),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: selectedType == DiscountType.percentage ? 'Discount (%)' : 'Discount (₹)',
                    border: const OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  cubit.setDiscount(DiscountType.fixed, 0);
                  Navigator.pop(dialogCtx);
                },
                child: const Text('Clear'),
              ),
              ElevatedButton(
                onPressed: () {
                  final val = double.tryParse(controller.text) ?? 0.0;
                  cubit.setDiscount(selectedType, val);
                  Navigator.pop(dialogCtx);
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobileBottomCartBar(BuildContext context, PosCubit cubit, PosState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${state.totalQuantityCount} Items in Cart',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  AppFormatters.money(state.total, currency: 'INR'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF135D44),
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF135D44),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: AppRadii.md),
              ),
              icon: const Icon(TablerIcons.shoppingBag),
              label: const Text('Review Cart & Checkout'),
              onPressed: state.cart.isEmpty
                  ? null
                  : () => cubit.setViewMode(PosViewMode.checkoutReview),
            ),
          ],
        ),
      ),
    );
  }
}
