import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/state/app_cubit.dart';
import '../../../../data/local/seed/seed_data.dart';

class AppShellPage extends StatelessWidget {
  const AppShellPage({
    super.key,
    required this.currentPath,
    required this.child,
  });

  final String currentPath;
  final Widget child;

  static final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  /// Smoothly toggles or opens the right-hand navigation drawer across all screens & platforms
  static void openDrawer(BuildContext context) {
    if (scaffoldKey.currentState != null) {
      if (scaffoldKey.currentState!.isEndDrawerOpen) {
        scaffoldKey.currentState!.closeEndDrawer();
      } else {
        scaffoldKey.currentState!.openEndDrawer();
      }
    } else {
      final scaffold = Scaffold.maybeOf(context);
      if (scaffold != null) {
        if (scaffold.isEndDrawerOpen) {
          scaffold.closeEndDrawer();
        } else {
          scaffold.openEndDrawer();
        }
      } else {
        context.findRootAncestorStateOfType<ScaffoldState>()?.openEndDrawer();
      }
    }
  }

  static void toggleSidebar(BuildContext context) {
    openDrawer(context);
  }

  static const _mobileTabs = [
    '/home',
    '/pos',
    '/products',
    '/crm',
  ];

  int get _currentMobileIndex {
    for (var i = 0; i < _mobileTabs.length; i++) {
      if (currentPath.startsWith(_mobileTabs[i])) return i;
    }
    return 4; // 'More' if outside the 4 main tabs
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 720;

    return Scaffold(
      key: AppShellPage.scaffoldKey,
      endDrawer: _buildAppDrawer(context),
      body: child,
      bottomNavigationBar: isMobile
          ? NavigationBar(
              selectedIndex: _currentMobileIndex,
              destinations: const [
                NavigationDestination(
                  icon: Icon(TablerIcons.layoutDashboard),
                  selectedIcon: Icon(TablerIcons.layoutDashboardFilled),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(TablerIcons.receipt),
                  selectedIcon: Icon(TablerIcons.receiptFilled),
                  label: 'Billing',
                ),
                NavigationDestination(
                  icon: Icon(TablerIcons.packages),
                  selectedIcon: Icon(TablerIcons.packages),
                  label: 'Stock',
                ),
                NavigationDestination(
                  icon: Icon(TablerIcons.users),
                  selectedIcon: Icon(TablerIcons.users),
                  label: 'CRM',
                ),
                NavigationDestination(
                  icon: Icon(TablerIcons.menu2),
                  selectedIcon: Icon(TablerIcons.menu2),
                  label: 'Menu',
                ),
              ],
              onDestinationSelected: (index) {
                if (index == 4) {
                  openDrawer(context);
                  return;
                }
                if (index == _currentMobileIndex) return;
                context.go(_mobileTabs[index]);
              },
            )
          : null,
    );
  }

  Widget _buildAppDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header with Darvi Branding
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.5),
                border: const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/darvi_icon.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(TablerIcons.leaf, color: AppColors.primary, size: 26),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DarviCorporateInfo.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primaryDark),
                        ),
                        Text(
                          'GSTIN: ${DarviCorporateInfo.gstin}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(TablerIcons.x, size: 20),
                    tooltip: 'Close Menu',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Navigation Items organized into clear module categories
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Operations
                  const _SectionHeader(title: 'OPERATIONS'),
                  _DrawerItem(icon: TablerIcons.layoutDashboard, label: 'Dashboard', path: '/home', current: currentPath),
                  _DrawerItem(icon: TablerIcons.receipt, label: 'POS Billing', path: '/pos', current: currentPath),
                  _DrawerItem(icon: TablerIcons.truckDelivery, label: 'Deliveries & Logistics', path: '/deliveries', current: currentPath),
                  _DrawerItem(icon: TablerIcons.fileInvoice, label: 'Quotations', path: '/quotations', current: currentPath),

                  const Divider(height: 16),
                  // Catalog & Inventory
                  const _SectionHeader(title: 'CATALOG & INVENTORY'),
                  _DrawerItem(icon: TablerIcons.packages, label: 'Products Catalog', path: '/products', current: currentPath),
                  _DrawerItem(icon: TablerIcons.buildingStore, label: 'Stock & Inventory Central', path: '/inventory', current: currentPath),
                  _DrawerItem(icon: TablerIcons.shoppingBag, label: 'Purchases & Inward Stock', path: '/purchases', current: currentPath),

                  const Divider(height: 16),
                  // Vikshha Farmlands
                  const _SectionHeader(title: 'VIKSHHA FARMLANDS'),
                  _DrawerItem(icon: TablerIcons.users, label: 'Farmland CRM & Leads', path: '/crm', current: currentPath),
                  _DrawerItem(icon: TablerIcons.trees, label: 'Projects & Plots', path: '/plots', current: currentPath),
                  _DrawerItem(icon: TablerIcons.bookmark, label: 'Plot Bookings & Deeds', path: '/bookings', current: currentPath),

                  const Divider(height: 16),
                  // Financials & HR
                  const _SectionHeader(title: 'FINANCIALS & HR'),
                  _DrawerItem(icon: TablerIcons.wallet, label: 'Accounts & Ledger', path: '/financials', current: currentPath),
                  _DrawerItem(icon: TablerIcons.addressBook, label: 'Customers & Suppliers', path: '/parties', current: currentPath),
                  _DrawerItem(icon: TablerIcons.idBadge, label: 'Employees, Attendance & Payroll', path: '/employees', current: currentPath),
                  _DrawerItem(icon: TablerIcons.chartBar, label: 'Reports & Business Analytics', path: '/reports', current: currentPath),

                  const Divider(height: 16),
                  // System
                  const _SectionHeader(title: 'SYSTEM'),
                  _DrawerItem(icon: TablerIcons.settings, label: 'System Settings', path: '/settings', current: currentPath),
                ],
              ),
            ),

            // Logout Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  icon: const Icon(TablerIcons.logout, size: 18),
                  label: const Text('Logout Session'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.read<AppCubit>().logout();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.current,
  });

  final IconData icon;
  final String label;
  final String path;
  final String current;

  @override
  Widget build(BuildContext context) {
    final selected = current == path || current.startsWith('$path/');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryContainer.withValues(alpha: 0.7) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(icon, color: selected ? AppColors.primary : Colors.grey.shade700, size: 20),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13.5,
            color: selected ? AppColors.primaryDark : AppColors.textPrimary,
          ),
        ),
        selected: selected,
        onTap: () {
          Navigator.of(context).pop();
          if (!selected) context.go(path);
        },
      ),
    );
  }
}
