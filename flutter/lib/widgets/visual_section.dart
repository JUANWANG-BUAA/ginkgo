import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

/// A quiet inset rule for rows nested inside a reveal animation.
class TodayVisualDivider extends StatelessWidget {
  const TodayVisualDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: GinkgoSpacing.edgeInsetsPage,
    child: ColoredBox(
      color: CupertinoColors.separator
          .resolveFrom(context)
          .withValues(alpha: 0.16),
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
    this.badge,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final String title;
  final IconData? icon;
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
            minimumSize: const Size(48, 48),
            onPressed: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel!,
                  style: TextStyle(
                    fontSize: GinkgoTypography.footnote.fontSize,
                    fontWeight: FontWeight.w500,
                    color: accent,
                  ),
                ),
                const SizedBox(width: GinkgoSpacing.opticalIconInset),
                Icon(CupertinoIcons.chevron_forward, size: 13, color: accent),
              ],
            ),
          )
        : null;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: GinkgoSpacing.sm,
      runSpacing: GinkgoSpacing.xs,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: GinkgoSpacing.small,
          children: [
            if (icon != null)
              Icon(
                icon,
                size: 16,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            Text(
              title,
              style: TextStyle(
                fontSize: GinkgoTypography.subheadline.fontSize,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label.resolveFrom(context),
                letterSpacing: -0.2,
              ),
            ),
            if (badge != null)
              Text(
                badge!,
                style: TextStyle(
                  fontSize: GinkgoTypography.footnote.fontSize,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
          ],
        ),
        ?action,
      ],
    );
  }
}
