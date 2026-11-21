import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_empty_state.dart';
import 'app_loading_state.dart';

class AppDataColumn<T> {
  const AppDataColumn({
    required this.title,
    required this.cellBuilder,
    this.width,
    this.numeric = false,
    this.alignment = Alignment.centerLeft,
    this.sortable = false,
  });

  final String title;
  final Widget Function(BuildContext context, T item, int index) cellBuilder;
  final double? width;
  final bool numeric;
  final Alignment alignment;
  final bool sortable;
}

/// Generic, responsive data table with sticky-like headers, typed columns,
/// sorting indicators, and row selection (adapted from Flutter Templates & Kite UI).
class AppDataTable<T> extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.items,
    this.onRowTap,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSort,
    this.loading = false,
    this.emptyMessage = 'No records found',
    this.emptyAction,
    this.currentPage,
    this.totalPages,
    this.onPageChanged,
    this.minWidth = 600.0,
  });

  final List<AppDataColumn<T>> columns;
  final List<T> items;
  final ValueChanged<T>? onRowTap;
  final int? sortColumnIndex;
  final bool sortAscending;
  final void Function(int columnIndex, bool ascending)? onSort;
  final bool loading;
  final String emptyMessage;
  final Widget? emptyAction;
  final int? currentPage;
  final int? totalPages;
  final ValueChanged<int>? onPageChanged;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    if (loading && items.isEmpty) {
      return const AppLoadingSkeleton(count: 6);
    }

    if (!loading && items.isEmpty) {
      return AppEmptyState(
        message: emptyMessage,
        action: emptyAction,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadii.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scrollable Table Area
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minWidth),
              child: DataTable(
                sortColumnIndex: sortColumnIndex,
                sortAscending: sortAscending,
                headingRowHeight: 44,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 60,
                horizontalMargin: 16,
                columnSpacing: 24,
                headingRowColor: const WidgetStatePropertyAll<Color>(AppColors.surfaceElevated),
                dividerThickness: 1,
                border: const TableBorder(
                  horizontalInside: BorderSide(color: AppColors.borderSubtle, width: 1),
                ),
                columns: [
                  for (var i = 0; i < columns.length; i++)
                    DataColumn(
                      numeric: columns[i].numeric,
                      onSort: columns[i].sortable && onSort != null
                          ? (idx, asc) => onSort!(i, asc)
                          : null,
                      label: Text(
                        columns[i].title,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                ],
                rows: [
                  for (var r = 0; r < items.length; r++)
                    DataRow(
                      onSelectChanged: onRowTap != null
                          ? (_) => onRowTap!(items[r])
                          : null,
                      cells: [
                        for (var c = 0; c < columns.length; c++)
                          DataCell(
                            Container(
                              alignment: columns[c].alignment,
                              width: columns[c].width,
                              child: columns[c].cellBuilder(context, items[r], r),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Optional Pagination Footer
          if (totalPages != null && totalPages! > 1) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Page ${currentPage ?? 1} of $totalPages (${items.length} records)',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(TablerIcons.chevronLeft, size: 16),
                        tooltip: 'Previous page',
                        onPressed: (currentPage ?? 1) > 1 && onPageChanged != null
                            ? () => onPageChanged!((currentPage ?? 1) - 1)
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(TablerIcons.chevronRight, size: 16),
                        tooltip: 'Next page',
                        onPressed: (currentPage ?? 1) < totalPages! && onPageChanged != null
                            ? () => onPageChanged!((currentPage ?? 1) + 1)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
