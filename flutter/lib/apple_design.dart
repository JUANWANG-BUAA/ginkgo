import 'package:flutter/cupertino.dart';

/// Product values measured against the repository's iOS 27 reference capture.
/// These dimensions are Ginkgo calibration values, not universal HIG constants.
abstract final class AppleDesign {
  static const groupRadius = 26.0;
  static const rowHeight = 52.0;
  static const pageInset = 16.0;
  static const accent = CupertinoDynamicColor.withBrightness(
    color: Color(0xff189840),
    darkColor: Color(0xff47bd6b),
  );
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
  static const font = 'Ginkgo Sans';
  static const fallback = ['Ginkgo Han'];
  static const body = TextStyle(
    inherit: false,
    fontFamily: font,
    fontFamilyFallback: fallback,
    fontSize: 17,
    letterSpacing: -0.25,
    color: CupertinoColors.label,
  );
  static const title = TextStyle(
    inherit: false,
    fontFamily: font,
    fontFamilyFallback: fallback,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    color: CupertinoColors.label,
  );
  static Duration duration(BuildContext context, int milliseconds) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);
}
