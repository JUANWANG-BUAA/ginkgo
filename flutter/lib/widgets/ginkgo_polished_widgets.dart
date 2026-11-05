import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/tokens.dart';
import 'package:ginkgo_mirror/widgets/press_feedback.dart';

/// A system button with shared typography, touch feedback and busy semantics.
class GinkgoButton extends StatelessWidget {
  const GinkgoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = GinkgoButtonVariant.primary,
    this.size = GinkgoButtonSize.medium,
    this.isLoading = false,
    this.isEnabled = true,
    this.icon,
    this.trailing,
  });
  final String label;
  final VoidCallback onPressed;
  final GinkgoButtonVariant variant;
  final GinkgoButtonSize size;
  final bool isLoading, isEnabled;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final enabled = isEnabled && !isLoading;
    final theme = CupertinoTheme.of(context);
    final foreground = variant == GinkgoButtonVariant.primary
        ? theme.primaryContrastingColor
        : theme.primaryColor;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading) ...[
          CupertinoActivityIndicator(color: foreground),
          const SizedBox(width: GinkgoSpacing.sm),
        ] else if (icon != null) ...[
          Icon(icon, color: foreground),
          const SizedBox(width: GinkgoSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style:
                (size == GinkgoButtonSize.large
                        ? GinkgoTypography.headline
                        : GinkgoTypography.body)
                    .copyWith(color: foreground),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: GinkgoSpacing.sm),
          trailing!,
        ],
      ],
    );
    final padding = size == GinkgoButtonSize.large
        ? GinkgoSpacing.edgeInsetsCard
        : GinkgoSpacing.edgeInsetsListTile;
    return Semantics(
      button: true,
      enabled: enabled,
      liveRegion: isLoading,
      value: isLoading ? '处理中' : null,
      child: PressFeedback(
        enabled: enabled,
        child: CupertinoButton(
          padding: padding,
          minimumSize: const Size(48, 48),
          color: switch (variant) {
            GinkgoButtonVariant.primary => theme.primaryColor,
            GinkgoButtonVariant.secondary =>
              CupertinoColors.tertiarySystemFill.resolveFrom(context),
            GinkgoButtonVariant.ghost => null,
          },
          onPressed: enabled ? onPressed : null,
          child: content,
        ),
      ),
    );
  }
}

enum GinkgoButtonVariant { primary, secondary, ghost }

enum GinkgoButtonSize { small, medium, large }

/// Swift-like card with polished appearance
class GinkgoCard extends StatelessWidget {
  const GinkgoCard({
    super.key,
    required this.child,
    this.elevation,
    this.backgroundColor,
    this.borderRadius = GinkgoRadii.panel,
    this.padding = GinkgoSpacing.edgeInsetsCard,
  });

  final Widget child;
  final List<BoxShadow>? elevation;
  final Color? backgroundColor;
  final double borderRadius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(
          backgroundColor ?? GinkgoColors.secondaryGroupedBackground,
          context,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: elevation,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Smooth divider matching iOS aesthetic
class GinkgoDivider extends StatelessWidget {
  const GinkgoDivider({
    super.key,
    this.height = 1,
    this.color = GinkgoColors.separator,
  });

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: CupertinoDynamicColor.resolve(color, context),
    );
  }
}
