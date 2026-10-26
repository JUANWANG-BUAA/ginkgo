import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';
import 'package:ginkgo_mirror/design/ginkgo_visuals.dart';

/// Phone pages keep the native collapsing title. Wide windows use the same
/// section / title / description hierarchy as Swift's AcademicPageHeader.
class ApplePageHeader extends StatelessWidget {
  const ApplePageHeader({
    super.key,
    required this.largeTitle,
    this.trailing,
    this.previousPageTitle,
    this.border,
    this.section,
    this.subtitle,
    this.icon,
  });
  final Widget largeTitle;
  final Widget? trailing;
  final String? previousPageTitle;
  final Border? border;

  /// Explicit desktop identity. Callers own the section, subtitle and icon;
  /// the header never infers them from the title.
  final String? section;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (!AppleDesign.desktop(context)) {
      return CupertinoSliverNavigationBar(
        largeTitle: largeTitle,
        previousPageTitle: previousPageTitle,
        border: border,
        trailing: trailing,
      );
    }
    final resolvedSection = section ?? 'Ginkgo';
    final resolvedSubtitle = subtitle;
    final resolvedIcon = icon;
    final canPop = Navigator.of(context).canPop();
    final accent = CupertinoTheme.of(context).primaryColor;
    return PinnedHeaderSliver(
      child: ColoredBox(
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        child: SafeArea(
          bottom: false,
          child: Padding(
            key: const Key('desktop-page-heading'),
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (canPop) ...[
                  CupertinoButton(
                    key: const Key('desktop-page-back'),
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(48, 48),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Semantics(
                      label: '返回上一页',
                      child: const Icon(CupertinoIcons.chevron_left, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (resolvedIcon != null) ...[
                  GinkgoIconTile(
                    icon: resolvedIcon,
                    size: 44,
                    iconSize: 22,
                    color: accent,
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resolvedSection,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Semantics(
                        header: true,
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                          child: largeTitle,
                        ),
                      ),
                      if (resolvedSubtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          resolvedSubtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel.resolveFrom(
                              context,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 16), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppleEmptyState extends StatelessWidget {
  const AppleEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.action,
    this.onAction,
    this.error = false,
    this.icon,
  });
  final String title, description;
  final String? action;
  final VoidCallback? onAction;
  final bool error;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
    child: Column(
      children: [
        Icon(
          icon ??
              (error
                  ? CupertinoIcons.exclamationmark_triangle
                  : CupertinoIcons.tray),
          size: 44,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        if (action != null)
          CupertinoButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

/// Modern inset groups use a continuous corner, a quiet content surface and
/// full row separators. Glass is reserved for navigation and transient menus.
class AppleSection extends StatelessWidget {
  const AppleSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.animateSize = true,
  });
  final List<Widget> children;
  final Widget? header, footer;
  final bool animateSize;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: AppleDesign.desktop(context) ? 20 : 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 10),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              child: header!,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppleDesign.pageInset,
          ),
          child: ClipRSuperellipse(
            borderRadius: BorderRadius.circular(
              AppleDesign.panelRadius(context),
            ),
            child: _AppleGroupResize(
              enabled: animateSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: CupertinoColors.secondarySystemGroupedBackground
                      .resolveFrom(context),
                  borderRadius: BorderRadius.circular(
                    AppleDesign.panelRadius(context),
                  ),
                  border: AppleDesign.desktop(context)
                      ? Border.all(
                          color: CupertinoColors.separator
                              .resolveFrom(context)
                              .withValues(alpha: 0.3),
                          width: 0.5,
                        )
                      : null,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      children[i],
                      if (i != children.length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            height: 0.5,
                            color: CupertinoColors.separator
                                .resolveFrom(context)
                                .withValues(alpha: 0.16),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              child: footer!,
            ),
          ),
      ],
    ),
  );
}

class AppleListTile extends StatelessWidget {
  const AppleListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.additionalInfo,
    this.leading,
    this.trailing,
    this.onTap,
    this.minimumHeight = AppleDesign.rowHeight,
    this.leadingSize = 30,
  });
  final Widget title;
  final Widget? subtitle, additionalInfo, leading, trailing;
  final VoidCallback? onTap;
  final double minimumHeight;
  final double leadingSize;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: minimumHeight),
    child: CupertinoListTile(
      title: _wrapText(title),
      subtitle: subtitle == null ? null : _wrapText(subtitle!),
      additionalInfo: additionalInfo,
      leading: leading,
      trailing: trailing,
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: AppPreferencesScope.of(context).compactLists ? 6 : 10,
      ),
      leadingToTitle: 12,
      leadingSize: leadingSize,
    ),
  );
  Widget _wrapText(Widget child) => Builder(
    builder: (context) => DefaultTextStyle(
      style: DefaultTextStyle.of(context).style,
      softWrap: true,
      overflow: TextOverflow.visible,
      child: child,
    ),
  );
}

class _AppleGroupResize extends StatelessWidget {
  const _AppleGroupResize({required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    if (!enabled || MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}
