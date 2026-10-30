import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/local_tasks.dart';
import 'package:ginkgo_mirror/application/reminder_planning.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/shared/reminders.dart';

import 'reminder_planner_fake.dart';

class RecordingPlatform implements ReminderPlatform {
  List<Map<String, Object>> plans = [];
  int calls = 0;
  int inFlight = 0;
  int maxInFlight = 0;
  Completer<void>? gate;
  @override
  Future<void> replace(List<Map<String, Object>> plans) async {
    calls++;
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    this.plans = plans;
    final pending = gate;
    if (pending != null) await pending.future;
    inFlight--;
  }
}

class Service implements MirrorService {
  const Service();
  @override
  bool get isDemo => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RefreshService implements MirrorService {
  int scheduleCalls = 0, taskCalls = 0;
  String? taskAction;
  Completer<ScheduleResponse>? pendingSchedule;
  @override
  bool get isDemo => false;
  @override
  Future<ScheduleResponse> schedule({
    String? termId,
    int? week,
    bool forceRefresh = false,
  }) async {
    scheduleCalls++;
    return pendingSchedule?.future ?? scheduleResult();
  }

  ScheduleResponse scheduleResult() => scheduleData();
  @override
  Future<CheckInResponse> checkin({bool forceRefresh = false}) async =>
      const CheckInResponse(
        date: '2026-10-26',
        courses: [],
        fromCache: false,
        stale: false,
      );
  @override
  Future<HomeworkResponse> homework({bool forceRefresh = false}) async =>
      const HomeworkResponse(
        termName: 'synthetic',
        termCode: 'synthetic',
        items: [],
      );
  @override
  Future<LocalTasksRead> editTasks({
    required String root,
    required String action,
    String? id,
    String? title,
    String? due,
    bool? completed,
  }) async {
    taskCalls++;
    taskAction = action;
    return const LocalTasksRead(data: []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StalledRefreshService implements MirrorService {
  final checkinRequests = <Completer<CheckInResponse>>[];
  final homeworkRequests = <Completer<HomeworkResponse>>[];

  @override
  bool get isDemo => false;

  @override
  Future<CheckInResponse> checkin({bool forceRefresh = false}) {
    final request = Completer<CheckInResponse>();
    checkinRequests.add(request);
    return request.future;
  }

  @override
  Future<HomeworkResponse> homework({bool forceRefresh = false}) {
    final request = Completer<HomeworkResponse>();
    homeworkRequests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CheckInResponse checkinReminderResult(String id) => CheckInResponse(
  date: '2026-10-26',
  courses: [
    CheckInCourse(
      id: id,
      courseName: 'synthetic',
      beginsAt: '08:00',
      endsAt: '09:40',
      status: CheckInStatus.notSigned,
      mergedRecordCount: 1,
      conflicting: false,
    ),
  ],
  fromCache: false,
  stale: false,
);

HomeworkResponse homeworkReminderResult(String id) => HomeworkResponse(
  termName: 'synthetic',
  termCode: 'synthetic',
  items: [
    HomeworkItem(
      id: id,
      courseName: 'synthetic',
      title: 'synthetic',
      dueAt: '2026-10-27 08:00:00',
      status: HomeworkStatus.pending,
      courseRole: 'student',
    ),
  ],
);

const task = LocalTaskRecord(
  id: 'synthetic',
  title: 'not sent to planner',
  due: '2026-10-27T08:00:00+08:00',
  completed: false,
);
ScheduleResponse scheduleData({FailureCode? failure, bool empty = false}) =>
    ScheduleResponse(
      terms: const [],
      weeks: const [
        ScheduleWeek(
          number: 8,
          startDate: '2026-10-26',
          endDate: '2026-11-01',
          current: true,
        ),
      ],
      termId: 'synthetic',
      weekNumber: 8,
      courses: empty
          ? []
          : const [
              ScheduleCourse(
                id: 'course',
                name: 'not sent to planner',
                day: 1,
                startSection: 1,
                endSection: 2,
                startTime: '08:00',
                endTime: '09:40',
              ),
            ],
      exams: const [],
      failure: failure,
    );
void main() {
  final now = DateTime.utc(2026, 10, 25, 23, 50);
  ReminderPlan plan(String group) => ReminderPlan(
    key: '$group:synthetic',
    group: group,
    at: now,
    expires: now.add(const Duration(hours: 1)),
  );
  test('opt-in typed planner consumes course context and tasks, four groups reach platform without private titles', () async {
    final planner = Planner();
    final platform = RecordingPlatform();
    final controller = ReminderController(
      service: const Service(),
      account: 'synthetic',
      visibility: null,
      persist: false,
      planner: planner,
      platform: platform,
      clock: () => now,
    );
    addTearDown(controller.dispose);
    expect(controller.courseEnabled, false);
    expect(controller.taskEnabled, false);
    await controller.setEnabled('course', true);
    await controller.setEnabled('task', true);
    planner.result = ExtendedReminderPlans(plans: [plan('course')]);
    await controller.updateSchedule(scheduleData());
    expect(planner.courses.single.weekStart, '2026-10-26');
    expect(planner.courses.single.startsAt, '08:00');
    planner.result = ExtendedReminderPlans(plans: [plan('task')]);
    await controller.updateTasks([task]);
    expect(planner.tasks.single.id, 'synthetic');
    controller.updateCheckin(
      const CheckInResponse(
        date: '2026-10-26',
        courses: [
          CheckInCourse(
            id: 'synthetic',
            courseName: 'private',
            beginsAt: '08:00',
            endsAt: '09:40',
            status: CheckInStatus.notSigned,
            mergedRecordCount: 1,
            conflicting: false,
          ),
        ],
        fromCache: false,
        stale: false,
      ),
    );
    controller.updateHomework(
      const HomeworkResponse(
        termName: 'synthetic',
        termCode: 'synthetic',
        items: [
          HomeworkItem(
            id: 'private',
            courseName: 'private',
            title: 'private',
            dueAt: '2026-10-27 08:00:00',
            status: HomeworkStatus.pending,
            courseRole: 'student',
          ),
        ],
      ),
    );
    await controller.reconcile();
    expect(platform.plans.map((p) => p['group']).toSet(), {
      'course',
      'task',
      'homework',
      'checkin',
    });
    expect(
      platform.plans.every(
        (p) => RegExp(r'^[a-f0-9]{64}$').hasMatch(p['key']! as String),
      ),
      true,
    );
    expect(platform.plans.toString(), isNot(contains('private')));
    expect(controller.unread('course'), 1);
    expect(controller.unread('task'), 1);
  });
  test('failure keeps old course plan, success empty clears, task completion clear is accepted', () async {
    final planner = Planner();
    final controller = ReminderController(
      service: const Service(),
      account: 'synthetic',
      visibility: null,
      persist: false,
      planner: planner,
      platform: RecordingPlatform(),
      clock: () => now,
    );
    addTearDown(controller.dispose);
    await controller.setEnabled('course', true);
    await controller.setEnabled('task', true);
    planner.result = ExtendedReminderPlans(plans: [plan('course')]);
    await controller.updateSchedule(scheduleData());
    await controller.updateSchedule(
      scheduleData(failure: FailureCode.serviceUnavailable),
    );
    expect(controller.plans.length, 1);
    expect(controller.hint, contains('未更新'));
    planner.result = ExtendedReminderPlans(plans: []);
    await controller.updateSchedule(scheduleData(empty: true));
    expect(controller.plans, isEmpty);
    planner.result = ExtendedReminderPlans(plans: [plan('task')]);
    await controller.updateTasks([task]);
    planner.result = ExtendedReminderPlans(plans: []);
    await controller.updateTasks([]);
    expect(controller.plans, isEmpty);
  });
  test('late planning after disable or disposal cannot schedule, unsupported is visible', () async {
    final planner = Planner();
    final platform = RecordingPlatform();
    final controller = ReminderController(
      service: const Service(),
      account: 'synthetic',
      visibility: null,
      persist: false,
      planner: planner,
      platform: platform,
      clock: () => now,
    );
    await controller.setEnabled('task', true);
    planner.pending = Completer();
    final request = controller.updateTasks([task]);
    await Future<void>.delayed(Duration.zero);
    await controller.setEnabled('task', false);
    planner.pending!.complete(ExtendedReminderPlans(plans: [plan('task')]));
    await request;
    await controller.setEnabled('task', true);
    expect(controller.plans, isEmpty);
    planner.pending = null;
    planner.result = ExtendedReminderPlans(plans: [], unsupported: true);
    await controller.updateTasks([task]);
    expect(controller.hint, contains('不支持'));
    planner.pending = Completer();
    final late = controller.updateTasks([task]);
    await controller.stop();
    planner.pending!.complete(ExtendedReminderPlans(plans: [plan('task')]));
    await late;
    expect(platform.plans, isEmpty);
    controller.dispose();
  });
  test(
    'missing queried week fails visibly and unknown group cannot flip homework',
    () async {
      final controller = ReminderController(
        service: const Service(),
        account: 'synthetic',
        visibility: null,
        persist: false,
        planner: Planner(),
        platform: RecordingPlatform(),
        clock: () => now,
      );
      addTearDown(controller.dispose);
      await controller.setEnabled('course', true);
      await controller.updateSchedule(
        const ScheduleResponse(
          terms: [],
          weeks: [],
          termId: 'synthetic',
          weekNumber: 8,
          courses: [
            ScheduleCourse(
              id: 'id',
              name: 'name',
              day: 1,
              startSection: 1,
              endSection: 2,
            ),
          ],
          exams: [],
        ),
      );
      expect(controller.hint, contains('无法确认'));
      await expectLater(
        controller.setEnabled('other', false),
        throwsArgumentError,
      );
      expect(controller.homeworkEnabled, true);
    },
  );
  test('refresh only reads opted-in groups and late read cannot revive a disabled plan', () async {
    final service = RefreshService();
    final planner = Planner();
    final controller = ReminderController(
      service: service,
      account: 'synthetic',
      visibility: null,
      persist: false,
      planner: planner,
      platform: RecordingPlatform(),
      tasksRoot: () async => '/synthetic',
      clock: () => now,
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(service.scheduleCalls, 0);
    expect(service.taskCalls, 0);
    await controller.setEnabled('task', true);
    await controller.refresh();
    expect(service.taskAction, 'load');
    await controller.setEnabled('course', true);
    service.pendingSchedule = Completer();
    planner.result = ExtendedReminderPlans(plans: [plan('course')]);
    final refresh = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    await controller.setEnabled('course', false);
    await controller.setEnabled('course', true);
    service.pendingSchedule!.complete(scheduleData());
    await refresh;
    expect(controller.plans.where((p) => p.group == 'course'), isEmpty);
  });

  test('overlapping reconciles are joined and rerun once', () async {
    final platform = RecordingPlatform();
    final controller = ReminderController(
      service: const Service(),
      account: 'sy2501001',
      visibility: null,
      platform: platform,
      persist: false,
      planner: Planner(),
    );
    addTearDown(controller.dispose);

    // Hold the first platform call open, then ask for two more passes.
    platform.gate = Completer<void>();
    final first = controller.reconcile();
    await Future<void>.delayed(Duration.zero);
    expect(platform.calls, 1);

    final second = controller.reconcile();
    final third = controller.reconcile();
    expect(
      identical(second, third),
      isTrue,
      reason: 'a tick during a running pass must join, not stack',
    );
    expect(platform.calls, 1, reason: 'only one replace may be in flight');

    platform.gate!.complete();
    await first;
    await second;
    await third;
    // The invariant: a tick can never overlap a running pass on the platform
    // channel. Without the join, three ticks would push three replaces onto the
    // Android main thread at once.
    expect(platform.maxInFlight, 1);
  });

  testWidgets('stalled refresh cannot overwrite a newer reminder generation', (
    tester,
  ) async {
    final service = StalledRefreshService();
    final platform = RecordingPlatform();
    final controller = ReminderController(
      service: service,
      account: 'synthetic',
      visibility: null,
      persist: false,
      planner: Planner(),
      platform: platform,
      clock: () => now,
    );
    addTearDown(controller.dispose);

    final first = controller.refresh();
    await tester.pump();
    expect(service.checkinRequests, hasLength(1));
    expect(service.homeworkRequests, hasLength(1));

    await tester.pump(const Duration(minutes: 5));
    final second = controller.refresh();
    await tester.pump();
    expect(service.checkinRequests, hasLength(2));
    expect(service.homeworkRequests, hasLength(2));

    service.checkinRequests[1].complete(checkinReminderResult('new'));
    service.homeworkRequests[1].complete(homeworkReminderResult('new'));
    await second;
    await tester.pump();

    service.checkinRequests[0].complete(checkinReminderResult('old'));
    service.homeworkRequests[0].complete(homeworkReminderResult('old'));
    await first;
    await tester.pump();

    final keys = controller.plans.map((plan) => plan.key).join('\n');
    expect(keys, contains('new'));
    expect(keys, isNot(contains('old')));
    final scheduled = platform.plans.map((plan) => plan['key']).join('\n');
    expect(scheduled, isNot(contains('old')));
  });
}
