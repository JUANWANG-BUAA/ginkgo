import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/tokens/colors.dart';
import 'package:ginkgo_mirror/design/tokens/elevation.dart';
import 'package:ginkgo_mirror/design/tokens/layout.dart';
import 'package:ginkgo_mirror/design/tokens/radii.dart';
import 'package:ginkgo_mirror/design/tokens/spacing.dart';

/// Semantic surface, border, and depth tokens shared by every card and grouped
/// container across the app. Keeping decoration factory logic here ensures
/// Today, Homework, Library, Schedule, Learning, and Settings read as one app.
abstract final class GinkgoSurfaceTokens {
  static const double borderWidth = GinkgoSpacing.hairline;
  static const double accentStripeWidth = 3.5;
  static const double accentStripeRadius = 2.0;
  static const double timelineWidth = 64.0;

  static double cardRadius(BuildContext context) =>
      GinkgoLayout.panelRadius(context);

  static const double innerCardRadius = GinkgoRadii.panel;

  static Color dividerColor(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return CupertinoColors.separator
        .resolveFrom(context)
        .withValues(alpha: dark ? 0.28 : 0.16);
  }

  static Color borderColor(
    BuildContext context, {
    Color? accent,
    bool emphasized = false,
  }) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    if (accent != null) {
      return accent.withValues(
        alpha: emphasized ? (dark ? 0.36 : 0.24) : (dark ? 0.26 : 0.16),
      );
    }
    return CupertinoColors.separator
        .resolveFrom(context)
        .withValues(alpha: dark ? 0.34 : 0.22);
  }

  static Color surfaceFill(
    BuildContext context, {
    Color? accent,
    bool tinted = false,
  }) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final base = GinkgoColors.secondaryGroupedBackground.resolveFrom(context);
    if (!tinted || accent == null) return base;
    return Color.alphaBlend(
      accent.withValues(alpha: dark ? 0.14 : 0.06),
      base,
    );
  }

  static List<BoxShadow>? cardShadow(
    BuildContext context, {
    Color? accent,
    bool elevated = true,
  }) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    if (dark || !elevated) return null;
    if (accent != null) {
      return [
        BoxShadow(
          color: accent.withValues(alpha: 0.07),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return GinkgoElevation.xs;
  }

  static BoxDecoration cardDecoration(
    BuildContext context, {
    double? radius,
    Color? accent,
    bool tinted = false,
    bool emphasized = false,
    bool elevated = true,
  }) => BoxDecoration(
    color: surfaceFill(context, accent: accent, tinted: tinted),
    borderRadius: BorderRadius.circular(radius ?? cardRadius(context)),
    border: Border.all(
      color: borderColor(context, accent: accent, emphasized: emphasized),
      width: borderWidth,
    ),
    boxShadow: cardShadow(context, accent: accent, elevated: elevated),
  );
}

/// Canonical icon container tiers so icons across headers, sections, list rows,
/// and hero cards follow one visual scale.
abstract final class GinkgoIconTokens {
  static const double sm = 26.0;
  static const double md = 36.0;
  static const double lg = 44.0;

  static const double glyphXs = 12.0;
  static const double glyphSm = 14.0;
  static const double glyphMd = 18.0;
  static const double glyphLg = 22.0;
  static const double chevron = 14.0;

  static double tileRadius(double size) {
    if (size <= 28) return GinkgoRadii.button;
    if (size <= 38) return GinkgoRadii.compact;
    return GinkgoRadii.panel;
  }
}

/// Unified pill / status badge tokens: capsule shape, calibrated tint wash,
/// and crisp hairline ring across light and dark themes.
abstract final class GinkgoBadgeTokens {
  static const double radius = GinkgoRadii.pill;

  static double fillAlpha(bool dark) => dark ? 0.22 : 0.11;
  static double borderAlpha(bool dark) => dark ? 0.30 : 0.18;
}

/// Unified action button & interactive chip tokens.
abstract final class GinkgoButtonTokens {
  static const Size minTarget = Size(48, 48);
  static const double chipRadius = GinkgoRadii.pill;
  static const double actionRadius = GinkgoRadii.compact;

  static const EdgeInsets paddingCompact = EdgeInsets.symmetric(
    horizontal: GinkgoSpacing.md,
    vertical: GinkgoSpacing.sm,
  );
  static const EdgeInsets paddingStandard = EdgeInsets.symmetric(
    horizontal: GinkgoSpacing.base,
    vertical: GinkgoSpacing.md,
  );

  static double tintedFillAlpha(bool dark, {bool selected = false}) => selected
      ? (dark ? 0.28 : 0.18)
      : (dark ? 0.18 : 0.09);

  static double subtleFillAlpha(bool dark, {bool selected = false}) => selected
      ? (dark ? 0.24 : 0.14)
      : (dark ? 0.14 : 0.06);
}
