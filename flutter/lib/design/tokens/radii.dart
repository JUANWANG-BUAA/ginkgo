import 'package:flutter/cupertino.dart';

/// Corner radius tokens using continuous Apple superellipse curves.
abstract final class GinkgoRadii {
  static const double pill = 2.0;
  static const double badge = 7.0;
  static const double button = 8.0;
  static const double navigationItem = 10.0;
  static const double panel = 12.0;
  static const double dialog = 18.0;
  static const double group = 26.0;

  static final borderRadiusPill = BorderRadius.circular(pill);
  static final borderRadiusBadge = BorderRadius.circular(badge);
  static final borderRadiusButton = BorderRadius.circular(button);
  static final borderRadiusNavigationItem = BorderRadius.circular(
    navigationItem,
  );
  static final borderRadiusPanel = BorderRadius.circular(panel);
  static final borderRadiusDialog = BorderRadius.circular(dialog);
  static final borderRadiusGroup = BorderRadius.circular(group);
}
