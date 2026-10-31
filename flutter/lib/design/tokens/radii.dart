import 'package:flutter/cupertino.dart';

/// Corner radius tokens using continuous Apple superellipse curves.
abstract final class GinkgoRadii {
  static const double badge = 7.0;
  static const double button = 8.0;
  static const double compact = 10.0;
  static const double panel = 12.0;
  static const double dialog = 18.0;

  /// Inset list groups stay softly rounded without making each section read as
  /// a floating card. The native iOS academic surfaces use a 12pt radius.
  static const double group = 16.0;

  static final borderRadiusDialog = BorderRadius.circular(dialog);
}
