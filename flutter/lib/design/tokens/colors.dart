import 'package:flutter/cupertino.dart';

/// Semantic colors for Ginkgo across light and dark brightness modes.
/// Aligned with Apple HIG (iOS / macOS) dynamic system materials.
abstract final class GinkgoColors {
  // Brand & Accent
  static const accent = CupertinoDynamicColor.withBrightness(
    color: Color(0xff189840),
    darkColor: Color(0xff47bd6b),
  );

  static const accentSubtle = CupertinoDynamicColor.withBrightness(
    color: Color(0x1a189840),
    darkColor: Color(0x2447bd6b),
  );

  // Surfaces & Backgrounds
  static const secondaryGroupedBackground =
      CupertinoColors.secondarySystemGroupedBackground;
  static const tertiarySystemFill = CupertinoColors.tertiarySystemFill;

  // Separators & Borders
  static const separator = CupertinoColors.separator;

  // Text & Content
  static const label = CupertinoColors.label;
  static const secondaryLabel = CupertinoColors.secondaryLabel;
  static const tertiaryLabel = CupertinoColors.tertiaryLabel;

  // Status Colors (Success, Pending, Danger, Uncertain, Inactive)
  // Contrast calibrated to ensure WCAG AA readability on grouped surfaces.
  static const statusSuccess = CupertinoDynamicColor.withBrightness(
    color: Color(0xff125a2d),
    darkColor: Color(0xff72d991),
  );

  static const statusPending = CupertinoDynamicColor.withBrightness(
    color: Color(0xff713900),
    darkColor: Color(0xffffbd70),
  );

  static const statusDanger = CupertinoDynamicColor.withBrightness(
    color: Color(0xff982020),
    darkColor: Color(0xffffaaa4),
  );

  static const statusUncertain = CupertinoDynamicColor.withBrightness(
    color: Color(0xff4a4f58),
    darkColor: Color(0xffc4c8d0),
  );

  static const statusInactive = statusUncertain;

  // Resource Category Tints
  static const resourceBlue = CupertinoDynamicColor.withBrightness(
    color: Color(0xff0066cc),
    darkColor: Color(0xff69adff),
  );

  static const resourcePurple = CupertinoDynamicColor.withBrightness(
    color: Color(0xff7446b8),
    darkColor: Color(0xffcfadff),
  );

  static const resourceTeal = CupertinoDynamicColor.withBrightness(
    color: Color(0xff08777c),
    darkColor: Color(0xff66d9df),
  );

  static const connectionOnline = Color(0xff34c759);
  static const connectionOffline = CupertinoColors.systemOrange;
}
