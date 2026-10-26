import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/failure_message.dart';
import 'package:ginkgo_mirror/application/diagnostic_log.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/local_tasks.dart';
import 'package:ginkgo_mirror/application/reminder_planning.dart';
import 'package:ginkgo_mirror/features/schedule/course_visibility.dart';
import 'package:ginkgo_mirror/features/homework/homework_projection.dart';
import 'package:ginkgo_mirror/shared/reminder_rules.dart';

abstract interface class ReminderPlatform {
  Future<void> replace(List<Map<String, Object>> plans);
}

class NativeReminderPlatform implements ReminderPlatform {
  static const channel = MethodChannel('cn.edu.buaa.ginkgo/reminders');
  @override
  Future<void> replace(List<Map<String, Object>> plans) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('当前平台不支持系统提醒，应用内提示仍可用');
    }
    await channel.invokeMethod<void>('replace', plans);
  }
}

/// Account-scoped read receipts contain only digests, not school content.
class ReminderController extends ChangeNotifier {
  ReminderController({
    required this.service,
    required this.account,
    required this.visibility,
    ReminderPlatform? platform,
    this.persist = true,
    DateTime Function()? clock,
    ReminderPlanningGateway? planner,
    Future<String> Function()? tasksRoot,
  }) : platform = platform ?? NativeReminderPlatform(),
       planner =
           planner ??
           (service is ReminderPlanningGateway
               ? service as ReminderPlanningGateway
               : null),
       tasksRoot = tasksRoot ?? localTasksStorageRoot,
       clock = clock ?? DateTime.now;
  final MirrorService service;
  final String account;
  final CourseVisibility? visibility;
  final ReminderPlatform platform;
  final bool persist;
  final ReminderPlanningGateway? planner;
  final Future<String> Function() tasksRoot;
  final DateTime Function() clock;
  final Map<String, int> _read = {};
  List<ReminderPlan> _checkin = [], _homework = [], _course = [], _task = [];
  final Map<String, int> _planningTickets = {};
  String? activeGroup;
  String? hint;
  bool checkinEnabled = true, homeworkEnabled = true;
  // Opt-in: do not silently add school reads or new notification groups.
  bool courseEnabled = false, taskEnabled = false;
  bool _busy = false, _disposed = false;
  bool _restored = false;
  Future<void> _writes = Future.value();
  int scheduled = 0;
  String? _lastPlatformState;
  String digest(String key) =>
      sha256.convert(utf8.encode('$account:$key')).toString();
  Future<File> _file() async => File(
    '${(await getApplicationSupportDirectory()).path}/reminders-${digest('account')}.json',
  );

  Future<void> restore() async {
    if (!persist) {
      _restored = true;
      return;
    }
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      checkinEnabled = data['checkin'] != false;
      homeworkEnabled = data['homework'] != false;
      courseEnabled = data['course'] == true;
      taskEnabled = data['task'] == true;
      for (final entry
          in (data['read'] as Map<String, dynamic>? ?? {}).entries) {
        if (entry.value is int &&
            (entry.value as int) > clock().millisecondsSinceEpoch) {
          _read[entry.key] = entry.value as int;
        }
      }
    } catch (_) {
      hint = '提醒偏好读取失败，已使用默认设置';
    } finally {
      _restored = true;
    }
  }

  Future<void> _save() {
    if (!persist) return Future.value();
    final data = jsonEncode({
      'checkin': checkinEnabled,
      'homework': homeworkEnabled,
      'course': courseEnabled,
      'task': taskEnabled,
      'read': _read,
    });
    _writes = _writes
        .then((_) async {
          final file = await _file();
          await file.parent.create(recursive: true);
          final temp = File('${file.path}.tmp');
          await temp.writeAsString(data, flush: true);
          await temp.rename(file.path);
        })
        .catchError((Object _) {
          if (!_disposed) {
            hint = '提醒已更新，但本机保存失败';
            notifyListeners();
          }
        });
    return _writes;
  }

  List<ReminderPlan> get plans => [
    if (checkinEnabled) ..._checkin,
    if (homeworkEnabled) ..._homework,
    if (courseEnabled) ..._course,
    if (taskEnabled) ..._task,
  ].where((p) => p.expires.isAfter(clock())).toList();
  static String _reminderGroup(String destination) => switch (destination) {
    'schedule' => 'course',
    'tasks' => 'task',
    _ => destination,
  };

  int unread(String group) => plans
      .where(
        (p) =>
            p.group == _reminderGroup(group) &&
            !p.at.isAfter(clock()) &&
            !_read.containsKey(digest(p.key)),
      )
      .length;

  void markRead(String group) {
    var changed = false;
    for (final plan in plans.where(
      (p) => p.group == _reminderGroup(group) && !p.at.isAfter(clock()),
    )) {
      final key = digest(plan.key);
      if (!_read.containsKey(key)) {
        _read[key] = plan.expires.millisecondsSinceEpoch;
        changed = true;
      }
    }
    if (changed) {
      unawaited(_save());
      notifyListeners();
    }
  }

  void setActive(String group) {
    activeGroup = group;
    markRead(group);
  }

  Future<void> setEnabled(String group, bool value) async {
    if (group == 'checkin') {
      checkinEnabled = value;
    } else if (group == 'homework') {
      homeworkEnabled = value;
    } else if (group == 'course') {
      courseEnabled = value;
      _planningTickets['course'] = (_planningTickets['course'] ?? 0) + 1;
      if (!value) _course = [];
    } else if (group == 'task') {
      taskEnabled = value;
      _planningTickets['task'] = (_planningTickets['task'] ?? 0) + 1;
      if (!value) _task = [];
    } else {
      throw ArgumentError.value(group, 'group');
    }
    await _save();
    await reconcile();
  }

  /// Failed or stale school reads never replace a previously accepted plan.
  Future<void> updateSchedule(ScheduleResponse data) async {
    if (_disposed || !courseEnabled) return;
    if (data.failure != null) {
      hint = '课程提醒未更新，请进入课表核对';
      return;
    }
    try {
      final seeds = data.courses.isEmpty
          ? <CourseReminderSeed>[]
          : courseReminderSeeds(data);
      await _plan('course', courses: seeds);
    } catch (_) {
      if (!_disposed) hint = '课程提醒未更新，课表时间或周次无法确认';
    }
  }

  Future<void> updateTasks(List<LocalTaskRecord> tasks) async {
    if (_disposed || !taskEnabled) return;
    await _plan('task', tasks: taskReminderSeeds(tasks));
  }

  Future<void> _plan(
    String group, {
    List<CourseReminderSeed> courses = const [],
    List<TaskReminderSeed> tasks = const [],
  }) async {
    final ticket = (_planningTickets[group] ?? 0) + 1;
    _planningTickets[group] = ticket;
    final currentPlanner = planner;
    if (currentPlanner == null) {
      hint = '当前服务不支持课程／待办提醒计划';
      return;
    }
    try {
      final result = await currentPlanner.planReminders(
        courses: courses,
        tasks: tasks,
        nowMillis: clock().millisecondsSinceEpoch,
      );
      if (_disposed || _planningTickets[group] != ticket) return;
      if (result.unsupported || result.plans.any((p) => p.group != group)) {
        hint = '当前服务暂不支持该提醒计划';
        return;
      }
      if (group == 'course') {
        _course = result.plans;
      } else {
        _task = result.plans;
      }
      if (result.skipped > 0) hint = '部分提醒时间不明确或已过期，未排程，请进入对应页面核对';
    } catch (_) {
      if (!_disposed && _planningTickets[group] == ticket) {
        hint = '提醒计划暂未更新，已保留仍有效的旧提醒';
      }
    }
  }

  void updateCheckin(CheckInResponse data) {
    if (data.failure == null && !data.stale) _checkin = checkinReminders(data);
  }

  void updateHomework(HomeworkResponse data) {
    if (data.failure == null) {
      _homework = homeworkReminders(
        personalHomeworkItems(data.items, visibility),
        clock(),
      );
    }
  }

  Future<void> refresh({bool includeHomework = true}) async {
    if (_busy || _disposed || service.isDemo) return;
    _busy = true;
    hint = null;
    // Independent reads: one service failing must not remove the other's plans.
    await Future.wait([
      if (courseEnabled)
        () async {
          final ticket = _planningTickets['course'] ?? 0;
          try {
            final data = await service.schedule(forceRefresh: true);
            if (!_disposed && (_planningTickets['course'] ?? 0) == ticket) {
              await updateSchedule(data);
            }
          } catch (_) {
            if (!_disposed) hint = '课程提醒未更新，请进入课表重试';
          }
        }(),
      if (taskEnabled)
        () async {
          final ticket = _planningTickets['task'] ?? 0;
          try {
            final root = await tasksRoot();
            if (_disposed) return;
            final data = await editLocalTasks(
              service,
              root: root,
              action: 'load',
            );
            if (!_disposed && (_planningTickets['task'] ?? 0) == ticket) {
              await updateTasks(data);
            }
          } catch (_) {
            if (!_disposed) hint = '待办提醒未更新，请进入待办页重试';
          }
        }(),
      () async {
        try {
          final data = await service.checkin(forceRefresh: true);
          if (!_disposed) {
            updateCheckin(data);
            if (data.failure != null) {
              hint = '签到提醒未更新：${failureMessage(data.failure)}';
            }
          }
        } catch (_) {
          if (!_disposed) hint = '签到提醒暂未更新，请进入签到页重试';
        }
      }(),
      if (includeHomework)
        () async {
          try {
            final data = await service.homework(forceRefresh: true);
            if (!_disposed) {
              updateHomework(data);
              if (data.failure != null) {
                hint = '作业提醒未更新：${failureMessage(data.failure)}';
              }
            }
          } catch (_) {
            if (!_disposed) hint = '作业提醒暂未更新，请进入作业页重试';
          }
        }(),
    ]);
    _busy = false;
    if (!_disposed) await reconcile();
  }

  Future<void> reconcile() async {
    if (_disposed || (persist && !_restored)) return;
    _read.removeWhere((_, expiry) => expiry <= clock().millisecondsSinceEpoch);
    if (activeGroup != null) markRead(activeGroup!);
    final sorted = plans..sort((a, b) => a.at.compareTo(b.at));
    final selected = sorted.take(60).toList();
    scheduled = selected.length;
    final platformPlans = <Map<String, Object>>[
      for (final p in selected)
        {
          'key': digest(p.key),
          'group': p.group,
          'at': p.at.millisecondsSinceEpoch,
          'expires': p.expires.millisecondsSinceEpoch,
        },
    ];
    final signature = jsonEncode(platformPlans);
    try {
      if (!service.isDemo && signature != _lastPlatformState) {
        await platform.replace(platformPlans);
        _lastPlatformState = signature;
      }
    } catch (_) {
      hint = '系统提醒排程失败，应用内未读提示仍可用';
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> reschedule() async {
    _lastPlatformState = null;
    await reconcile();
  }

  Future<void> stop() async {
    _disposed = true;
    if (!service.isDemo) await platform.replace([]);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

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
