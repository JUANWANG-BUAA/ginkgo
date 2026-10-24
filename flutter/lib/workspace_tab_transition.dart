import 'package:flutter/cupertino.dart';

/// One clock above CupertinoTabScaffold's inactive TickerModes. The scaffold
/// still owns lazy mounting, offstage pages and each tab's original Navigator.
/// No outgoing page is copied or kept painting just for the transition.
class WorkspaceTabMotion extends StatefulWidget {
  const WorkspaceTabMotion({
    super.key,
    required this.controller,
    required this.child,
  });

  final CupertinoTabController controller;
  final Widget child;

  @override
  State<WorkspaceTabMotion> createState() => _WorkspaceTabMotionState();
}

class _WorkspaceTabMotionState extends State<WorkspaceTabMotion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 230),
    value: 1,
  );
  late int _index;
  double _direction = 1;
  bool _enabled = false;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    _index = widget.controller.index;
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_select);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (!_enabled) _finish();
  }

  @override
  void didUpdateWidget(WorkspaceTabMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_select);
      widget.controller.addListener(_select);
      _index = widget.controller.index;
      _finish();
    }
  }

  void _select() {
    final next = widget.controller.index;
    if (next == _index) return;
    _direction = next > _index ? 1 : -1;
    _index = next;
    if (_enabled && _resumed) {
      // A rapid selection replaces the previous motion, never queues it.
      _animation.forward(from: 0);
    } else {
      _finish();
    }
  }

  void _finish() {
    _animation.stop();
    _animation.value = 1;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (!_resumed) _finish();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_select);
    WidgetsBinding.instance.removeObserver(this);
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _TabMotionScope(motion: this, child: widget.child);
}

class _TabMotionScope extends InheritedWidget {
  const _TabMotionScope({required this.motion, required super.child});
  final _WorkspaceTabMotionState motion;

  @override
  bool updateShouldNotify(_TabMotionScope oldWidget) =>
      motion != oldWidget.motion;
}

/// Paint-only page-entry motion. The incoming sheet slides in one full page
/// width from the side it was selected from, so it reads as a page laid over
/// the workspace instead of a small nudge. A soft shadow on its free edge and
/// a narrow spine gradient on its hinged edge give the sheet paper depth; both
/// fade out with the motion, leaving no permanent shading.
///
/// The sheet itself is never faded (opacity stays 1) and a stable
/// child/repaint boundary means animation frames do not rebuild the page, its
/// Navigator, scrollables or filters. There are deliberately no horizontal
/// drag recognizers here.
class WorkspaceTabTransition extends StatelessWidget {
  const WorkspaceTabTransition({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = context
        .dependOnInheritedWidgetOfExactType<_TabMotionScope>()!
        .motion;
    final width = MediaQuery.sizeOf(context).width;
    return AnimatedBuilder(
      animation: motion._animation,
      child: RepaintBoundary(child: child),
      builder: (context, child) {
        final active = index == motion._index;
        final linear = active ? motion._animation.value : 1.0;
        final progress = Curves.easeOutCubic.transform(linear);
        return Transform.translate(
          offset: Offset(motion._direction * width * (1 - progress), 0),
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              ?child,
              Positioned.fill(
                child: IgnorePointer(
                  child: _PageEdge(
                    direction: motion._direction,
                    shade: active ? 1 - linear : 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Two gradient strips that make the sliding page read as a sheet of paper:
/// a wide shadow at its free (leading) edge and a narrower spine gradient at
/// the edge it is hinged on.
class _PageEdge extends StatelessWidget {
  const _PageEdge({required this.direction, required this.shade});

  static const Key shadowKey = ValueKey('workspace-tab-page-edge');
  static const Key spineKey = ValueKey('workspace-tab-page-spine');

  /// Positive when the page arrives from the right, negative from the left.
  final double direction;

  /// 0 at rest, 1 at the first frame of the motion.
  final double shade;

  @override
  Widget build(BuildContext context) {
    final leadingOnLeft = direction > 0;
    return Stack(
      children: [
        _layer(
          shadowKey,
          width: 34,
          fromLeft: leadingOnLeft,
          alphas: const [0.26, 0.10, 0.0],
        ),
        _layer(
          spineKey,
          width: 14,
          fromLeft: !leadingOnLeft,
          alphas: const [0.15, 0.05, 0.0],
        ),
      ],
    );
  }

  Widget _layer(
    Key key, {
    required double width,
    required bool fromLeft,
    required List<double> alphas,
  }) {
    return Align(
      alignment: fromLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: DecoratedBox(
          key: key,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: fromLeft ? Alignment.centerLeft : Alignment.centerRight,
              end: fromLeft ? Alignment.centerRight : Alignment.centerLeft,
              colors: [
                for (final alpha in alphas)
                  Color.fromRGBO(0, 0, 0, alpha * shade),
              ],
              stops: const [0, 0.4, 1],
            ),
          ),
        ),
      ),
    );
  }
}
