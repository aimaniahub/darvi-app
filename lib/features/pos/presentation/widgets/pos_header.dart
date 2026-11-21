import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../cubit/pos_cubit.dart';
import 'pos_held_bills_dialog.dart';

class PosHeader extends StatelessWidget implements PreferredSizeWidget {
  const PosHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(AppHeader.kAppHeaderHeight);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        final cubit = context.read<PosCubit>();

        return AppHeader(
          title: 'POS Billing',
          subtitle: 'Agri Tech Hubli',
          actions: [
            // Cashier Name with Quick Edit
            InkWell(
              borderRadius: AppRadii.sm,
              onTap: () => _showEditCashierDialog(context, cubit, state.cashierName),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(TablerIcons.user, color: AppColors.primary, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      state.cashierName,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(TablerIcons.chevronDown, color: AppColors.primary, size: 14),
                  ],
                ),
              ),
            ),

            // Held Bills Action with Badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: const Icon(TablerIcons.playerPause, size: 14),
                  label: const Text('Held', style: TextStyle(fontSize: 12)),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => BlocProvider.value(
                      value: cubit,
                      child: const PosHeldBillsDialog(),
                    ),
                  ),
                ),
                if (state.heldBills.isNotEmpty)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${state.heldBills.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Park Current Bill
            if (state.cart.isNotEmpty)
              IconButton(
                tooltip: 'Park / Hold Current Bill',
                icon: const Icon(TablerIcons.bookmarkPlus, color: AppColors.warning, size: 18),
                onPressed: () => _showParkBillDialog(context, cubit),
              ),

            // Clear Cart / New Bill
            IconButton(
              tooltip: 'New Bill / Clear Cart',
              icon: const Icon(TablerIcons.refresh, color: AppColors.textPrimary, size: 18),
              onPressed: () {
                if (state.cart.isNotEmpty) {
                  _showClearConfirm(context, cubit);
                } else {
                  cubit.newSale();
                }
              },
            ),

            // Invoices History
            IconButton(
              tooltip: 'Invoice History',
              icon: const Icon(TablerIcons.history, color: AppColors.textPrimary, size: 18),
              onPressed: () => context.push('/reports'),
            ),
          ],
        );
      },
    );
  }

  void _showEditCashierDialog(BuildContext context, PosCubit cubit, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Cashier Identity'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Cashier Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                cubit.setCashierName(controller.text.trim());
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showParkBillDialog(BuildContext context, PosCubit cubit) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Park / Hold Bill'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Save this active cart so you can attend another customer. You can resume it anytime.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Reference Note (Optional)',
                hintText: 'e.g. Customer forgot wallet, phone payment...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              cubit.holdCurrentBill(note: controller.text.trim().isEmpty ? null : controller.text.trim());
              Navigator.pop(dialogCtx);
            },
            child: const Text('Hold Bill'),
          ),
        ],
      ),
    );
  }

  void _showClearConfirm(BuildContext context, PosCubit cubit) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Clear Active Cart?'),
        content: const Text('All added items in the current cart will be discarded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              cubit.clearCart();
              Navigator.pop(dialogCtx);
            },
            child: const Text('Clear Cart'),
          ),
        ],
      ),
    );
  }

}
