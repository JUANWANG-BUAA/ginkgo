import 'package:flutter/cupertino.dart';

/// 4pt / 8pt spatial layout scale matching Apple Human Interface Guidelines.
abstract final class GinkgoSpacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double base = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

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
  static const edgeInsetsListTileCompact = EdgeInsets.symmetric(
    horizontal: base,
    vertical: 6,
  );
  static const edgeInsetsSidebarItem = EdgeInsets.symmetric(
    horizontal: 4,
    vertical: 2,
  );
  static const edgeInsetsSidebarItemInner = EdgeInsets.symmetric(
    horizontal: 11,
    vertical: 8,
  );
}
