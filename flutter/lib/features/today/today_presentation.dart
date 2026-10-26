import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/design/ginkgo_visuals.dart';

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
      child: const SizedBox(height: 0.5, width: double.infinity),
    ),
  );
}

/// Today-only typography and spacing; the shared section keeps its behavior.
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
    padding: EdgeInsets.only(top: AppleDesign.desktop(context) ? 4 : 0),
    child: AppleSection(
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
    this.onAction,
  });

  final String title;
  final IconData? icon;
  final String? badge;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoTheme.of(context).primaryColor;

    final action = (actionLabel != null && onAction != null)
        ? CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(36, 28),
            onPressed: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 13,
                  color: accent,
                ),
              ],
            ),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              if (icon != null) Icon(icon, size: 16, color: accent),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label.resolveFrom(context),
                  letterSpacing: -0.2,
                ),
              ),
              if (badge != null) GinkgoBadge(label: badge!, compact: true),
            ],
          ),
          ?action,
        ],
      ),
    );
  }
}
