import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';

/// A quiet inset rule for rows nested inside a reveal animation.
class TodayVisualDivider extends StatelessWidget {
  const TodayVisualDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: GinkgoSpacing.edgeInsetsPage,
    child: ColoredBox(
      color: GinkgoSurfaceTokens.dividerColor(context),
      child: const SizedBox(
        height: GinkgoSpacing.hairline,
        width: double.infinity,
      ),
    ),
  );
}

/// Shared structured section wrapper with secondary header and muted footer.
class TodayVisualSection extends StatelessWidget {
  const TodayVisualSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
  });

  final List<Widget> children;
  final Widget? header, footer;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      top: AppleDesign.desktop(context) ? GinkgoSpacing.xs : 0,
    ),
    child: AppleSection(
      animateSize: false,
      header: header == null
          ? null
          : DefaultTextStyle.merge(
              style: GinkgoTypography.footnote.copyWith(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontWeight: FontWeight.w500,
              ),
              child: header!,
            ),
      footer: footer == null
          ? null
          : DefaultTextStyle.merge(
              style: TextStyle(
                color: AppleDesign.statusInactive.resolveFrom(context),
              ),
              child: footer!,
            ),
      children: children,
    ),
  );
}

/// A structured section header with theme icon, bold title, count capsule badge,
/// and trailing action affordance.
class TodaySectionHeader extends StatelessWidget {
  const TodaySectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.badge,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final String title;
  final IconData? icon;
  final Color? iconColor;
  final String? badge;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoTheme.of(context).primaryColor;

    final action = actionLabel != null
        ? CupertinoButton(
            key: actionKey,
            padding: EdgeInsets.zero,
            minimumSize: GinkgoButtonTokens.minTarget,
            onPressed: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel!,
                  style: GinkgoTypography.footnote.copyWith(
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
                const SizedBox(width: GinkgoSpacing.opticalIconInset),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: GinkgoIconTokens.chevron,
                  color: accent,
                ),
              ],
            ),
          )
        : null;

    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: GinkgoSpacing.sm,
        runSpacing: GinkgoSpacing.xs,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: GinkgoSpacing.sm,
            children: [
              if (icon != null)
                GinkgoIconTile(
                  icon: icon!,
                  size: GinkgoIconTokens.sm,
                  iconSize: GinkgoIconTokens.glyphSm,
                  color:
                      iconColor ??
                      CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              Text(
                title,
                style: GinkgoTypography.callout.copyWith(
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
              if (badge != null)
                Text(
                  badge!,
                  style: GinkgoTypography.footnote.copyWith(
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
            ],
          ),
          ?action,
        ],
      ),
    );
  }
}
