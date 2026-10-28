import 'package:flutter/cupertino.dart';

/// 4pt / 8pt spatial layout scale matching Apple Human Interface Guidelines.
abstract final class GinkgoSpacing {
  static const double md = 12.0;
  static const double base = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  // Insets
  static const pageInset = 16.0;
  static const desktopPageInset = 24.0;

  static const edgeInsetsPage = EdgeInsets.symmetric(horizontal: pageInset);
  static const edgeInsetsDesktopPage = EdgeInsets.fromLTRB(
    desktopPageInset,
    22,
    desktopPageInset,
    6,
  );
  static const edgeInsetsCard = EdgeInsets.all(base);
  static const edgeInsetsListTile = EdgeInsets.symmetric(
    horizontal: base,
    vertical: 10,
  );
  static const edgeInsetsBadge = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 5,
  );
  static const edgeInsetsFact = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 13,
  );

  static const double xs = 4.0;
  static const double compact = 5.0;
  static const double small = 6.0;
  static const double factLabelWidth = 124.0;
  static const double metricColumnWidth = 108.0;
  static const double metricGridSpacing = 18.0;

  static EdgeInsets badgeInsets({
    required bool compact,
    required bool largeText,
  }) => EdgeInsets.symmetric(
    horizontal: compact ? 6 : 8,
    vertical: largeText ? 4 : (compact ? 2 : 3),
  );
}
