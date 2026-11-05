import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/tokens.dart';

/// Swift-style page route with sophisticated transition
class GinkgoPageRoute<T> extends CupertinoPageRoute<T> {
  GinkgoPageRoute({
    required super.builder,
    super.title,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  });

  @override
  Duration get transitionDuration => GinkgoMotion.normal;
}

/// Smooth bottom sheet with polished appearance
class GinkgoBottomSheet extends StatelessWidget {
  const GinkgoBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.onClose,
    this.backgroundColor,
    this.isDismissible = true,
    this.enableDrag = true,
  });

  final Widget child;
  final String? title;
  final VoidCallback? onClose;
  final Color? backgroundColor;
  final bool isDismissible;
  final bool enableDrag;

  @override
  Widget build(BuildContext context) {
    return CupertinoPopupSurface(
      isSurfacePainted: true,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (enableDrag)
              Padding(
                padding: EdgeInsets.only(top: GinkgoSpacing.md),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: GinkgoColors.tertiaryLabel,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            if (title != null) ...[
              Padding(
                padding: EdgeInsets.all(GinkgoSpacing.base),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title!, style: GinkgoTypography.headline),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: onClose ?? () => Navigator.pop(context),
                      child: const Icon(CupertinoIcons.xmark_circle_fill),
                    ),
                  ],
                ),
              ),
              Container(color: GinkgoColors.separator, height: 1),
            ],
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

/// Show Ginkgo-styled bottom sheet
Future<T?> showGinkgoBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (context) => GinkgoBottomSheet(
      title: title,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor,
      child: builder(context),
    ),
  );
}

/// Alert dialog with Swift styling
class GinkgoAlertDialog extends StatelessWidget {
  const GinkgoAlertDialog({
    super.key,
    required this.title,
    this.message,
    required this.actions,
    this.defaultActionIndex,
    this.cancelActionIndex,
  });

  final String title;
  final String? message;
  final List<GinkgoAlertAction> actions;
  final int? defaultActionIndex;
  final int? cancelActionIndex;

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(title, style: GinkgoTypography.headline),
      content: message != null
          ? Padding(
              padding: EdgeInsets.only(top: GinkgoSpacing.md),
              child: Text(message!, style: GinkgoTypography.body),
            )
          : null,
      actions: actions.asMap().entries.map((entry) {
        final action = entry.value;
        final index = entry.key;
        final isDefault = index == defaultActionIndex;

        return CupertinoDialogAction(
          isDefaultAction: isDefault,
          isDestructiveAction: action.isDestructive,
          onPressed: () {
            Navigator.pop(context, index);
            action.onPressed?.call();
          },
          child: Text(action.label),
        );
      }).toList(),
    );
  }
}

class GinkgoAlertAction {
  GinkgoAlertAction({
    required this.label,
    this.onPressed,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;
}

/// Loading indicator with Ginkgo styling
class GinkgoLoadingIndicator extends StatelessWidget {
  const GinkgoLoadingIndicator({super.key, this.message, this.size = 50.0});

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CupertinoActivityIndicator(radius: 15),
          ),
          if (message != null) ...[
            SizedBox(height: GinkgoSpacing.base),
            Text(
              message!,
              style: GinkgoTypography.callout,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty state view with Ginkgo styling
class GinkgoEmptyState extends StatelessWidget {
  const GinkgoEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String? message;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: GinkgoColors.tertiaryLabel),
          SizedBox(height: GinkgoSpacing.xl),
          Text(
            title,
            style: GinkgoTypography.headline,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            SizedBox(height: GinkgoSpacing.sm),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: GinkgoSpacing.base),
              child: Text(
                message!,
                style: GinkgoTypography.callout.copyWith(
                  color: GinkgoColors.secondaryLabel,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (action != null && actionLabel != null) ...[
            SizedBox(height: GinkgoSpacing.xl),
            CupertinoButton.filled(
              onPressed: action,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
