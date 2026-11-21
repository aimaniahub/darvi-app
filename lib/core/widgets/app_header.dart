import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../app/theme/app_theme.dart';
import '../../core/state/app_cubit.dart';
import '../../features/shell/presentation/pages/app_shell_page.dart';

/// Single item in a navigation breadcrumb trail.
class BreadcrumbItem {
  const BreadcrumbItem({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;
}

/// Global Application Header for Darvi Billing & ERP.
///
/// Implements [PreferredSizeWidget] so it can be passed directly to
/// [Scaffold.appBar] across all application screens.
///
/// Guarantees exact visual and structural standardization across every module:
/// - Exact 64px standard toolbar height (plus optional bottom tabs)
/// - Pure surface background (`AppColors.surface`) with a crisp 1px border (`AppColors.border`)
/// - Standard typography (`AppTypography` scale)
/// - Left section: Context-aware Back button (if canPop), persistent Darvi brand mark, and title/subtitle
/// - Right section: Screen actions, user/role badge, and right-side navigation drawer toggle (Menu)
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.breadcrumbs,
    this.breadcrumb,
    this.subtitle,
    this.titleWidget,
    this.leading,
    this.showBackButton,
    this.onBackPressed,
    this.showSidebarToggle = true,
    this.onSidebarToggle,
    this.actions,
    this.bottom,
    this.height = kAppHeaderHeight,
    this.badge,
  });

  /// Standard default height for the global header toolbar.
  static const double kAppHeaderHeight = 64.0;

  /// Main title of the screen.
  final String title;

  /// Optional custom title widget override. If provided, replaces the default text title.
  final Widget? titleWidget;

  /// Breadcrumb path items reflecting hierarchy, e.g. `['Vikshha CRM', 'Projects']`.
  final List<String>? breadcrumbs;

  /// Single breadcrumb string shortcut, e.g. `'Products'`.
  final String? breadcrumb;

  /// Subtitle or short description displayed under or alongside the title.
  final String? subtitle;

  /// Custom leading widget. If omitted, automatically resolves back button if context can pop.
  final Widget? leading;

  /// Whether to force display the back button.
  /// If null, automatically displays back button if the current context can pop.
  final bool? showBackButton;

  /// Custom callback for the back button. Defaults to popping the router / navigator.
  final VoidCallback? onBackPressed;

  /// Whether to show the right-side sidebar/drawer menu toggle. Defaults to true.
  final bool showSidebarToggle;

  /// Custom callback for the sidebar toggle button. Defaults to [AppShellPage.toggleSidebar].
  final VoidCallback? onSidebarToggle;

  /// Screen-specific action buttons displayed on the right side.
  final List<Widget>? actions;

  /// Optional bottom widget, such as a [TabBar].
  final PreferredSizeWidget? bottom;

  /// Header toolbar height. Defaults to [kAppHeaderHeight].
  final double height;

  /// Optional decorative or status badge next to title.
  final Widget? badge;

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0.0;
    return Size.fromHeight(height + bottomHeight);
  }

  bool _shouldShowBackButton(BuildContext context) {
    if (showBackButton != null) return showBackButton!;
    try {
      if (context.canPop()) return true;
    } catch (_) {}
    return Navigator.of(context).canPop();
  }

  Widget? _buildLeading(BuildContext context) {
    if (leading != null) return leading;

    final shouldBack = _shouldShowBackButton(context);
    if (shouldBack) {
      return IconButton(
        icon: const Icon(TablerIcons.arrowLeft, size: 22, color: AppColors.textPrimary),
        tooltip: 'Back',
        splashRadius: 20,
        onPressed: onBackPressed ??
            () {
              if (context.canPop()) {
                context.pop();
              } else {
                Navigator.of(context).maybePop();
              }
            },
      );
    }

    return null;
  }

  List<String> get _resolvedBreadcrumbs {
    if (breadcrumbs != null && breadcrumbs!.isNotEmpty) return breadcrumbs!;
    if (breadcrumb != null && breadcrumb!.trim().isNotEmpty) return [breadcrumb!.trim()];
    return const [];
  }

  Widget _buildTitleArea(BuildContext context) {
    if (titleWidget != null) return titleWidget!;

    final trails = _resolvedBreadcrumbs;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Persistent Darvi Brand Logo Mark
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/darvi_icon.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(TablerIcons.leaf, color: AppColors.primary, size: 20),
          ),
        ),

        // Title and Breadcrumbs/Subtitle Column
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trails.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < trails.length; i++) ...[
                        if (i > 0)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(TablerIcons.chevronRight, size: 11, color: AppColors.textSecondary),
                          ),
                        Flexible(
                          child: Text(
                            trails[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    badge!,
                  ],
                ],
              ),
              if (subtitle != null && trails.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserRoleBadge(BuildContext context) {
    String role = 'ADMIN';
    try {
      final appCubit = context.read<AppCubit>();
      role = appCubit.state.session?.role.name.toUpperCase() ?? 'ADMIN';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(TablerIcons.userCheck, size: 13, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            role,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildBottom() {
    final bottomWidget = bottom;
    if (bottomWidget == null) {
      return PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          color: AppColors.border,
          height: 1.0,
        ),
      );
    }

    return PreferredSize(
      preferredSize: Size.fromHeight(bottomWidget.preferredSize.height + 1.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          bottomWidget,
          Container(
            color: AppColors.border,
            height: 1.0,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leadingWidget = _buildLeading(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final showRoleBadge = screenWidth >= 520;

    return AppBar(
      toolbarHeight: height,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leading: leadingWidget,
      titleSpacing: leadingWidget != null ? 4.0 : AppSpacing.md,
      title: _buildTitleArea(context),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Screen-specific actions
              if (actions != null && actions!.isNotEmpty)
                ...actions!.map((act) => Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: act,
                    )),

              // Current User Role Indicator
              if (showRoleBadge) _buildUserRoleBadge(context),

              // Menu / Right-side Drawer Toggle
              if (showSidebarToggle)
                IconButton(
                  icon: const Icon(TablerIcons.menu2, size: 22, color: AppColors.textPrimary),
                  tooltip: 'Menu & Sidebar',
                  splashRadius: 20,
                  onPressed: onSidebarToggle ?? () => AppShellPage.toggleSidebar(context),
                ),
            ],
          ),
        ),
      ],
      bottom: _buildBottom(),
    );
  }
}
