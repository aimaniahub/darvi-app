import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/cards.dart';

class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DarviSectionHeader(title: 'Quick Operations'),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              QuickActionButton(
                label: 'New Sale POS',
                icon: TablerIcons.receipt,
                color: AppColors.primary,
                onTap: () => context.go('/pos'),
              ),
              const SizedBox(width: AppSpacing.sm),
              QuickActionButton(
                label: 'Add Product',
                icon: TablerIcons.packageExport,
                color: Colors.deepPurple,
                onTap: () => context.go('/products'),
              ),
              const SizedBox(width: AppSpacing.sm),
              QuickActionButton(
                label: 'Inward Purchase',
                icon: TablerIcons.shoppingBag,
                color: Colors.blue.shade700,
                onTap: () => context.go('/purchases'),
              ),
              const SizedBox(width: AppSpacing.sm),
              QuickActionButton(
                label: 'New Customer',
                icon: TablerIcons.userPlus,
                color: Colors.teal,
                onTap: () => context.go('/parties'),
              ),
              const SizedBox(width: AppSpacing.sm),
              QuickActionButton(
                label: 'Record Expense',
                icon: TablerIcons.wallet,
                color: Colors.red.shade700,
                onTap: () => context.go('/financials'),
              ),
              const SizedBox(width: AppSpacing.sm),
              QuickActionButton(
                label: 'New Lead CRM',
                icon: TablerIcons.usersGroup,
                color: AppColors.leafAccent,
                onTap: () => context.go('/crm'),
              ),
              const SizedBox(width: AppSpacing.sm),
              QuickActionButton(
                label: 'Register Plot',
                icon: TablerIcons.mapPin,
                color: AppColors.primaryLight,
                onTap: () => context.go('/plots'),
              ),
              const SizedBox(width: AppSpacing.sm),
              QuickActionButton(
                label: 'Plot Booking',
                icon: TablerIcons.bookmarkPlus,
                color: Colors.amber.shade800,
                onTap: () => context.go('/bookings'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
