import 'package:flutter/cupertino.dart';

import 'design/tokens/colors.dart';
import 'design/tokens/layout.dart';
import 'design/tokens/motion.dart';
import 'design/tokens/radii.dart';
import 'design/tokens/spacing.dart';
import 'design/tokens/typography.dart';

export 'design/tokens.dart';

/// Product values measured against the repository's iOS 27 reference capture.
/// These dimensions are Ginkgo calibration values, bridged to GinkgoTokens.
abstract final class AppleDesign {
  static const groupRadius = GinkgoRadii.group;
  static const rowHeight = GinkgoLayout.rowHeight;
  static const pageInset = GinkgoSpacing.pageInset;

  static bool desktop(BuildContext context) => GinkgoLayout.isDesktop(context);

  static double panelRadius(BuildContext context) =>
      GinkgoLayout.panelRadius(context);

  static const accent = GinkgoColors.accent;
  static const resourceBlue = GinkgoColors.resourceBlue;
  static const resourcePurple = GinkgoColors.resourcePurple;
  static const resourceTeal = GinkgoColors.resourceTeal;

  // State text must remain legible on grouped surfaces and tinted badges.
  // Colors complement a visible label/icon; they never determine business state.
  static const statusSuccess = GinkgoColors.statusSuccess;
  static const statusPending = GinkgoColors.statusPending;
  static const statusUncertain = GinkgoColors.statusUncertain;
  static const statusDanger = GinkgoColors.statusDanger;
  static const statusInactive = GinkgoColors.statusInactive;

  static const font = GinkgoTypography.font;
  static const fallback = GinkgoTypography.fallback;
  static const body = GinkgoTypography.body;
  static const title = GinkgoTypography.largeTitle;

  static Duration duration(BuildContext context, int milliseconds) =>
      GinkgoMotion.duration(context, milliseconds);
}
