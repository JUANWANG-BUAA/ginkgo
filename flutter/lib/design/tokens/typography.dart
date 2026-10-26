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
