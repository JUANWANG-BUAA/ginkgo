import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'application/contracts.dart';
import 'application/failure_message.dart';
import 'application/diagnostic_log.dart';
import 'application/mirror_service.dart';
import 'course_visibility.dart';
import 'homework_projection.dart';
import 'reminder_rules.dart';

abstract interface class ReminderPlatform {
  Future<void> replace(List<Map<String, Object>> plans);
}

class NativeReminderPlatform implements ReminderPlatform {
  static const channel = MethodChannel('cn.edu.buaa.ginkgo/reminders');
  @override
  Future<void> replace(List<Map<String, Object>> plans) async {
    if (Platform.isAndroid) await channel.invokeMethod<void>('replace', plans);
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
  }) : platform = platform ?? NativeReminderPlatform(),
       clock = clock ?? DateTime.now;
  final MirrorService service;
  final String account;
  final CourseVisibility? visibility;
  final ReminderPlatform platform;
  final bool persist;
  final DateTime Function() clock;
  final Map<String, int> _read = {};
  List<ReminderPlan> _checkin = [], _homework = [];
  String? activeGroup;
  String? hint;
  bool checkinEnabled = true, homeworkEnabled = true;
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
  ].where((p) => p.expires.isAfter(clock())).toList();
  int unread(String group) => plans
      .where(
        (p) =>
            p.group == group &&
            !p.at.isAfter(clock()) &&
            !_read.containsKey(digest(p.key)),
      )
      .length;

  void markRead(String group) {
    var changed = false;
    for (final plan in plans.where(
      (p) => p.group == group && !p.at.isAfter(clock()),
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
    } else {
      homeworkEnabled = value;
    }
    await _save();
    await reconcile();
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
  });
  final MirrorService service;
  final String account;
  final Widget child;
  static ReminderController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ReminderData>()?.notifier;
  @override
  State<ReminderScope> createState() => _ReminderScopeState();
}

class _ReminderScopeState extends State<ReminderScope>
    with WidgetsBindingObserver {
  ReminderController? controller;
  Timer? poll, tick;
  @override
  void initState() {
    super.initState();
    DiagnosticLog.shared.current = null;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (controller != null) return;
    controller = ReminderController(
      service: widget.service,
      account: widget.account,
      visibility: CourseVisibilityScope.of(context),
    );
    unawaited(() async {
      await controller!.restore();
      if (mounted) {
        await controller!.refresh(includeHomework: false);
        if (mounted) _start();
      }
    }());
  }

  void _start() {
    poll?.cancel();
    tick?.cancel();
    poll = Timer.periodic(
      const Duration(minutes: 2),
      (_) => controller!.refresh(),
    );
    tick = Timer.periodic(
      const Duration(seconds: 15),
      (_) => controller!.reconcile(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(controller!.refresh());
      unawaited(controller!.reschedule());
      _start();
    } else {
      poll?.cancel();
      tick?.cancel();
    }
  }

  @override
  void dispose() {
    poll?.cancel();
    tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(controller!.stop().catchError((Object _) {}));
    controller!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ReminderData(notifier: controller!, child: widget.child);
}

class _ReminderData extends InheritedNotifier<ReminderController> {
  const _ReminderData({required super.notifier, required super.child});
}
