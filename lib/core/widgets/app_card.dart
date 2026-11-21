import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_spacing.dart';

enum AppCardVariant {
  standard,
  bordered,
  compact,
}

/// Unified card container for Darvi Billing & ERP (inspired by Kite UI).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.headerTrailing,
    this.padding,
    this.variant = AppCardVariant.standard,
    this.onTap,
  });

  const AppCard.bordered({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.headerTrailing,
    this.padding,
    this.onTap,
  }) : variant = AppCardVariant.bordered;

  const AppCard.compact({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.headerTrailing,
    this.padding,
    this.onTap,
  }) : variant = AppCardVariant.compact;

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? headerTrailing;
  final EdgeInsetsGeometry? padding;
  final AppCardVariant variant;
  final VoidCallback? onTap;

  EdgeInsetsGeometry get _effectivePadding =>
      padding ??
      switch (variant) {
        AppCardVariant.compact => AppDimensions.cardPaddingCompact,
        _ => AppDimensions.cardPadding,
      };

  @override
  Widget build(BuildContext context) {
    final border = switch (variant) {
      AppCardVariant.bordered => Border.all(color: AppColors.border, width: 1.2),
      _ => Border.all(color: AppColors.border, width: 1),
    };

    final boxShadow = switch (variant) {
      AppCardVariant.bordered => const <BoxShadow>[],
      _ => const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
    };

    Widget cardContent = Container(
      padding: _effectivePadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadii.lg,
        border: border,
        boxShadow: boxShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (headerTrailing != null) headerTrailing!,
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          child,
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppRadii.lg,
        child: cardContent,
      );
    }
    return cardContent;
  }
}

