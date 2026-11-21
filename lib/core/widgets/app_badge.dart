import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum AppBadgeTone {
  success,
  warning,
  error,
  info,
  neutral,
}

/// Semantic status pill badge for Darvi Billing & ERP (inspired by Kite UI).
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.neutral,
    this.icon,
    this.showDot = false,
  });

  const AppBadge.success({
    super.key,
    required this.label,
    this.icon,
    this.showDot = false,
  }) : tone = AppBadgeTone.success;

  const AppBadge.warning({
    super.key,
    required this.label,
    this.icon,
    this.showDot = false,
  }) : tone = AppBadgeTone.warning;

  const AppBadge.error({
    super.key,
    required this.label,
    this.icon,
    this.showDot = false,
  }) : tone = AppBadgeTone.error;

  const AppBadge.info({
    super.key,
    required this.label,
    this.icon,
    this.showDot = false,
  }) : tone = AppBadgeTone.info;

  const AppBadge.neutral({
    super.key,
    required this.label,
    this.icon,
    this.showDot = false,
  }) : tone = AppBadgeTone.neutral;

  final String label;
  final AppBadgeTone tone;
  final IconData? icon;
  final bool showDot;

  (Color bg, Color fg) get _colors => switch (tone) {
        AppBadgeTone.success => (AppColors.successContainer, AppColors.successText),
        AppBadgeTone.warning => (AppColors.warningContainer, AppColors.warningText),
        AppBadgeTone.error => (AppColors.errorContainer, AppColors.errorText),
        AppBadgeTone.info => (AppColors.infoContainer, AppColors.infoText),
        AppBadgeTone.neutral => (AppColors.surfaceElevated, AppColors.textSecondary),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.pill,
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ] else if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: fg,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Backwards compatibility wrapper for StatusChip
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.md,
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

