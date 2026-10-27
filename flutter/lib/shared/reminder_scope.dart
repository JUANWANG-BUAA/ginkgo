import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/diagnostic_log.dart';
import 'package:ginkgo_mirror/features/schedule/course_visibility.dart';
import 'package:ginkgo_mirror/mirror_service.dart';

import 'reminders.dart';

/// 把 [ReminderController] 的作用域挂到子树上，并跟随应用生命周期启停。
///
/// 控制器由本组件创建并负责释放；[controllerFactory] 仅用于测试注入。
class ReminderScope extends StatefulWidget {
  const ReminderScope({
    super.key,
    required this.service,
    required this.account,
    required this.child,
    this.controllerFactory,
  });

  /// Optional factory; the scope owns and disposes the returned controller.
  final ReminderController Function(
    MirrorService service,
    String account,
    CourseVisibility? visibility,
  )?
  controllerFactory;
  final MirrorService service;
  final String account;
  final Widget child;
  static ReminderController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ReminderData>()?.notifier;
  static ReminderController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ReminderData>()?.notifier;
  @override
  State<ReminderScope> createState() => _ReminderScopeState();
}

class _ReminderScopeState extends State<ReminderScope>
    with WidgetsBindingObserver {
  ReminderController? controller;
  Timer? poll, tick;
  AppLifecycleState? _lifecycle;
  bool _ready = false, _activating = false, _closed = false;

  bool get _foreground =>
      mounted && !_closed && _lifecycle == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    DiagnosticLog.shared.current = null;
    _lifecycle =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (controller != null) return;
    final visibility = CourseVisibilityScope.of(context);
    controller =
        widget.controllerFactory?.call(
          widget.service,
          widget.account,
          visibility,
        ) ??
        ReminderController(
          service: widget.service,
          account: widget.account,
          visibility: visibility,
        );
    final current = controller!;
    unawaited(() async {
      await current.restore();
      if (!mounted || _closed) return;
      _ready = true;
      await _activate(initial: true);
    }());
  }

  Future<void> _activate({bool initial = false}) async {
    final current = controller;
    if (!_foreground || !_ready || _activating || current == null) return;
    _activating = true;
    try {
      final refresh = current.refresh(includeHomework: !initial);
      if (!initial) unawaited(current.reschedule());
      await refresh;
      // A restore/read may finish after the app leaves the foreground.
      if (_foreground) _start();
    } finally {
      _activating = false;
    }
  }

  void _start() {
    if (!_foreground || !_ready || poll != null || tick != null) return;
    poll = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_foreground) unawaited(controller!.refresh());
    });
    tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_foreground) unawaited(controller!.reconcile());
    });
  }

  void _cancelTimers() {
    poll?.cancel();
    tick?.cancel();
    poll = tick = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_closed || state == _lifecycle) return;
    _lifecycle = state;
    if (state == AppLifecycleState.resumed) {
      unawaited(_activate());
    } else {
      _cancelTimers();
    }
  }

  @override
  void dispose() {
    _closed = true;
    _cancelTimers();
    WidgetsBinding.instance.removeObserver(this);
    final current = controller;
    if (current != null) {
      unawaited(current.stop().catchError((Object _) {}));
      current.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ReminderData(notifier: controller!, child: widget.child);
}

class _ReminderData extends InheritedNotifier<ReminderController> {
  const _ReminderData({required super.notifier, required super.child});
}
