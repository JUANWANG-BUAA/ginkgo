import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/infrastructure/demo_mirror_service.dart';
import 'package:ginkgo_mirror/reminder_rules.dart';
import 'package:ginkgo_mirror/reminders.dart';
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

void main() {
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
    expect(checkinReminders(response([course()])).length, 1);
    expect(
      checkinReminders(
        response([
          course(status: CheckInStatus.signed),
          course(conflict: true),
        ]),
      ),
      isEmpty,
    );
    expect(checkinReminders(response([course()], stale: true)), isEmpty);
  });
  test('homework schedules 48h / 24h, skips completed, unknown deadlines and overdue; no two-stage catch-up flood', () {
    final now = DateTime.parse('2026-10-21T00:00:00Z');
    final plans = homeworkReminders([assignment()], now);
    expect(plans.map((p) => p.at.toIso8601String()), [
      '2026-10-21T00:00:00.000Z',
      '2026-10-22T00:00:00.000Z',
    ]);
    expect(
      homeworkReminders([
        assignment(),
      ], DateTime.parse('2026-10-22T01:00:00Z')).length,
      1,
    );
    expect(
      homeworkReminders([
        assignment(status: HomeworkStatus.submitted),
        assignment(due: 'invalid'),
        assignment(due: null),
      ], now),
      isEmpty,
    );
    expect(
      homeworkReminders([assignment()], DateTime.parse('2026-10-23T00:00:00Z')),
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
