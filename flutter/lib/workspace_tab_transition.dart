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
    duration: const Duration(milliseconds: 210),
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

/// Paint-only entry motion. A stable child/repaint boundary means animation
/// frames do not rebuild the page, its Navigator, scrollables or filters.
/// There are deliberately no horizontal drag recognizers here.
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
    return AnimatedBuilder(
      animation: motion._animation,
      child: RepaintBoundary(child: child),
      builder: (context, child) {
        final progress = index == motion._index
            ? Curves.easeOutCubic.transform(motion._animation.value)
            : 1.0;
        return Transform.translate(
          offset: Offset(16 * motion._direction * (1 - progress), 0),
          child: Opacity(opacity: 0.86 + 0.14 * progress, child: child),
        );
      },
    );
  }
}
