import 'package:flutter/cupertino.dart';

import 'radii.dart';

/// Layout breakpoints and structural dimensions.
abstract final class GinkgoLayout {
  // Breakpoints
  static const double desktopBreakpoint = 760.0;
  static const double wideBreakpoint = 1200.0;

  // Sidebar & Navigation Dimensions
  static const double desktopSidebarWidth = 248.0;
  static const double mobileTabBarHeight = 50.0;

  // Content Dimensions & Max Bounds
  static const double rowHeight = 52.0;
  static const double headerIconSize = 44.0;
  static const double contentMaxWidth = 900.0;
  static const double todayContentMaxWidth = 820.0;
  static const double formMaxWidth = 420.0;

  // Responsive Helpers
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopBreakpoint;

  static double panelRadius(BuildContext context) =>
      isDesktop(context) ? GinkgoRadii.panel : GinkgoRadii.group;
}
