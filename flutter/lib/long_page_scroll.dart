import 'package:flutter/cupertino.dart';

import 'apple_design.dart';

/// Shared long-page navigation without rebuilding the list on each scroll tick.
/// A separate controller is required so nested horizontal grids stay independent.
class LongPageScroll extends StatelessWidget {
  const LongPageScroll({
    super.key,
    required this.controller,
    required this.child,
  });
  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      CupertinoScrollbar(
        controller: controller,
        thumbVisibility: AppleDesign.desktop(context),
        thickness: AppleDesign.desktop(context) ? 6 : 3,
        thicknessWhileDragging: 10,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.vertical &&
            notification.depth == 0,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: child,
        ),
      ),
      Positioned(
        right: 20,
        bottom: MediaQuery.paddingOf(context).bottom + 80,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (!controller.hasClients ||
                !controller.position.hasContentDimensions ||
                controller.offset <
                    controller.position.viewportDimension * 1.5) {
              return const SizedBox.shrink();
            }
            return DecoratedBox(
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemGroupedBackground
                    .resolveFrom(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: CupertinoColors.separator.resolveFrom(context),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: CupertinoButton(
                key: const Key('page-back-to-top'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  if (MediaQuery.disableAnimationsOf(context) ||
                      controller.offset >
                          controller.position.viewportDimension * 4) {
                    controller.jumpTo(0);
                  } else {
                    controller.animateTo(
                      0,
                      duration: AppleDesign.duration(context, 240),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.arrow_up_to_line, size: 17),
                    SizedBox(width: 6),
                    Text('顶部', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}
