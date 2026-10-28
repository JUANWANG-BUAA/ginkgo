import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/tokens.dart';

/// A rounded tinted base for a single glyph. The glyph follows text scaling
/// within the fixed tile, with padding retained even at accessibility sizes.
class GinkgoIconTile extends StatelessWidget {
  const GinkgoIconTile({
    super.key,
    required this.icon,
    this.size = 44,
    this.iconSize,
    this.selected = false,
    this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final double size;
  final double? iconSize;
  final bool selected;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final accent = CupertinoDynamicColor.resolve(
      color ?? CupertinoTheme.of(context).primaryColor,
      context,
    );
    final alpha = dark ? (selected ? 0.28 : 0.16) : (selected ? 0.16 : 0.10);
    final baseIconSize = (iconSize ?? size / 2).clamp(0.0, size * 0.75);
    final scaledIconSize = MediaQuery.textScalerOf(context)
        .scale(baseIconSize)
        .clamp(baseIconSize, size * 0.75);
    final tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(GinkgoRadii.panel),
      ),
      child: Center(
        child: Icon(
          icon,
          size: scaledIconSize,
          color: accent,
          // The size above already incorporates the system text scaler.
          applyTextScaling: false,
        ),
      ),
    );
    return semanticLabel == null
        ? tile
        : Semantics(label: semanticLabel, child: tile);
  }
}

/// A compact tinted label. The text always carries the meaning; color is only
/// reinforcement, so the badge stays readable at large type and in dark mode.
class GinkgoBadge extends StatelessWidget {
  const GinkgoBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final accent = CupertinoDynamicColor.resolve(
      color ?? CupertinoTheme.of(context).primaryColor,
      context,
    );
    return Container(
      padding: GinkgoSpacing.badgeInsets(
        compact: compact,
        largeText: MediaQuery.textScalerOf(context).scale(1) > 1.3,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: dark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(GinkgoRadii.compact),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: MediaQuery.textScalerOf(context).scale(12).clamp(12, 20),
              color: accent,
              applyTextScaling: false,
            ),
            const SizedBox(width: GinkgoSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              // A status qualifier must not disappear at accessibility sizes.
              softWrap: true,
              style: TextStyle(
                fontSize: compact
                    ? GinkgoTypography.caption2.fontSize
                    : GinkgoTypography.caption.fontSize,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
