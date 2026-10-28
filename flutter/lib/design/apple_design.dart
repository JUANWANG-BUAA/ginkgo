import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/tokens/colors.dart';
import 'package:ginkgo_mirror/design/tokens/layout.dart';
import 'package:ginkgo_mirror/design/tokens/motion.dart';
import 'package:ginkgo_mirror/design/tokens/radii.dart';
import 'package:ginkgo_mirror/design/tokens/spacing.dart';
import 'package:ginkgo_mirror/design/tokens/typography.dart';

export 'package:ginkgo_mirror/design/tokens.dart';

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
  static const bodyCondensedSize = GinkgoTypography.bodyCondensedSize;
  static const calloutSize = GinkgoTypography.calloutSize;
  static const bodyCondensed = GinkgoTypography.bodyCondensed;
  static const callout = GinkgoTypography.callout;
  static const subheadline = GinkgoTypography.subheadline;
  static const footnote = GinkgoTypography.footnote;
  static const caption = GinkgoTypography.caption;
  static const caption2 = GinkgoTypography.caption2;
  // `title` used to alias largeTitle, so the scale jumped 34 → 26 with nothing
  // between. Keep `title` on title2 and expose the rest of the scale.
  static const largeTitle = GinkgoTypography.largeTitle;
  static const title = GinkgoTypography.title;
  static const title2 = GinkgoTypography.title2;
  static const headline = GinkgoTypography.headline;

  static Duration duration(BuildContext context, int milliseconds) =>
      GinkgoMotion.duration(context, milliseconds);
}
