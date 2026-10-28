import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/busy_gate.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/failure_message.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/local_tasks.dart';
import 'package:ginkgo_mirror/application/reminder_planning.dart';
import 'package:ginkgo_mirror/application/service_capabilities.dart';
import 'package:ginkgo_mirror/application/reminder_store.dart';
import 'package:ginkgo_mirror/application/reminder_platform.dart';
import 'package:ginkgo_mirror/shared/course_visibility.dart';
import 'package:ginkgo_mirror/shared/homework_visibility.dart';
import 'package:ginkgo_mirror/shared/reminder_rules.dart';

// Scope 与控制器分属不同文件；调用方仍从本文件取全部提醒能力。
export 'reminder_scope.dart';

export 'package:ginkgo_mirror/application/reminder_platform.dart';

/// Account-scoped read receipts contain only digests, not school content.
class ReminderController extends ChangeNotifier {
  ReminderController({
    required this.service,
    required this.account,
    required this.visibility,
    required this.platform,
    this.persist = true,
    DateTime Function()? clock,
    ReminderPlanningGateway? planner,
    Future<String> Function()? tasksRoot,
    this.store,
  }) : planner =
           planner ?? ServiceCapabilities.resolve(service).reminderPlanning,
       tasksRoot = tasksRoot ?? _missingTasksRoot,
       clock = clock ?? DateTime.now;
  final MirrorService service;
  final String account;
  final CourseVisibility? visibility;
  final ReminderPlatform platform;
  final bool persist;
  final ReminderPlanningGateway? planner;
  final Future<String> Function() tasksRoot;
  final ReminderStore? store;
  final DateTime Function() clock;
  final Map<String, int> _read = {};
  List<ReminderPlan> _checkin = [], _homework = [], _course = [], _task = [];
  final Map<String, int> _planningTickets = {};
  String? activeGroup;
  String? hint;
  bool checkinEnabled = true, homeworkEnabled = true;
  // Opt-in: do not silently add school reads or new notification groups.
  bool courseEnabled = false, taskEnabled = false;
  bool _disposed = false;

  /// A read that never settles must not disable reminders for the whole
  /// session: the gate reopens on its own and says so.
  final _refreshGate = BusyGate(deadline: const Duration(minutes: 5));
  bool get busy => _refreshGate.busy;
  bool _restored = false;
  bool _storageReady = false;
  bool get settingsReady => !persist || _storageReady;
  bool get canRetryRestore => persist && _restored && !_storageReady;
  int scheduled = 0;
  String? _lastPlatformState;
  String digest(String key) =>
      sha256.convert(utf8.encode('$account:$key')).toString();
  static Future<String> _missingTasksRoot() =>
      Future.error(StateError('Task storage is unavailable'));

  Future<void> restore() async {
    if (_disposed) return;
    if (!persist) {
      _restored = true;
      _storageReady = true;
      return;
    }
    _restored = false;
    _storageReady = false;
    notifyListeners();
    try {
      final storage = store;
      if (storage == null) throw StateError('Reminder storage is unavailable');
      final encoded = await storage.read();
      if (_disposed) return;
      _storageReady = true;
      hint = null;
      if (encoded == null) return;
      final data = jsonDecode(encoded) as Map<String, dynamic>;
      final savedRead = data['read'] as Map<String, dynamic>? ?? {};
      final recovered = <String, int>{};
      for (final entry in savedRead.entries) {
        if (entry.value is int &&
            (entry.value as int) > clock().millisecondsSinceEpoch) {
          recovered[entry.key] = entry.value as int;
        }
      }
      checkinEnabled = data['checkin'] != false;
      homeworkEnabled = data['homework'] != false;
      courseEnabled = data['course'] == true;
      taskEnabled = data['task'] == true;
      _read
        ..clear()
        ..addAll(recovered);
    } catch (_) {
      _storageReady = false;
      if (!_disposed) hint = '提醒偏好读取失败，请重试后再修改';
    } finally {
      if (!_disposed) {
        _restored = true;
        notifyListeners();
      }
    }
  }

  void reportRestoreTimeout() {
    if (_disposed) return;
    hint = '提醒偏好读取未完成，请稍后再修改';
    notifyListeners();
  }

  Future<void> _save() {
    if (!persist) return Future.value();
    if (_disposed || !_storageReady) return Future.value();
    final data = jsonEncode({
      'checkin': checkinEnabled,
      'homework': homeworkEnabled,
      'course': courseEnabled,
      'task': taskEnabled,
      'read': _read,
    });
    final storage = store;
    return Future<void>.sync(() {
      if (storage == null) throw StateError('Reminder storage is unavailable');
      return storage.write(data);
    }).catchError((Object _) {
      if (!_disposed) {
        hint = '提醒已更新，但本机保存失败';
        notifyListeners();
      }
    });
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
    if (_disposed || (persist && !_storageReady)) return;
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
    if (_disposed) return;
    if (persist && !_storageReady) {
      hint = '提醒偏好尚未读取，请稍后重试';
      notifyListeners();
      return;
    }
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
    if (_disposed || service.isDemo) return;
    if (!_refreshGate.enter()) return;
    _refreshGate.onExpired = () {
      if (_disposed) return;
      hint = '上次提醒刷新未完成，已重新允许刷新';
      notifyListeners();
    };
    if (settingsReady) hint = null;
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
    _refreshGate.leave();
    if (!_disposed) await reconcile();
  }

  /// Serializes platform scheduling. A 15 s tick can arrive while a previous
  /// `replace` is still running; without this, overlapping calls would queue on
  /// the Android main thread and each re-cancel/re-arm up to 60 alarms.
  Future<void>? _reconciling;
  Future<void>? _reconcileRerun;

  Future<void> reconcile() {
    if (_disposed || (persist && !_storageReady)) return Future.value();
    final inFlight = _reconciling;
    if (inFlight == null) {
      return _reconciling = _reconcile().whenComplete(
        () => _reconciling = null,
      );
    }
    // A tick that arrived mid-run must not be dropped: the plans may have
    // changed since the running pass started.
    return _reconcileRerun ??= inFlight
        .then((_) async {
          _reconcileRerun = null;
          if (_disposed) return;
          await reconcile();
        })
        .whenComplete(() => _reconcileRerun = null);
  }

  Future<void> _reconcile() async {
    if (_disposed || (persist && !_storageReady)) return;
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
    _refreshGate.dispose();
    super.dispose();
  }
}
