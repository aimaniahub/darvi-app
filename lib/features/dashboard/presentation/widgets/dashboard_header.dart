import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/state/app_cubit.dart';
import '../../../../data/local/seed/seed_data.dart';
import '../../../shell/presentation/pages/app_shell_page.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.appState,
    required this.alertCount,
    required this.onNotificationTap,
    this.onSidebarTap,
  });

  final AppState appState;
  final int alertCount;
  final VoidCallback onNotificationTap;
  final VoidCallback? onSidebarTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateFormatted = DateFormat('EEEE, dd MMMM yyyy').format(now);
    final roleName = appState.session?.role.name.toUpperCase() ?? 'ADMIN';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 620;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main Top Bar Row: Left Brand Logo & Title | Right Notifications, Role, Sidebar
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Left Side: Brand Logo Mark (40x40 container)
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
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.primaryContainer,
                        alignment: Alignment.center,
                        child: const Icon(TablerIcons.leaf, color: AppColors.primary, size: 22),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // 2. Left Side: Business Title & Date (vertically centered)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                DarviCorporateInfo.businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'HUB-01',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateFormatted,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // 3. Right Side: Notification Icon, Role Profile Pill, and Sidebar Toggle
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Notification Bell Button (40x40 matching box)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: onNotificationTap,
                          tooltip: 'Alerts & Reminders',
                          icon: Badge(
                            isLabelVisible: alertCount > 0,
                            label: Text(
                              '$alertCount',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: AppColors.warning,
                            child: const Icon(TablerIcons.bell, size: 20, color: AppColors.textPrimary),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // User Profile Badge (40px height)
                      Container(
                        height: 40,
                        padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.primary,
                              child: Text(
                                roleName.isNotEmpty ? roleName[0] : 'U',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (!isCompact) ...[
                              const SizedBox(width: 8),
                              Text(
                                roleName,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Sidebar / Menu Navigation Button (40x40 matching box)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          tooltip: 'Navigation Menu & Sidebar',
                          icon: const Icon(TablerIcons.layoutSidebar, size: 20, color: AppColors.textPrimary),
                          onPressed: onSidebarTap ?? () => AppShellPage.toggleSidebar(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Greeting & Sub-header line
              Row(
                children: [
                  const Icon(TablerIcons.sparkles, size: 14, color: AppColors.leafAccent),
                  const SizedBox(width: 6),
                  Text(
                    'Welcome back! Here is your business performance summary.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
