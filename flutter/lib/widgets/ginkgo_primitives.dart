import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';
import 'package:ginkgo_mirror/widgets/press_feedback.dart';

/// Shared visual surface for standalone cards and grouped panels.
class GinkgoCard extends StatelessWidget {
  const GinkgoCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius,
    this.accent,
    this.tinted = false,
    this.emphasized = false,
    this.elevated = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? radius;
  final Color? accent;
  final bool tinted;
  final bool emphasized;
  final bool elevated;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedRadius = radius ?? GinkgoSurfaceTokens.cardRadius(context);
    final resolvedAccent = accent == null
        ? null
        : CupertinoDynamicColor.resolve(accent!, context);
    Widget body = padding == null
        ? child
        : Padding(padding: padding!, child: child);
    body = DecoratedBox(
      decoration: GinkgoSurfaceTokens.cardDecoration(
        context,
        radius: resolvedRadius,
        accent: resolvedAccent,
        tinted: tinted,
        emphasized: emphasized,
        elevated: elevated,
      ),
      child: body,
    );
    body = ClipRSuperellipse(
      borderRadius: BorderRadius.circular(resolvedRadius),
      child: body,
    );
    if (onTap != null) {
      body = PressFeedback(
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: GinkgoButtonTokens.minTarget,
          onPressed: onTap,
          child: body,
        ),
      );
    }
    return margin == null ? body : Padding(padding: margin!, child: body);
  }
}

/// Visual prominence levels for [GinkgoActionButton].
enum GinkgoButtonVariant { primary, tinted, subtle }

/// Token-driven action button and selectable filter chip with a guaranteed
/// 48dp hit target, consistent icon-label rhythm, and unified radius.
class GinkgoActionButton extends StatelessWidget {
  const GinkgoActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = GinkgoButtonVariant.tinted,
    this.tint,
    this.selected = false,
    this.compact = true,
    this.pill = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GinkgoButtonVariant variant;
  final Color? tint;
  final bool selected;
  final bool compact;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final resolvedTint = CupertinoDynamicColor.resolve(
      tint ?? CupertinoTheme.of(context).primaryColor,
      context,
    );
    final labelColor = switch (variant) {
      GinkgoButtonVariant.primary => CupertinoDynamicColor.resolve(
        CupertinoTheme.of(context).primaryContrastingColor,
        context,
      ),
      GinkgoButtonVariant.tinted => resolvedTint,
      GinkgoButtonVariant.subtle =>
        selected
            ? resolvedTint
            : CupertinoColors.secondaryLabel.resolveFrom(context),
    };
    final fillColor = switch (variant) {
      GinkgoButtonVariant.primary => resolvedTint,
      GinkgoButtonVariant.tinted => resolvedTint.withValues(
        alpha: GinkgoButtonTokens.tintedFillAlpha(dark, selected: selected),
      ),
      GinkgoButtonVariant.subtle =>
        (selected
                ? resolvedTint
                : CupertinoColors.label.resolveFrom(context))
            .withValues(
              alpha: GinkgoButtonTokens.subtleFillAlpha(
                dark,
                selected: selected,
              ),
            ),
    };
    final borderColor = switch (variant) {
      GinkgoButtonVariant.primary => null,
      GinkgoButtonVariant.tinted => resolvedTint.withValues(
        alpha: selected ? (dark ? 0.45 : 0.30) : (dark ? 0.24 : 0.14),
      ),
      GinkgoButtonVariant.subtle =>
        selected
            ? resolvedTint.withValues(alpha: dark ? 0.36 : 0.24)
            : GinkgoSurfaceTokens.borderColor(context),
    };
    final radius = pill
        ? GinkgoButtonTokens.chipRadius
        : GinkgoButtonTokens.actionRadius;

    return PressFeedback(
      enabled: onPressed != null,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: GinkgoButtonTokens.minTarget,
        onPressed: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(radius),
            border: borderColor == null
                ? null
                : Border.all(
                    color: borderColor,
                    width: GinkgoSurfaceTokens.borderWidth,
                  ),
          ),
          child: Padding(
            padding: compact
                ? GinkgoButtonTokens.paddingCompact
                : GinkgoButtonTokens.paddingStandard,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: GinkgoIconTokens.glyphSm,
                    color: labelColor,
                  ),
                  const SizedBox(width: GinkgoSpacing.small),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (compact
                                ? GinkgoTypography.footnote
                                : GinkgoTypography.callout)
                            .copyWith(
                              fontWeight: FontWeight.w600,
                              color: labelColor,
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Layered progressive-disclosure row for actionable school items (assignments,
/// deadlines, upcoming classes). Separates urgency signal, primary title, and
/// supporting metadata into three clear visual tiers.
class GinkgoProgressiveRow extends StatelessWidget {
  const GinkgoProgressiveRow({
    super.key,
    required this.title,
    this.subtitle,
    this.meta,
    this.badgeLabel,
    this.badgeIcon,
    this.extraBadges = const [],
    this.accent,
    this.emphasized = false,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? meta;
  final String? badgeLabel;
  final IconData? badgeIcon;
  final List<Widget> extraBadges;
  final Color? accent;
  final bool emphasized;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedAccent = CupertinoDynamicColor.resolve(
      accent ?? CupertinoTheme.of(context).primaryColor,
      context,
    );
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final hasHeaderRow =
        badgeLabel != null || meta != null || extraBadges.isNotEmpty;

    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: GinkgoLayout.rowHeight),
      child: Padding(
        padding: emphasized
            ? GinkgoSpacing.edgeInsetsFocusRow
            : GinkgoSpacing.edgeInsetsListTile,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasHeaderRow) ...[
                    Wrap(
                      spacing: GinkgoSpacing.sm,
                      runSpacing: GinkgoSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (badgeLabel != null)
                          GinkgoBadge(
                            label: badgeLabel!,
                            icon: badgeIcon ?? CupertinoIcons.clock_fill,
                            color: resolvedAccent,
                            compact: true,
                          ),
                        ...extraBadges,
                        if (meta != null)
                          Text(
                            meta!,
                            style: GinkgoTypography.caption.copyWith(
                              color: secondary,
                              fontWeight: FontWeight.w500,
                              fontFeatures: GinkgoTypography.tabularDigits,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: GinkgoSpacing.small),
                  ],
                  Text(
                    title,
                    maxLines: MediaQuery.textScalerOf(context).scale(17) > 24
                        ? null
                        : 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (emphasized
                                ? GinkgoTypography.headline
                                : GinkgoTypography.bodyCondensed)
                            .copyWith(
                              fontWeight: FontWeight.w600,
                              color: labelColor,
                              height: 1.3,
                            ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: GinkgoSpacing.xs),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GinkgoTypography.footnote.copyWith(
                        color: secondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: GinkgoSpacing.sm),
              const ExcludeSemantics(child: CupertinoListTileChevron()),
            ],
          ],
        ),
      ),
    );

    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        enabled: onTap == null ? null : true,
        child: onTap == null
            ? body
            : PressFeedback(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: GinkgoButtonTokens.minTarget,
                  onPressed: onTap,
                  child: body,
                ),
              ),
      ),
    );
  }
}
