import 'package:flutter/widgets.dart';
import '../theme/app_spacing.dart';

/// Lays out stat tiles and KPI cards at a consistent, bounded height with flexible responsive width.
/// Adapted to guarantee a responsive 2-column grid on mobile, 2-3 on tablet, and 3-4 on desktop.
class AppStatGrid extends StatelessWidget {
  const AppStatGrid({
    super.key,
    required this.children,
    this.spacing = AppSpacing.sm,
    this.minTileWidth = 140.0,
    this.columns,
    this.maxColumns,
  });

  final List<Widget> children;
  final double spacing;
  final double minTileWidth;
  final int? columns;
  final int? maxColumns;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        int cols;
        if (columns != null) {
          cols = columns!;
        } else if (availableWidth < 600) {
          cols = 2; // Mobile: strictly 2 columns!
        } else if (availableWidth < 960) {
          cols = 3; // Tablet: 2-3 columns
        } else {
          cols = 4; // Desktop: 3-4 columns
        }
        if (maxColumns != null && cols > maxColumns!) {
          cols = maxColumns!;
        }
        cols = cols.clamp(1, children.length);

        final rows = <List<Widget>>[];
        for (var i = 0; i < children.length; i += cols) {
          rows.add(
            children.sublist(i, (i + cols).clamp(0, children.length)),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) SizedBox(height: spacing),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < cols; i++) ...[
                      if (i > 0) SizedBox(width: spacing),
                      Expanded(
                        child: i < rows[r].length
                            ? rows[r][i]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
