import 'package:flutter/cupertino.dart';

/// One clock above the tabs' inactive TickerModes. Only the original incoming
/// and outgoing pages paint during a turn; their Navigators are never copied.
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
  int? _previousIndex;
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
    _previousIndex = _index;
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

/// Cupertino tab layout with a continuous page turn. Visited tabs retain their
/// original navigation stacks. Only the selected page can receive focus,
/// pointers, Hero flights or accessibility actions, even while two pages paint.
class WorkspaceTabScaffold extends StatefulWidget {
  const WorkspaceTabScaffold({
    super.key,
    required this.controller,
    required this.tabBar,
    required this.tabBuilder,
  });

  final CupertinoTabController controller;
  final CupertinoTabBar tabBar;
  final IndexedWidgetBuilder tabBuilder;

  @override
  State<WorkspaceTabScaffold> createState() => _WorkspaceTabScaffoldState();
}

class _WorkspaceTabScaffoldState extends State<WorkspaceTabScaffold> {
  final _visited = <int>{};
  final _focus = <int, FocusScopeNode>{};
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_select);
  }

  void _select() => setState(() {});

  @override
  void didUpdateWidget(WorkspaceTabScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_select);
      widget.controller.addListener(_select);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_select);
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = context
        .dependOnInheritedWidgetOfExactType<_TabMotionScope>()!
        .motion;
    final selected = widget.controller.index;
    _visited.add(selected);
    final node = _focus.putIfAbsent(selected, () => FocusScopeNode());
    FocusScope.of(context).setFirstFocus(node);
    // Build the page subtrees only on selection/layout changes, never per frame.
    final pages = <int, Widget>{
      for (final index in _visited)
        index: Builder(builder: (context) => widget.tabBuilder(context, index)),
    };
    final media = MediaQuery.of(context);
    var contentMedia = media.removeViewInsets(removeBottom: true);
    var bottom = media.viewInsets.bottom;
    if (widget.tabBar.preferredSize.height > bottom) {
      final obstruction =
          widget.tabBar.preferredSize.height + media.padding.bottom;
      if (widget.tabBar.opaque(context)) {
        bottom = obstruction;
        contentMedia = contentMedia.removePadding(removeBottom: true);
      } else {
        contentMedia = contentMedia.copyWith(
          padding: contentMedia.padding.copyWith(bottom: obstruction),
        );
      }
    }
    return ColoredBox(
      color: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: MediaQuery(
              data: contentMedia,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottom),
                child: ClipRect(
                  child: AnimatedBuilder(
                    animation: motion._animation,
                    builder: (context, _) => Stack(
                      fit: StackFit.expand,
                      children: [
                        // Paint the incoming page last so its edge is above the
                        // outgoing sheet, without remounting either subtree.
                        for (final index in [
                          ..._visited.where((index) => index != selected),
                          selected,
                        ])
                          _page(index, selected, motion, pages[index]!),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onHorizontalDragStart: (_) => _drag = 0,
              onHorizontalDragUpdate: (details) => _drag += details.delta.dx,
              onHorizontalDragEnd: (_) {
                if (_drag.abs() < 48) return;
                final rtl = Directionality.of(context) == TextDirection.rtl;
                final step = (_drag < 0) != rtl ? 1 : -1;
                widget.controller.index = (selected + step).clamp(
                  0,
                  widget.tabBar.items.length - 1,
                );
              },
              child: MediaQuery.withNoTextScaling(
                child: widget.tabBar.copyWith(
                  currentIndex: selected,
                  onTap: (index) {
                    widget.controller.index = index;
                    widget.tabBar.onTap?.call(index);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _page(
    int index,
    int selected,
    _WorkspaceTabMotionState motion,
    Widget page,
  ) {
    final active = index == selected;
    final outgoing =
        motion._animation.value < 1 && index == motion._previousIndex;
    return KeyedSubtree(
      key: ValueKey(index),
      child: HeroMode(
        enabled: active,
        child: Offstage(
          offstage: !active && !outgoing,
          child: TickerMode(
            enabled: active,
            child: ExcludeSemantics(
              excluding: !active,
              child: IgnorePointer(
                ignoring: !active,
                child: FocusScope(
                  node: _focus.putIfAbsent(index, () => FocusScopeNode()),
                  canRequestFocus: active,
                  child: page,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paint-only page-turn motion. The incoming sheet slides in one full page
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
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final width = MediaQuery.sizeOf(context).width;
    return AnimatedBuilder(
      animation: motion._animation,
      child: RepaintBoundary(child: child),
      builder: (context, child) {
        final active = index == motion._index;
        final outgoing = index == motion._previousIndex;
        final linear = active || outgoing ? motion._animation.value : 1.0;
        final progress = Curves.easeOutCubic.transform(linear);
        final direction = motion._direction * (rtl ? -1 : 1);
        final offset = active
            ? 1 - progress
            : outgoing
            ? -progress
            : 0.0;
        return Transform.translate(
          offset: Offset(direction * width * offset, 0),
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              ?child,
              Positioned.fill(
                child: IgnorePointer(
                  child: _PageEdge(
                    direction: direction,
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
