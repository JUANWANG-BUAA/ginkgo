import 'package:flutter/cupertino.dart';

import 'apple_design.dart';

Color _accentForeground(Color accent) {
  Color foreground(Color background) => background.computeLuminance() > 0.179
      ? CupertinoColors.black
      : CupertinoColors.white;
  if (accent is CupertinoDynamicColor) {
    return CupertinoDynamicColor.withBrightness(
      color: foreground(accent.color),
      darkColor: foreground(accent.darkColor),
    );
  }
  return foreground(accent);
}

CupertinoThemeData ginkgoTheme([
  Brightness? brightness,
  Color accent = GinkgoColors.accent,
]) => CupertinoThemeData(
  primaryColor: accent,
  // Filled controls need a contrasting foreground for both palette variants.
  primaryContrastingColor: _accentForeground(accent),
  textTheme: CupertinoTextThemeData(
    textStyle: GinkgoTypography.body,
    navTitleTextStyle: const TextStyle(
      inherit: false,
      fontFamily: GinkgoTypography.font,
      fontFamilyFallback: GinkgoTypography.fallback,
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: GinkgoColors.label,
    ),
    navLargeTitleTextStyle: GinkgoTypography.largeTitle,
    actionTextStyle: TextStyle(
      inherit: false,
      fontFamily: GinkgoTypography.font,
      fontFamilyFallback: GinkgoTypography.fallback,
      fontSize: 17,
      letterSpacing: -0.25,
      color: accent,
    ),
    // The nav bar back button reads navActionTextStyle, not actionTextStyle;
    // leaving it unset falls back to system blue and breaks the accent.
    navActionTextStyle: TextStyle(
      inherit: false,
      fontFamily: GinkgoTypography.font,
      fontFamilyFallback: GinkgoTypography.fallback,
      fontSize: 17,
      color: accent,
    ),
    dateTimePickerTextStyle: const TextStyle(
      inherit: false,
      fontFamily: GinkgoTypography.font,
      fontFamilyFallback: GinkgoTypography.fallback,
      fontSize: 21,
      color: GinkgoColors.label,
    ),
  ),
  brightness: brightness,
);
