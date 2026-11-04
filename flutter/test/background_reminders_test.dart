import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/background_reminders.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/shared/reminder_controller.dart';

import 'session_widget_test.dart' show FakeService, signedOut;
import 'reminder_planner_fake.dart';
import 'reminders_test.dart' show assignment;

class ScopedPlatform implements ReminderPlatform, ScopedReminderPlatform {
  Set<String>? groups;
  String? owner;
  List<Map<String, Object>> plans = [];
  bool? checkin, homework;
  Completer<void>? pending;
  @override
  Future<void> replace(List<Map<String, Object>> plans) async =>
      throw StateError('unscoped write');
  @override
  Future<void> clearOwner(String value) async {
    owner = null;
  }

  @override
  Future<void> synchronize({
    required String owner,
    required bool checkin,
    required bool homework,
    required Set<String> groups,
    required List<Map<String, Object>> plans,
  }) async {
    this.owner = owner;
    this.checkin = checkin;
    this.homework = homework;
    this.groups = groups;
    this.plans = plans;
    await pending?.future;
  }
}

class PendingCheckinService extends FakeService {
  PendingCheckinService()
    : super(restoreResponse: signedOut, loginResponse: signedOut);
  final pending = Completer<CheckInResponse>();
  int requests = 0;
  @override
  Future<CheckInResponse> checkin({bool forceRefresh = false}) {
    requests++;
    return pending.future;
  }
}

void main() {
  final now = DateTime.parse('2026-10-21T00:00:00Z');
  final owner = md5.convert(utf8.encode('sy2501001:background')).toString();
  const checkin = CheckInResponse(
    date: '2026-10-21',
    courses: [],
    fromCache: false,
    stale: false,
  );
  final homework = HomeworkResponse(
    termCode: '',
    termName: '',
    items: [assignment()],
  );

  test(
    'successful empty replaces only that group; failed homework is retained',
    () {
      final batch = backgroundReminderBatch(
        account: 'sy2501001',
        expectedOwner: owner,
        checkin: checkin,
        homework: const HomeworkResponse(
          termCode: '',
          termName: '',
          items: [],
          failure: FailureCode.serviceUnavailable,
        ),
        planner: Planner(),
        nowMillis: now.millisecondsSinceEpoch,
        personalHomework: (_) => true,
      );
      expect(batch.groups, {'checkin'});
      expect(batch.plans, isEmpty);
    },
  );
  test(
    'background plans use the same account-bound keys as foreground',
    () async {
      final batch = backgroundReminderBatch(
        account: 'sy2501001',
        expectedOwner: owner,
        checkin: null,
        homework: homework,
        planner: Planner(),
        nowMillis: now.millisecondsSinceEpoch,
        personalHomework: (_) => true,
      );
      expect(batch.groups, {'homework'});
      expect(batch.plans, isNotEmpty);
      expect(
        batch.plans.every(
          (plan) => RegExp(r'^[a-f0-9]{64}$').hasMatch(plan['key'] as String),
        ),
        isTrue,
      );
      final encoded = jsonEncode(batch.plans);
      expect(encoded, isNot(contains('sy2501001')));
      expect(encoded, isNot(contains('合成')));
      final platform = ScopedPlatform();
      final controller = ReminderController(
        service: FakeService(
          restoreResponse: signedOut,
          loginResponse: signedOut,
        ),
        account: 'sy2501001',
        visibility: null,
        platform: platform,
        persist: false,
        planner: Planner(),
        clock: () => now,
      );
      addTearDown(controller.dispose);
      await controller.restore();
      controller.updateHomework(homework);
      await controller.reconcile();
      expect(platform.plans, batch.plans);
    },
  );
  test('account mismatch cannot publish plans', () {
    expect(
      () => backgroundReminderBatch(
        account: 'sy2501002',
        expectedOwner: owner,
        checkin: checkin,
        homework: homework,
        planner: Planner(),
        nowMillis: now.millisecondsSinceEpoch,
        personalHomework: (_) => true,
      ),
      throwsStateError,
    );
  });
  test('a stalled first read cannot prevent native job registration', () async {
    final service = PendingCheckinService();
    final platform = ScopedPlatform();
    final controller = ReminderController(
      service: service,
      account: 'sy2501001',
      visibility: null,
      platform: platform,
      persist: false,
      planner: Planner(),
      clock: () => now,
    );
    addTearDown(controller.dispose);
    await controller.restore();
    final refresh = controller.refresh(includeHomework: false);
    await Future<void>.delayed(Duration.zero);
    try {
      expect(platform.owner, owner);
      expect(platform.checkin, true);
    } finally {
      service.pending.complete(checkin);
      await refresh;
    }
  });
  test(
    'a new read during native sync remains pending for the next pass',
    () async {
      final platform = ScopedPlatform()..pending = Completer<void>();
      final controller = ReminderController(
        service: FakeService(
          restoreResponse: signedOut,
          loginResponse: signedOut,
        ),
        account: 'sy2501001',
        visibility: null,
        platform: platform,
        persist: false,
        planner: Planner(),
        clock: () => now,
      );
      addTearDown(controller.dispose);
      await controller.restore();
      controller.updateHomework(homework);
      final first = controller.reconcile();
      await Future<void>.delayed(Duration.zero);
      controller.updateHomework(
        HomeworkResponse(
          termCode: '',
          termName: '',
          items: [assignment(id: 'newer')],
        ),
      );
      final next = controller.reconcile();
      platform.pending!.complete();
      await first;
      await next;
      expect(platform.groups, contains('homework'));
      final newer = backgroundReminderBatch(
        account: 'sy2501001',
        expectedOwner: owner,
        checkin: null,
        homework: HomeworkResponse(
          termCode: '',
          termName: '',
          items: [assignment(id: 'newer')],
        ),
        planner: Planner(),
        nowMillis: now.millisecondsSinceEpoch,
        personalHomework: (_) => true,
      );
      expect(platform.plans, newer.plans);
    },
  );
  test('retiring during job registration cannot start school reads', () async {
    final service = PendingCheckinService();
    final platform = ScopedPlatform()..pending = Completer<void>();
    final controller = ReminderController(
      service: service,
      account: 'sy2501001',
      visibility: null,
      platform: platform,
      persist: false,
      planner: Planner(),
      clock: () => now,
    );
    addTearDown(controller.dispose);
    await controller.restore();
    final refresh = controller.refresh(includeHomework: false);
    await Future<void>.delayed(Duration.zero);
    await controller.stop();
    platform.pending!.complete();
    await refresh;
    expect(service.requests, 0);
  });
  test('hidden or assistant homework can be excluded before planning', () {
    final batch = backgroundReminderBatch(
      account: 'sy2501001',
      expectedOwner: owner,
      checkin: null,
      homework: homework,
      planner: Planner(),
      nowMillis: now.millisecondsSinceEpoch,
      personalHomework: (_) => false,
    );
    expect(batch.groups, {'homework'});
    expect(batch.plans, isEmpty);
  });
  test(
    'resume does not overwrite newer native groups with old UI plans',
    () async {
      final platform = ScopedPlatform();
      final controller = ReminderController(
        service: FakeService(
          restoreResponse: signedOut,
          loginResponse: signedOut,
        ),
        account: 'sy2501001',
        visibility: null,
        platform: platform,
        persist: false,
        planner: Planner(),
        clock: () => now,
      );
      addTearDown(controller.dispose);
      await controller.restore();
      controller.updateHomework(homework);
      await controller.reconcile();
      expect(platform.groups, contains('homework'));
      controller.updateHomework(homework);
      await controller.reconcile();
      await controller.reschedule();
      expect(platform.groups, isNot(contains('homework')));
      // A background job can now own a newer native plan, while this controller
      // still has its old UI snapshot. Resume is not a successful school read.
      await controller.reschedule();
      expect(platform.groups, isNot(contains('homework')));
      controller.updateHomework(
        const HomeworkResponse(
          termCode: '',
          termName: '',
          items: [],
          failure: FailureCode.serviceUnavailable,
        ),
      );
      await controller.reschedule();
      expect(platform.groups, isNot(contains('homework')));
      controller.updateHomework(homework);
      await controller.reconcile();
      expect(platform.groups, contains('homework'));
    },
  );
  test(
    'controller arms background without deleting groups not yet read',
    () async {
      final platform = ScopedPlatform();
      final controller = ReminderController(
        service: FakeService(
          restoreResponse: signedOut,
          loginResponse: signedOut,
        ),
        account: 'sy2501001',
        visibility: null,
        platform: platform,
        persist: false,
        planner: Planner(),
        clock: () => now,
      );
      addTearDown(controller.dispose);
      await controller.restore();
      await controller.reconcile();
      expect(platform.owner, owner);
      expect(platform.checkin, isTrue);
      expect(platform.homework, isTrue);
      expect(platform.groups, {'course', 'task'});
      controller.updateCheckin(checkin);
      await controller.reconcile();
      expect(platform.groups, {'course', 'task', 'checkin'});
      await controller.setEnabled('homework', false);
      expect(platform.homework, isFalse);
      expect(platform.groups, contains('homework'));
      await controller.stop();
      expect(platform.owner, isNull);
    },
  );
}
