import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/app_models.dart';
import '../../../../core/utils/formatters.dart';

class CartItemTile extends StatelessWidget {
  const CartItemTile({
    super.key,
    required this.item,
    required this.currency,
    required this.canEditPrice,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    required this.onDiscountEdit,
    required this.onPriceEdit,
  });

  final CartItem item;
  final String currency;
  final bool canEditPrice;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;
  final ValueChanged<double> onDiscountEdit;
  final ValueChanged<double> onPriceEdit;

  @override
  Widget build(BuildContext context) {
    final lineTotal = (item.price * item.qty) - item.discount;
    return Dismissible(
      key: ValueKey('cart_${item.productId}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: AppRadii.md,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Icon(TablerIcons.trash, color: Theme.of(context).colorScheme.error),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Text(
                    AppFormatters.money(lineTotal, currency: currency),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _QtyButton(icon: TablerIcons.minus, onTap: onDecrease),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Text('${item.qty}', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  _QtyButton(icon: TablerIcons.plus, onTap: onIncrease),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showAmountDialog(
                      context,
                      title: 'Item discount',
                      initial: item.discount,
                      onSubmit: onDiscountEdit,
                    ),
                    icon: const Icon(TablerIcons.discount, size: 16),
                    label: Text('Disc ${item.discount.toStringAsFixed(2)}'),
                  ),
                  if (canEditPrice)
                    TextButton.icon(
                      onPressed: () => _showAmountDialog(
                        context,
                        title: 'Edit item price',
                        initial: item.price,
                        onSubmit: onPriceEdit,
                      ),
                      icon: const Icon(TablerIcons.edit, size: 16),
                      label: Text(item.price.toStringAsFixed(2)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAmountDialog(
    BuildContext context, {
    required String title,
    required double initial,
    required ValueChanged<double> onSubmit,
  }) {
    final controller = TextEditingController(text: initial.toStringAsFixed(2));
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text) ?? initial;
              onSubmit(val < 0 ? 0.0 : val);
              Navigator.pop(dialogCtx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      icon: Icon(icon, size: 16),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}
