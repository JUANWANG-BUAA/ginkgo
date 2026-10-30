import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/reminder_planning.dart';
import 'package:ginkgo_mirror/application/reminder_store.dart';
import 'package:ginkgo_mirror/infrastructure/demo_mirror_service.dart';
import 'package:ginkgo_mirror/infrastructure/reminder_store.dart';
import 'package:ginkgo_mirror/shared/reminder_rules.dart';
import 'package:ginkgo_mirror/shared/reminders.dart';

import 'reminder_planner_fake.dart';
import 'reminder_rule_double.dart';
import 'package:ginkgo_mirror/application/diagnostic_log.dart';

CheckInCourse course({
  CheckInStatus status = CheckInStatus.notSigned,
  bool conflict = false,
}) => CheckInCourse(
  id: 'synthetic',
  courseName: '合成课程',
  beginsAt: '08:00',
  endsAt: '09:00',
  status: status,
  mergedRecordCount: 1,
  conflicting: conflict,
);
HomeworkItem assignment({
  String id = 'synthetic',
  HomeworkStatus status = HomeworkStatus.pending,
  String? due = '2026-10-23 08:00:00',
}) => HomeworkItem(
  id: id,
  courseName: '合成课程',
  title: '合成作业',
  dueAt: due,
  status: status,
  courseRole: 'student',
);

class FakeReminderPlatform implements ReminderPlatform {
  List<Map<String, Object>> plans = [];
  @override
  Future<void> replace(List<Map<String, Object>> plans) async {
    this.plans = plans;
  }
}

class MemoryReminderStore implements ReminderStore {
  String? data;
  bool failWrites = false;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String value) async {
    if (failWrites) throw StateError('unavailable');
    data = value;
  }
}

class _DelayedReminderStore implements ReminderStore {
  final reading = Completer<String?>();
  final writes = <String>[];
  @override
  Future<String?> read() => reading.future;
  @override
  Future<void> write(String data) async => writes.add(data);
}

/// The check-in and assignment reminder rule lives in the domain; the unit
/// tests cannot load it, so they plan through the double that the shared table
/// pins against the domain implementation.
List<ReminderPlan> planCheckin(CheckInResponse response, DateTime now) =>
    const ReminderRuleDouble().plan(
      checkin: checkinReminderSeeds(response.date, response.courses),
      homework: const [],
      now: now,
    ).plans;

List<ReminderPlan> planHomework(List<HomeworkItem> items, DateTime now) =>
    const ReminderRuleDouble().plan(
      checkin: const [],
      homework: homeworkReminderSeeds(items),
      now: now,
    ).plans;

void main() {
  test(
    'failed file write does not poison later same-account operations',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ginkgo-reminders-failure-',
      );
      addTearDown(() => directory.delete(recursive: true));
      var fail = true;
      final store = FileReminderStore(
        'failure-test',
        directory: () async {
          if (fail) throw StateError('unavailable');
          return directory;
        },
      );
      await expectLater(store.write('old'), throwsStateError);
      fail = false;
      await store.write('new');
      expect(await store.read(), 'new');
    },
  );

  test('corrupt reminder preferences are never overwritten on edit', () async {
    final store = MemoryReminderStore()..data = '{"checkin":false,"read":[]}';
    final controller = ReminderController(
      service: const DemoMirrorService(),
      account: 'synthetic',
      visibility: null,
      store: store,
      platform: FakeReminderPlatform(),
    );
    addTearDown(controller.dispose);
    await controller.restore();
    expect(controller.checkinEnabled, isTrue);
    expect(controller.settingsReady, isFalse);
    expect(controller.canRetryRestore, isTrue);
    await controller.setEnabled('checkin', false);
    expect(store.data, '{"checkin":false,"read":[]}');
  });

  test(
    'replacement controller restores after both pending same-account edits',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ginkgo-reminders-switch-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final blocked = Completer<Directory>();
      var blockNext = false;
      Future<Directory> resolve() {
        if (blockNext) {
          blockNext = false;
          return blocked.future;
        }
        return Future.value(directory);
      }

      ReminderController create() => ReminderController(
        service: const DemoMirrorService(),
        account: 'synthetic',
        visibility: null,
        store: FileReminderStore('synthetic', directory: resolve),
        platform: FakeReminderPlatform(),
      );
      final old = create();
      final next = create();
      addTearDown(old.dispose);
      addTearDown(next.dispose);
      await old.restore();
      blockNext = true;
      final first = old.setEnabled('task', true);
      final second = old.setEnabled('course', true);
      var restored = false;
      final read = next.restore().then((_) => restored = true);
      await Future<void>.delayed(Duration.zero);
      expect(restored, isFalse);
      blocked.complete(directory);
      await Future.wait([first, second, read]);
      expect(next.taskEnabled, isTrue);
      expect(next.courseEnabled, isTrue);
    },
  );

  test(
    'same-account store reads wait for all previously accepted writes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ginkgo-reminders-queue-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final blocked = Completer<Directory>();
      var resolutions = 0;
      Future<Directory> resolve() {
        resolutions++;
        return resolutions == 1 ? blocked.future : Future.value(directory);
      }

      final old = FileReminderStore('synthetic', directory: resolve);
      final next = FileReminderStore('synthetic', directory: resolve);
      final first = old.write('first');
      final second = old.write('second');
      final read = next.read();
      await Future<void>.delayed(Duration.zero);
      expect(resolutions, 1);
      blocked.complete(directory);
      await Future.wait([first, second]);
      expect(await read, 'second');
    },
  );

  test(
    'preferences cannot be changed while restoration is unresolved',
    () async {
      final store = _DelayedReminderStore();
      final controller = ReminderController(
        service: const DemoMirrorService(),
        account: 'synthetic',
        visibility: null,
        store: store,
        platform: FakeReminderPlatform(),
      );
      addTearDown(controller.dispose);
      final restoring = controller.restore();
      await controller.setEnabled('task', true);
      expect(controller.taskEnabled, isFalse);
      expect(store.writes, isEmpty);
      expect(controller.hint, contains('读取'));
      store.reading.complete('{"task":false,"read":{}}');
      await restoring;
      await controller.setEnabled('task', true);
      expect(controller.taskEnabled, isTrue);
      expect(store.writes, hasLength(1));
    },
  );
  test(
    'file store reads the existing account file and isolates accounts',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ginkgo-reminders-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final controller = ReminderController(
        service: const DemoMirrorService(),
        account: 'synthetic',
        visibility: null,
        persist: false,
        platform: FakeReminderPlatform(),
      );
      addTearDown(controller.dispose);
      final oldFile = File(
        '${directory.path}/reminders-${controller.digest('account')}.json',
      );
      await oldFile.writeAsString('{"checkin":false}');
      final store = FileReminderStore(
        'synthetic',
        directory: () async => directory,
      );
      final other = FileReminderStore(
        'other',
        directory: () async => directory,
      );
      expect(await store.read(), '{"checkin":false}');
      expect(await other.read(), isNull);
      await store.write('{"checkin":true}');
      expect(await oldFile.readAsString(), '{"checkin":true}');
      expect(await File('${oldFile.path}.tmp').exists(), isFalse);
    },
  );
  test('reminder settings restore and persist through the injected store', () async {
    final store = MemoryReminderStore()
      ..data =
          '{"checkin":false,"homework":true,"course":true,"task":false,"read":{}}';
    final controller = ReminderController(
      service: const DemoMirrorService(),
      account: 'synthetic',
      visibility: null,
      store: store,
      platform: FakeReminderPlatform(),
    );
    addTearDown(controller.dispose);
    await controller.restore();
    expect(controller.checkinEnabled, isFalse);
    expect(controller.courseEnabled, isTrue);
    await controller.setEnabled('task', true);
    expect((jsonDecode(store.data!) as Map)['task'], isTrue);
    store.failWrites = true;
    await controller.setEnabled('task', false);
    expect(controller.hint, '提醒已更新，但本机保存失败');
    expect((jsonDecode(store.data!) as Map)['task'], isTrue);
  });
  test('check-in opens at exactly ten minutes and closes at end, Beijing independent of device zone', () {
    bool open(String now) =>
        checkinWindowOpen(course(), '2026-10-20', DateTime.parse(now));
    expect(open('2026-10-20T07:49:59+08:00'), false);
    expect(open('2026-10-20T07:50:00+08:00'), true);
    expect(open('2026-10-20T00:00:00Z'), true);
    expect(open('2026-10-20T09:00:00+08:00'), false);
    expect(open('2026-10-19T08:00:00+08:00'), false);
    expect(schoolInstant('2026-02-30 10:00:00'), isNull);
  });
  test('one check-in reminder, none for signed, ambiguous or stale data', () {
    CheckInResponse response(List<CheckInCourse> items, {bool stale = false}) =>
        CheckInResponse(
          date: '2026-10-20',
          courses: items,
          fromCache: false,
          stale: stale,
        );
    // Before the session starts: a class already running never reminds.
    final now = DateTime.parse('2026-10-20T07:55:00+08:00');
    expect(planCheckin(response([course()]), now).length, 1);
    expect(
      planCheckin(
        response([
          course(status: CheckInStatus.signed),
          course(conflict: true),
        ]),
        now,
      ),
      isEmpty,
    );
    // Stale data is not a rule question: the controller refuses to plan from
    // a snapshot it could not refresh.
    final controller = ReminderController(
      service: const DemoMirrorService(),
      account: 'synthetic',
      visibility: null,
      platform: FakeReminderPlatform(),
      planner: Planner(),
    );
    controller.updateCheckin(response([course()], stale: true));
    expect(controller.plans, isEmpty);
  });
  test('distinct teaching-class IDs keep separate reminders and duplicate IDs fold', () {
    CheckInCourse target(String id) => CheckInCourse(
      id: id,
      courseName: '机器人控制技术',
      beginsAt: '09:50',
      endsAt: '12:15',
      status: CheckInStatus.notSigned,
      mergedRecordCount: 1,
      conflicting: false,
      signInAllowed: true,
    );
    final response = CheckInResponse(
      date: '2026-10-20',
      courses: [target('101'), target('102'), target('101')],
      fromCache: false,
      stale: false,
    );

    expect(
      planCheckin(response, DateTime.parse('2026-10-20T01:40:00Z')),
      hasLength(2),
    );
  });
  test('homework schedules 48h / 24h, skips completed, unknown deadlines and overdue; no two-stage catch-up flood', () {
    final now = DateTime.parse('2026-10-21T00:00:00Z');
    final plans = planHomework([assignment()], now);
    expect(plans.map((p) => p.at.toIso8601String()), [
      '2026-10-21T00:00:00.000Z',
      '2026-10-22T00:00:00.000Z',
    ]);
    expect(
      planHomework([assignment()], DateTime.parse('2026-10-22T01:00:00Z')).length,
      1,
    );
    expect(
      planHomework([
        assignment(status: HomeworkStatus.submitted),
        assignment(due: 'invalid'),
        assignment(due: null),
      ], now),
      isEmpty,
    );
    expect(
      planHomework([assignment()], DateTime.parse('2026-10-23T00:00:00Z')),
      isEmpty,
    );
  });
  test('read receipts deduplicate per stage and account; completion cancels plans; switches work', () async {
    var now = DateTime.parse('2026-10-21T00:00:00Z');
    final platform = FakeReminderPlatform();
    final controller = ReminderController(
      service: const DemoMirrorService(),
      account: 'synthetic',
      visibility: null,
      platform: platform,
      persist: false,
      clock: () => now,
      planner: Planner(),
    );
    addTearDown(controller.dispose);
    HomeworkResponse response(HomeworkStatus status) => HomeworkResponse(
      termName: '合成',
      termCode: 'synthetic',
      items: [assignment(status: status)],
    );
    controller.updateHomework(response(HomeworkStatus.pending));
    await controller.reconcile();
    expect(controller.unread('homework'), 1);
    controller.markRead('homework');
    controller.updateHomework(response(HomeworkStatus.pending));
    expect(controller.unread('homework'), 0);
    now = now.add(const Duration(days: 1));
    controller.updateHomework(response(HomeworkStatus.pending));
    expect(controller.unread('homework'), 1);
    await controller.setEnabled('homework', false);
    expect(controller.plans, isEmpty);
    await controller.setEnabled('homework', true);
    expect(controller.unread('homework'), 1);
    final other = ReminderController(
      service: const DemoMirrorService(),
      account: 'other',
      visibility: null,
      persist: false,
      platform: FakeReminderPlatform(),
    );
    expect(controller.digest('same'), isNot(other.digest('same')));
    other.dispose();
    controller.updateHomework(response(HomeworkStatus.submitted));
    expect(controller.plans, isEmpty);
  });
  test('diagnostics coalesce repeated failures and only retain bounded code/time data', () async {
    final log = DiagnosticLog();
    log.record(FailureCode.serviceUnavailable);
    log.record(FailureCode.serviceUnavailable);
    expect(log.entries.length, 1);
    for (var i = 0; i < 60; i++) {
      log.record(FailureCode.values[i % FailureCode.values.length]);
    }
    expect(log.entries.length, 50);
    expect(
      log.entries.last.summary,
      contains(
        'code=${FailureCode.values[59 % FailureCode.values.length].name}',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    log.dispose();
  });
}
