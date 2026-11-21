import 'package:flutter/material.dart';

/// Standard sizing and layout dimensions for Darvi Billing.
class AppDimensions {
  // Standard component heights
  static const double buttonHeight = 46.0;
  static const double buttonHeightCompact = 38.0;
  static const double buttonHeightSm = 32.0;

  static const double inputHeight = 48.0;
  static const double inputHeightCompact = 40.0;

  static const double filterHeight = 38.0;
  static const double searchBarHeight = 44.0;

  static const double headerHeight = 60.0;
  static const double topBarHeight = 56.0;

  static const double listRowHeight = 68.0;
  static const double listRowHeightCompact = 52.0;

  // Icon sizing
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 32.0;

  // Card padding
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets cardPaddingCompact = EdgeInsets.all(12.0);

  // Responsive Breakpoints
  static const double breakpointMobile = 650.0;
  static const double breakpointTablet = 1024.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < breakpointMobile;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= breakpointMobile && width < breakpointTablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= breakpointTablet;
}

