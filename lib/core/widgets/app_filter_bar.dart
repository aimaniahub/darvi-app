import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_spacing.dart';
import 'app_search_field.dart';

class FilterOption {
  const FilterOption({
    required this.id,
    required this.label,
    this.badge,
  });

  final String id;
  final String label;
  final String? badge;
}

/// Unified filter and search toolbar for resource tables and catalog screens.
/// Ported and refined from Kite UI's Resource Toolbar.
class AppFilterBar extends StatelessWidget {
  const AppFilterBar({
    super.key,
    this.searchController,
    this.searchHint = 'Search...',
    this.onSearchChanged,
    this.onSearchClear,
    this.filterOptions = const [],
    this.selectedFilterId,
    this.onFilterSelected,
    this.onRefresh,
    this.onClearFilters,
    this.trailingAction,
    this.isRefreshing = false,
  });

  final TextEditingController? searchController;
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClear;
  final List<FilterOption> filterOptions;
  final String? selectedFilterId;
  final ValueChanged<String>? onFilterSelected;
  final VoidCallback? onRefresh;
  final VoidCallback? onClearFilters;
  final Widget? trailingAction;
  final bool isRefreshing;

  bool get _hasActiveFilters =>
      (selectedFilterId != null && selectedFilterId!.isNotEmpty) ||
      (searchController != null && searchController!.text.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadii.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Left side: Search + Filter Chips
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: AppSearchField(
                  controller: searchController,
                  hint: searchHint,
                  height: AppDimensions.filterHeight,
                  onChanged: onSearchChanged,
                  onClear: onSearchClear,
                ),
              ),
              for (final opt in filterOptions) ...[
                _buildFilterChip(context, opt),
              ],
            ],
          ),

          // Right side: Actions & Refresh
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_hasActiveFilters && onClearFilters != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.error,
                  ),
                  icon: const Icon(TablerIcons.x, size: 14),
                  label: const Text('Clear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: onClearFilters,
                ),
              if (onRefresh != null)
                IconButton(
                  tooltip: 'Refresh',
                  icon: isRefreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(TablerIcons.refresh, size: 18, color: AppColors.textSecondary),
                  onPressed: isRefreshing ? null : onRefresh,
                ),
              if (trailingAction != null) trailingAction!,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, FilterOption option) {
    final isSelected = selectedFilterId == option.id;

    return InkWell(
      onTap: () => onFilterSelected?.call(option.id),
      borderRadius: AppRadii.pill,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: AppDimensions.filterHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: AppRadii.pill,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              option.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            if (option.badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white24 : AppColors.border,
                  borderRadius: AppRadii.pill,
                ),
                child: Text(
                  option.badge!,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
