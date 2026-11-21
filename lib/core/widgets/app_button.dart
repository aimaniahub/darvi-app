import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_spacing.dart';

enum AppButtonVariant {
  primary,
  secondary,
  outlined,
  danger,
  ghost,
}

enum AppButtonSize {
  standard,
  compact,
  small,
}

/// Unified button component for Darvi Billing & ERP.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.standard,
    this.expanded = false,
    this.loading = false,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.size = AppButtonSize.standard,
    this.expanded = false,
    this.loading = false,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.size = AppButtonSize.standard,
    this.expanded = false,
    this.loading = false,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.outlined({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.size = AppButtonSize.standard,
    this.expanded = false,
    this.loading = false,
  }) : variant = AppButtonVariant.outlined;

  const AppButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.size = AppButtonSize.standard,
    this.expanded = false,
    this.loading = false,
  }) : variant = AppButtonVariant.danger;

  const AppButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.size = AppButtonSize.standard,
    this.expanded = false,
    this.loading = false,
  }) : variant = AppButtonVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool expanded;
  final bool loading;

  double get _height => switch (size) {
        AppButtonSize.standard => AppDimensions.buttonHeight,
        AppButtonSize.compact => AppDimensions.buttonHeightCompact,
        AppButtonSize.small => AppDimensions.buttonHeightSm,
      };

  double get _iconSize => switch (size) {
        AppButtonSize.standard => 18.0,
        AppButtonSize.compact => 16.0,
        AppButtonSize.small => 14.0,
      };

  EdgeInsets get _padding => switch (size) {
        AppButtonSize.standard => const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        AppButtonSize.compact => const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        AppButtonSize.small => const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      };

  TextStyle get _textStyle => switch (size) {
        AppButtonSize.standard => const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        AppButtonSize.compact => const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        AppButtonSize.small => const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      };

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = loading ? null : onPressed;

    Widget content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            width: _iconSize,
            height: _iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_getForegroundColor(context)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: _iconSize),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _textStyle,
          ),
        ),
        if (!loading && trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(trailingIcon, size: _iconSize),
        ],
      ],
    );

    Widget buttonWidget;

    switch (variant) {
      case AppButtonVariant.primary:
        buttonWidget = FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.38),
            disabledForegroundColor: Colors.white70,
            minimumSize: Size(expanded ? double.infinity : 0, _height),
            padding: _padding,
            shape: RoundedRectangleBorder(borderRadius: AppRadii.md),
          ),
          onPressed: effectiveOnPressed,
          child: content,
        );
        break;

      case AppButtonVariant.secondary:
        buttonWidget = FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: AppColors.primaryDark,
            disabledBackgroundColor: AppColors.borderSubtle,
            disabledForegroundColor: AppColors.textMuted,
            minimumSize: Size(expanded ? double.infinity : 0, _height),
            padding: _padding,
            shape: RoundedRectangleBorder(borderRadius: AppRadii.md),
          ),
          onPressed: effectiveOnPressed,
          child: content,
        );
        break;

      case AppButtonVariant.outlined:
        buttonWidget = OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.2),
            disabledForegroundColor: AppColors.textMuted,
            minimumSize: Size(expanded ? double.infinity : 0, _height),
            padding: _padding,
            shape: RoundedRectangleBorder(borderRadius: AppRadii.md),
          ),
          onPressed: effectiveOnPressed,
          child: content,
        );
        break;

      case AppButtonVariant.danger:
        buttonWidget = FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.error.withValues(alpha: 0.38),
            disabledForegroundColor: Colors.white70,
            minimumSize: Size(expanded ? double.infinity : 0, _height),
            padding: _padding,
            shape: RoundedRectangleBorder(borderRadius: AppRadii.md),
          ),
          onPressed: effectiveOnPressed,
          child: content,
        );
        break;

      case AppButtonVariant.ghost:
        buttonWidget = TextButton(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            disabledForegroundColor: AppColors.textMuted,
            minimumSize: Size(expanded ? double.infinity : 0, _height),
            padding: _padding,
            shape: RoundedRectangleBorder(borderRadius: AppRadii.md),
          ),
          onPressed: effectiveOnPressed,
          child: content,
        );
        break;
    }

    if (expanded) {
      return SizedBox(width: double.infinity, height: _height, child: buttonWidget);
    }
    return SizedBox(height: _height, child: buttonWidget);
  }

  Color _getForegroundColor(BuildContext context) {
    return switch (variant) {
      AppButtonVariant.primary => Colors.white,
      AppButtonVariant.secondary => AppColors.primaryDark,
      AppButtonVariant.outlined => AppColors.primary,
      AppButtonVariant.danger => Colors.white,
      AppButtonVariant.ghost => AppColors.textPrimary,
    };
  }
}

/// Backwards compatibility wrapper for PrimaryButton
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = true,
    this.minHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    return AppButton.primary(
      label: label,
      onPressed: onPressed,
      icon: icon,
      expanded: expanded,
    );
  }
}

/// Backwards compatibility wrapper for DangerButton
class DangerButton extends StatelessWidget {
  const DangerButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AppButton.danger(
      label: label,
      onPressed: onPressed,
      icon: icon ?? Icons.delete_outline,
      expanded: true,
    );
  }
}

