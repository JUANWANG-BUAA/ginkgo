import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/busy_gate.dart';
import 'package:ginkgo_mirror/application/diagnostic_log.dart';
import 'package:ginkgo_mirror/shared/course_visibility.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';

import 'reminders.dart';

/// 把 [ReminderController] 的作用域挂到子树上，并跟随应用生命周期启停。
///
/// 控制器由注入的工厂创建，本组件负责释放。
class ReminderScope extends StatefulWidget {
  const ReminderScope({
    super.key,
    required this.service,
    required this.account,
    required this.child,
    required this.controllerFactory,
  });

  /// The scope owns and disposes the returned controller.
  final ReminderController Function(
    MirrorService service,
    String account,
    CourseVisibility? visibility,
  )
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
  Timer? poll, tick, restoreWatchdog;
  AppLifecycleState? _lifecycle;
  bool _ready = false, _closed = false;
  int _generation = 0;
  Completer<void>? _restoring;

  /// One activation at a time, and never forever: a read that does not settle
  /// must not stop the poll/tick timers from ever starting.
  BusyGate _activation = BusyGate(deadline: const Duration(minutes: 5));

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
    _createController();
  }

  @override
  void didUpdateWidget(covariant ReminderScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.service, widget.service) ||
        oldWidget.account != widget.account) {
      _retireController();
      _createController();
    }
  }

  void _createController() {
    final visibility = CourseVisibilityScope.of(context);
    controller = widget.controllerFactory(
      widget.service,
      widget.account,
      visibility,
    );
    final current = controller!;
    final generation = ++_generation;
    unawaited(() async {
      var restoreFailed = false;
      final restored = Completer<void>();
      _restoring = restored;
      restoreWatchdog = Timer(const Duration(minutes: 1), () {
        restoreFailed = true;
        if (!restored.isCompleted) restored.complete();
      });
      unawaited(
        current
            .restore()
            .then((_) {
              if (!restored.isCompleted) restored.complete();
            })
            .catchError((Object _) {
              restoreFailed = true;
              if (!restored.isCompleted) restored.complete();
            }),
      );
      await restored.future;
      if (!mounted || _closed || generation != _generation) return;
      restoreWatchdog?.cancel();
      restoreWatchdog = null;
      _restoring = null;
      _ready = true;
      final activation = _activate(initial: true);
      if (restoreFailed && mounted && !_closed) {
        current.reportRestoreTimeout();
      }
      await activation;
    }());
  }

  Future<void> _activate({bool initial = false}) async {
    final current = controller;
    final generation = _generation;
    final gate = _activation;
    if (!_foreground || !_ready || current == null) return;
    if (!gate.enter()) return;
    try {
      final refresh = current.refresh(includeHomework: !initial);
      if (!initial) unawaited(current.reschedule());
      // Start the periodic work before waiting: whether this particular read
      // settles or not, the controller must keep ticking.
      if (_foreground) _start();
      await refresh;
    } finally {
      gate.leave();
      // A restore/read may finish after the app leaves the foreground.
      if (_foreground && generation == _generation) _start();
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

  void _retireController() {
    _generation++;
    _ready = false;
    _cancelTimers();
    restoreWatchdog?.cancel();
    restoreWatchdog = null;
    final restoring = _restoring;
    _restoring = null;
    if (restoring != null && !restoring.isCompleted) restoring.complete();
    _activation.dispose();
    _activation = BusyGate(deadline: const Duration(minutes: 5));
    final current = controller;
    controller = null;
    if (current != null) {
      unawaited(current.stop().catchError((Object _) {}));
      current.dispose();
    }
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
    _retireController();
    _activation.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ReminderData(notifier: controller!, child: widget.child);
}

class _ReminderData extends InheritedNotifier<ReminderController> {
  const _ReminderData({required super.notifier, required super.child});
}
