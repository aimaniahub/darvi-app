import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Responsive Master-Detail Split View (adapted from Flutter Templates `SplitView`).
/// Displays master and detail panes side-by-side on desktop/tablet, and switches
/// to stacked view on mobile.
class AppSplitView extends StatelessWidget {
  const AppSplitView({
    super.key,
    required this.master,
    required this.detail,
    this.masterWidth = 340.0,
    this.showDetailOnMobile = false,
    this.breakpoint = AppDimensions.breakpointMobile,
    this.dividerColor,
  });

  final Widget master;
  final Widget? detail;
  final double masterWidth;
  final bool showDetailOnMobile;
  final double breakpoint;
  final Color? dividerColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= breakpoint;

        if (!isWide) {
          // Mobile: show detail if requested and available, else master
          if (showDetailOnMobile && detail != null) {
            return detail!;
          }
          return master;
        }

        // Desktop / Tablet: Side-by-Side Dual Pane
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: masterWidth,
              child: master,
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: dividerColor ?? AppColors.border,
            ),
            Expanded(
              child: detail ??
                  const Center(
                    child: Text(
                      'Select an item to view details',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
            ),
          ],
        );
      },
    );
  }
}

