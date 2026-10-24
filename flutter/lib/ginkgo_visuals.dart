import 'package:flutter/cupertino.dart';

/// A rounded tinted base for a single glyph. Keeps the glyph size stable while
/// the tile communicates selection through tint strength, never through motion.
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
    final accent = color ?? CupertinoTheme.of(context).primaryColor;
    final alpha = dark ? (selected ? 0.28 : 0.16) : (selected ? 0.16 : 0.10);
    final tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(icon, size: iconSize ?? size / 2, color: accent),
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
    final accent = color ?? CupertinoTheme.of(context).primaryColor;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: dark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: accent),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
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
