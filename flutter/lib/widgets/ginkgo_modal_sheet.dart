import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';

/// Shared modal bottom sheet with a centered grabber handle and live finger-
/// following swipe-to-dismiss gesture (distance or downward fling velocity).
Future<T?> showGinkgoModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool showGrabber = true,
  bool barrierDismissible = true,
}) => showCupertinoModalPopup<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  builder: (sheetContext) => _GinkgoSwipeDismissSheet(
    showGrabber: showGrabber,
    child: builder(sheetContext),
  ),
);

class _GinkgoSwipeDismissSheet extends StatefulWidget {
  const _GinkgoSwipeDismissSheet({
    required this.child,
    required this.showGrabber,
  });

  final Widget child;
  final bool showGrabber;

  @override
  State<_GinkgoSwipeDismissSheet> createState() =>
      _GinkgoSwipeDismissSheetState();
}

class _GinkgoSwipeDismissSheetState extends State<_GinkgoSwipeDismissSheet>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  late final AnimationController _snapController = AnimationController(
    vsync: this,
    duration: GinkgoMotion.snappy,
  );
  Animation<double>? _snapAnimation;

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    final next = (_dragOffset + delta).clamp(0.0, 420.0);
    if (next != _dragOffset) {
      _snapController.stop();
      setState(() => _dragOffset = next);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset > 96 || velocity > 480) {
      HapticFeedback.lightImpact();
      Navigator.of(context).maybePop();
      return;
    }
    final start = _dragOffset;
    if (start == 0) return;
    _snapAnimation =
        Tween<double>(begin: start, end: 0).animate(
          CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
        )..addListener(() {
          if (mounted) setState(() => _dragOffset = _snapAnimation!.value);
        });
    _snapController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(AppleDesign.panelRadius(context));
    final background = CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    );
    return Transform.translate(
      offset: Offset(0, _dragOffset),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: radius),
          child: ColoredBox(
            color: background,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.showGrabber)
                  Semantics(
                    label: '向下拖动关闭面板',
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: GinkgoSpacing.sm,
                        bottom: GinkgoSpacing.xs,
                      ),
                      child: Center(
                        child: Container(
                          width: GinkgoSpacing.xxl,
                          height: GinkgoSpacing.xs,
                          decoration: BoxDecoration(
                            color: CupertinoColors.tertiaryLabel.resolveFrom(
                              context,
                            ),
                            borderRadius: BorderRadius.circular(
                              GinkgoRadii.pill,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Flexible(child: widget.child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
