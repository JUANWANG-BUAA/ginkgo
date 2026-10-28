import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/tokens/colors.dart';

/// Semantic typography scale matching Apple Human Interface Guidelines.
abstract final class GinkgoTypography {
  static const font = 'Ginkgo Sans';
  static const fallback = ['Ginkgo Han'];

  static const largeTitle = TextStyle(
    inherit: false,
    fontFamily: font,
    fontFamilyFallback: fallback,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    color: GinkgoColors.label,
  );

  static const title = TextStyle(
    inherit: false,
    fontFamily: font,
    fontFamilyFallback: fallback,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: GinkgoColors.label,
  );

  static const title2 = TextStyle(
    inherit: false,
    fontFamily: font,
    fontFamilyFallback: fallback,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: GinkgoColors.label,
  );

  static const headline = TextStyle(
    inherit: false,
    fontFamily: font,
    fontFamilyFallback: fallback,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: GinkgoColors.label,
  );

  static const body = TextStyle(
    inherit: false,
    fontFamily: font,
    fontFamilyFallback: fallback,
    fontSize: 17,
    letterSpacing: -0.25,
    color: GinkgoColors.label,
  );

  static const bodyCondensedSize = 16.0;
  static const calloutSize = 15.0;
  static const metricSize = 24.0;
  static const metricProminentSize = 32.0;

  /// Dense rows and sidebars. 16 and 15 are the two most used sizes in the
  /// app after body/footnote; leaving them out of the scale is what pushed
  /// pages to hard-code `fontSize: 16` / `fontSize: 15` instead.
  static const bodyCondensed = TextStyle(
    inherit: false,
    fontFamily: font,
    fontFamilyFallback: fallback,
    fontSize: bodyCondensedSize,
    letterSpacing: -0.2,
    color: GinkgoColors.label,
  );

  static const callout = TextStyle(
    inherit: false,
    fontFamily: font,
    fontFamilyFallback: fallback,
    fontSize: calloutSize,
    letterSpacing: -0.18,
    color: GinkgoColors.label,
  );

  static const subheadline = TextStyle(
    inherit: false,
    fontFamily: font,
    fontFamilyFallback: fallback,
    fontSize: 14,
    letterSpacing: -0.15,
    color: GinkgoColors.label,
  );

  static const footnote = TextStyle(
    inherit: false,
    fontFamily: font,
    fontFamilyFallback: fallback,
    fontSize: 13,
    letterSpacing: -0.08,
    color: GinkgoColors.secondaryLabel,
  );

  static const caption = TextStyle(
    inherit: false,
    fontFamily: font,
    fontFamilyFallback: fallback,
    fontSize: 12,
    letterSpacing: 0.0,
    color: GinkgoColors.secondaryLabel,
  );

  static const caption2 = TextStyle(
    inherit: false,
    fontFamily: font,
    fontFamilyFallback: fallback,
    fontSize: 11,
    letterSpacing: 0.06,
    color: GinkgoColors.tertiaryLabel,
  );

  static const tabularDigits = [FontFeature.tabularFigures()];
}
