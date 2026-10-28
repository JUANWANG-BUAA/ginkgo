import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/local_tasks.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/features/homework/homework_detail_page.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/shared/reminders.dart';
import 'package:ginkgo_mirror/features/tasks/tasks_page.dart';
import 'package:ginkgo_mirror/features/today/today_action_row.dart';
import 'package:ginkgo_mirror/features/today/today_course_focus.dart';
import 'package:ginkgo_mirror/features/today/today_course_section.dart';
import 'package:ginkgo_mirror/features/today/today_homework_section.dart';
import 'package:ginkgo_mirror/features/today/today_page.dart';
import 'package:ginkgo_mirror/features/today/today_tasks_section.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';

final clock = DateTime.utc(2026, 10, 22, 9);
const emptyCourses = TodayResponse(date: '2026-10-22', courses: []);
const emptyHomework = HomeworkResponse(
  termName: '合成学期',
  termCode: 'synthetic',
  items: [],
);
const oneHomework = HomeworkResponse(
  termName: '合成学期',
  termCode: 'synthetic',
  items: [
    HomeworkItem(
      id: 'spoc:assignment-one',
      courseName: '合成课程',
      title: '合成报告',
      dueAt: '2026-10-22T12:00:00+08:00',
      status: HomeworkStatus.pending,
    ),
  ],
);
Map<String, Object> task(
  String id, {
  String due = '',
  bool completed = false,
}) => {'id': id, 'title': '事项$id', 'due': due, 'completed': completed};
ReadOnlyResponse tasksPayload(List<Map<String, Object>> tasks) =>
    ReadOnlyResponse(stale: false, payload: jsonEncode(tasks));

/// This fake owns only Today capabilities. Any eager unrelated module call fails.
class TodayFake extends Fake implements MirrorService {
  int courseReads = 0, homeworkReads = 0, taskReads = 0;
  final roots = <String>[];
  final details = <String>[];
  final courseRequests = <Completer<TodayResponse>>[];
  final homeworkRequests = <Completer<HomeworkResponse>>[];
  final taskRequests = <Completer<ReadOnlyResponse>>[];
  bool holdCourses = false, holdHomework = false, holdTasks = false;
  HomeworkResponse assignments = emptyHomework;
  ReadOnlyResponse local = tasksPayload([]);
  @override
  bool get isDemo => true;
  @override
  Future<TodayResponse> today({bool forceRefresh = false}) {
    courseReads++;
    if (!holdCourses) return Future.value(emptyCourses);
    final c = Completer<TodayResponse>();
    courseRequests.add(c);
    return c.future;
  }

  @override
  Future<HomeworkResponse> homework({bool forceRefresh = false}) {
    homeworkReads++;
    if (!holdHomework) return Future.value(assignments);
    final c = Completer<HomeworkResponse>();
    homeworkRequests.add(c);
    return c.future;
  }

  @override
  Future<ReadOnlyResponse> editTasks({
    required String root,
    required String action,
    String? id,
    String? title,
    String? due,
    bool? completed,
  }) {
    expect(action, 'load'); // Today must never write or auto-complete a task.
    roots.add(root);
    taskReads++;
    if (!holdTasks) return Future.value(local);
    final c = Completer<ReadOnlyResponse>();
    taskRequests.add(c);
    return c.future;
  }

  @override
  Future<HomeworkDetailResponse> homeworkDetail(
    String assignmentId, {
    bool forceRefresh = false,
  }) async {
    details.add(assignmentId);
    return const HomeworkDetailResponse(
      status: '待完成',
      stale: false,
      content: '合成内容',
    );
  }
}

class ReminderSpy extends ReminderController {
  ReminderSpy(MirrorService service)
    : super(
        service: service,
        account: 'synthetic',
        visibility: null,
        persist: false,
      );
  final updates = <HomeworkResponse>[];
  @override
  Future<void> restore() async {}
  @override
  Future<void> refresh({bool includeHomework = true}) async {}
  @override
  Future<void> reconcile() async {}
  @override
  Future<void> stop() async {}
  @override
  void updateHomework(HomeworkResponse data) {
    updates.add(data);
  }
}

Widget host(
  Widget child, {
  double scale = 1,
  Brightness brightness = Brightness.light,
}) => CupertinoApp(
  theme: CupertinoThemeData(brightness: brightness),
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(scale),
      disableAnimations: true,
    ),
    child: child,
  ),
);
Widget page(TodayFake service, {String account = 'a'}) => TodayPage(
  service: service,
  storageRoot: '/synthetic/tasks',
  accountName: '同名用户',
  accountId: account,
  now: () => DateTime.utc(2026, 10, 22, 1),
);
void size(WidgetTester tester, [Size value = const Size(430, 2200)]) {
  tester.view.physicalSize = value;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> clear(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  test('school clocks validate ranges, midnight and date-only deadlines', () {
    expect(todaySchoolNow(DateTime.utc(2026, 10, 21, 17)).day, 22);
    expect(todayDate('2026-02-30'), isNull);
    expect(TodayCourseWindow.parse('2026-10-22', '25:00-26:00'), isNull);
    expect(TodayCourseWindow.parse('2026-10-22', '08:00-08:00'), isNull);
    final cross = TodayCourseWindow.parse('2026-10-22', '23:30-00:20')!;
    expect(cross.ends.day, 23);
    expect(cross.status(DateTime.utc(2026, 10, 22, 23, 30)), '正在上课');
    expect(cross.status(DateTime.utc(2026, 10, 23, 0, 20)), '已结束');
    expect(todayDueLabel('2026-10-22', clock, localTask: true), '截止 今天（日期）');
    expect(
      todayDueLabel('2026-10-22', DateTime.utc(2026, 10, 23), localTask: true),
      '已截止 10月22日（日期）',
    );
    expect(todayDueLabel('2026-10-22T02:00:00Z', clock), '截止 今天 10:00');
    expect(
      todayCompareDue('2026-10-22T12:00:00+08:00', '2026-10-22'),
      lessThan(0),
    );
    expect(todayDueLabel('', clock, localTask: true), '无截止时间');
    expect(todayDueLabel(null, clock), '截止时间待确认');
    expect(todayDueLabel('invalid', clock), contains('待确认'));
  });

  testWidgets('focus selects ongoing before next and honors exact end', (
    tester,
  ) async {
    size(tester);
    const data = TodayResponse(
      date: '2026-10-22',
      courses: [
        TodayCourse(name: '下午课程', time: '14:00-15:00', place: '合成B楼'),
        TodayCourse(name: '上午课程', time: '08:00-09:00', place: '合成A楼'),
        TodayCourse(name: '未知课程'),
      ],
    );
    await tester.pumpWidget(
      host(
        TodayCourseFocus(
          data: data,
          now: DateTime.utc(2026, 10, 22, 8),
          onOpen: () {},
        ),
      ),
    );
    expect(find.text('上午课程'), findsOneWidget);
    expect(find.textContaining('正在上课'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('today-course-focus'))).height,
      greaterThanOrEqualTo(48),
    );
    await tester.pumpWidget(host(TodayCourseFocus(data: data, now: clock)));
    expect(find.text('下午课程'), findsOneWidget);
    expect(find.textContaining('下一节课'), findsOneWidget);
    await tester.pumpWidget(
      host(TodayCourseFocus(data: data, now: DateTime.utc(2026, 10, 22, 16))),
    );
    expect(find.text('部分课程时间待确认'), findsOneWidget);
    await tester.pumpWidget(
      host(TodayCourseFocus(data: data, now: DateTime.utc(2026, 10, 23))),
    );
    expect(find.text('课表日期待更新'), findsOneWidget);
  });

  testWidgets('an empty snapshot from yesterday is not today confirmed empty', (
    tester,
  ) async {
    size(tester);
    await tester.pumpWidget(
      host(
        TodayCourseSection(
          data: emptyCourses,
          now: DateTime.utc(2026, 10, 23),
          loading: false,
          error: null,
          expanded: false,
          onToggleExpanded: () {},
          onRetry: () {},
        ),
      ),
    );
    expect(find.text('今天没有课程'), findsNothing);
    expect(find.text('课表日期待更新'), findsOneWidget);
  });

  testWidgets(
    'homework sorts deadlines, opens exact item, never labels unknown empty',
    (tester) async {
      size(tester);
      final section = RefreshSection<HomeworkResponse>()
        ..value = const HomeworkResponse(
          termName: '',
          termCode: 'synthetic',
          items: [
            HomeworkItem(
              id: 'unknownDue',
              courseName: '课程',
              title: '无日期作业',
              status: HomeworkStatus.pending,
            ),
            HomeworkItem(
              id: 'late',
              courseName: '课程',
              title: '较晚作业',
              dueAt: '2026-10-23T12:00:00+08:00',
              status: HomeworkStatus.pending,
            ),
            HomeworkItem(
              id: 'soon',
              courseName: '课程',
              title: '近期作业',
              dueAt: '2026-10-22T12:00:00+08:00',
              status: HomeworkStatus.pending,
            ),
            HomeworkItem(
              id: 'assistant',
              courseRole: 'assistant',
              courseName: '课程',
              title: '助教作业',
              status: HomeworkStatus.pending,
            ),
          ],
        );
      HomeworkItem? opened;
      await tester.pumpWidget(
        host(
          TodayHomeworkSection(
            section: section,
            onRetry: () {},
            onOpenItem: (item) => opened = item,
            now: clock,
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.text('近期作业')).dy,
        lessThan(tester.getTopLeft(find.text('较晚作业')).dy),
      );
      expect(
        tester.getTopLeft(find.text('较晚作业')).dy,
        lessThan(tester.getTopLeft(find.text('无日期作业')).dy),
      );
      expect(find.text('助教作业'), findsNothing);
      expect(find.text('截止时间待确认'), findsOneWidget);
      await tester.tap(find.byKey(const Key('today-homework-item-soon')));
      expect(opened?.id, 'soon');
      section.value = const HomeworkResponse(
        termName: '',
        termCode: 's',
        items: [
          HomeworkItem(
            id: 'u',
            courseName: '课程',
            title: '未知',
            status: HomeworkStatus.unknown,
          ),
        ],
      );
      await tester.pumpWidget(
        host(
          TodayHomeworkSection(section: section, onRetry: () {}, now: clock),
        ),
      );
      expect(find.text('作业状态尚未确认'), findsOneWidget);
      expect(find.text('当前没有待处理作业'), findsNothing);
      section.dispose();
    },
  );

  testWidgets('homework shows the source snapshot time on a failed refresh', (
    tester,
  ) async {
    size(tester);
    final section = RefreshSection<HomeworkResponse>()
      ..value = const HomeworkResponse(
        termName: '合成学期',
        termCode: 'synthetic',
        items: [],
        fetchedAt: '2026-10-22T01:23:00Z',
      )
      ..error = '读取失败';
    await tester.pumpWidget(
      host(TodayHomeworkSection(section: section, onRetry: () {}, now: clock)),
    );
    expect(find.textContaining('作业同步：10月22日 09:23'), findsOneWidget);
    expect(find.text('读取失败'), findsOneWidget);
    expect(find.text('当前没有待处理作业'), findsNothing);
    section.dispose();
  });

  testWidgets('empty assignments still report incomplete course roles', (
    tester,
  ) async {
    size(tester);
    final section = RefreshSection<HomeworkResponse>()
      ..value = const HomeworkResponse(
        termName: '合成学期',
        termCode: 'synthetic',
        items: [],
        rolesComplete: false,
      );
    await tester.pumpWidget(
      host(TodayHomeworkSection(section: section, onRetry: () {}, now: clock)),
    );
    expect(find.text('作业结果不完整'), findsOneWidget);
    expect(find.textContaining('课程身份未能全部核对'), findsWidgets);
    expect(find.text('当前没有待处理作业'), findsNothing);
    section.dispose();
  });

  testWidgets(
    'tasks publish while school requests wait; missing payload is not zero',
    (tester) async {
      size(tester);
      final fake = TodayFake()
        ..holdCourses = true
        ..holdHomework = true
        ..local = tasksPayload([task('local', due: '2026-10-22')]);
      await tester.pumpWidget(host(page(fake)));
      await tester.pump();
      expect(find.text('事项local'), findsOneWidget);
      expect(find.text('正在读取今天课程…'), findsOneWidget);
      expect(find.text('正在检查学校作业…'), findsOneWidget);
      expect(fake.roots, ['/synthetic/tasks']);
      await clear(tester);
      final bad = TodayFake()..local = const ReadOnlyResponse(stale: false);
      await tester.pumpWidget(host(page(bad)));
      await tester.pumpAndSettle();
      expect(find.text('当前没有未完成待办'), findsNothing);
      expect(find.text('无法读取个人待办，请重试。'), findsOneWidget);
      await clear(tester);
    },
  );

  testWidgets(
    'tasks separate undated and completed and preserve old content on failed refresh',
    (tester) async {
      size(tester);
      final section = RefreshSection<TodayTasksSnapshot>()
        ..value = TodayTasksSnapshot([
          LocalTaskRecord.fromJson(task('date', due: '2026-10-22')),
          LocalTaskRecord.fromJson(task('none')),
          LocalTaskRecord.fromJson(task('done', completed: true)),
        ], clock);
      String? opened;
      await tester.pumpWidget(
        host(
          TodayTasksSection(
            section: section,
            now: clock,
            onRetry: () {},
            onOpen: (id) => opened = id,
          ),
        ),
      );
      expect(find.text('事项done'), findsNothing);
      expect(find.text('已完成 1 项'), findsOneWidget);
      expect(find.text('无截止时间'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('事项none')).dy,
        greaterThan(tester.getTopLeft(find.text('未设截止 / 时间待确认')).dy),
      );
      await tester.tap(find.byKey(const Key('today-task-date')));
      expect(opened, 'date');
      await section.refresh(
        () async => const SectionResult(error: '合成读取失败'),
        fallbackError: '失败',
      );
      await tester.pumpWidget(
        host(
          TodayTasksSection(
            section: section,
            now: clock,
            onRetry: () {},
            onOpen: (_) {},
          ),
        ),
      );
      expect(find.text('事项date'), findsOneWidget);
      expect(find.text('合成读取失败'), findsOneWidget);
      expect(find.text('显示上次读取结果，请重试确认。'), findsOneWidget);
      section.dispose();
    },
  );

  testWidgets(
    'linked tasks are hidden only when their homework row is visible',
    (tester) async {
      size(tester);
      LocalTaskRecord linked(String id, String assignment) => LocalTaskRecord(
        id: id,
        title: '本机$id',
        due: '',
        completed: false,
        sourceAssignmentId: assignment,
      );
      final section = RefreshSection<TodayTasksSnapshot>()
        ..value = TodayTasksSnapshot([
          linked('visible', 'assignment-visible'),
          linked('missing', 'assignment-missing'),
        ], clock);
      Widget view(Set<String> visible) => host(
        TodayTasksSection(
          section: section,
          now: clock,
          onRetry: () {},
          onOpen: (_) {},
          visibleHomeworkIds: visible,
        ),
      );
      await tester.pumpWidget(view({'assignment-visible'}));
      expect(find.text('本机visible'), findsNothing);
      expect(find.text('本机missing'), findsOneWidget);
      expect(find.text('已在学校作业区显示，不在此重复；可在待办页查看'), findsOneWidget);
      await tester.pumpWidget(view({}));
      expect(find.text('本机visible'), findsOneWidget);
      expect(find.text('本机missing'), findsOneWidget);
      expect(find.byKey(const Key('today-tasks-linked-note')), findsNothing);
      section.dispose();
    },
  );

  testWidgets(
    'same-name account switch discards late tasks and reminder side effects',
    (tester) async {
      size(tester);
      final fake = TodayFake()
        ..holdHomework = true
        ..holdTasks = true;
      final spy = ReminderSpy(fake);
      Widget scoped(String account) => host(
        ReminderScope(
          service: fake,
          account: 'synthetic',
          controllerFactory: (_, _, _) => spy,
          child: page(fake, account: account),
        ),
      );
      await tester.pumpWidget(scoped('a'));
      await tester.pump();
      await tester.pumpWidget(scoped('b'));
      await tester.pump();
      expect(fake.homeworkRequests.length, 2);
      expect(fake.taskRequests.length, 2);
      fake.homeworkRequests.first.complete(oneHomework);
      fake.taskRequests.first.complete(tasksPayload([task('old')]));
      await tester.pump();
      expect(spy.updates, isEmpty);
      expect(find.text('事项old'), findsNothing);
      fake.homeworkRequests.last.complete(emptyHomework);
      fake.taskRequests.last.complete(tasksPayload([task('new')]));
      await tester.pumpAndSettle();
      expect(spy.updates, [emptyHomework]);
      expect(find.text('事项new'), findsOneWidget);
      expect(find.text('事项old'), findsNothing);
      await clear(tester);
    },
  );

  testWidgets('tab reentry reloads only tasks, not school sections', (
    tester,
  ) async {
    size(tester);
    final fake = TodayFake();
    Widget tab(bool active) =>
        host(TickerMode(enabled: active, child: page(fake)));
    await tester.pumpWidget(tab(true));
    await tester.pumpAndSettle();
    expect(fake.taskReads, 1);
    await tester.pumpWidget(tab(false));
    await tester.pump();
    fake.local = tasksPayload([task('changed')]);
    await tester.pumpWidget(tab(true));
    await tester.pumpAndSettle();
    expect(fake.taskReads, 2);
    expect(fake.courseReads, 1);
    expect(fake.homeworkReads, 1);
    expect(find.text('事项changed'), findsOneWidget);
    await clear(tester);
  });

  testWidgets(
    'homework detail and targeted Tasks navigation reload tasks on return',
    (tester) async {
      size(tester);
      final fake = TodayFake()
        ..assignments = oneHomework
        ..local = tasksPayload([task('one')]);
      await tester.pumpWidget(host(page(fake)));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('today-homework-item-spoc:assignment-one')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeworkDetailPage), findsOneWidget);
      expect(fake.details, ['assignment-one']);
      expect(
        tester
            .widget<HomeworkDetailPage>(find.byType(HomeworkDetailPage))
            .storageRoot,
        '/synthetic/tasks',
      );
      expect(fake.roots.every((root) => root == '/synthetic/tasks'), isTrue);
      final beforeReturn = fake.taskReads;
      fake.local = tasksPayload([task('one'), task('linked')]);
      Navigator.of(tester.element(find.byType(HomeworkDetailPage))).pop();
      await tester.pumpAndSettle();
      expect(fake.taskReads, beforeReturn + 1);
      expect(find.text('事项linked'), findsOneWidget);
      await tester.tap(find.byKey(const Key('today-task-one')));
      await tester.pumpAndSettle();
      final target = tester.widget<TasksPage>(find.byType(TasksPage));
      expect(target.initialTaskId, 'one');
      expect(target.storageRoot, '/synthetic/tasks');
      Navigator.of(tester.element(find.byType(TasksPage))).pop();
      await tester.pumpAndSettle();
      expect(fake.taskReads, beforeReturn + 3);
      expect(fake.courseReads, 1);
      expect(fake.homeworkReads, 1);
      await clear(tester);
    },
  );

  testWidgets(
    '320dp large text dark and Windows wide layout expose readable semantic actions',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        for (final viewport in [
          const Size(320, 2400),
          const Size(1280, 1400),
        ]) {
          size(tester, viewport);
          final fake = TodayFake()
            ..assignments = oneHomework
            ..local = tasksPayload([task('a', due: '2026-10-22')]);
          await tester.pumpWidget(
            host(page(fake), scale: 2, brightness: Brightness.dark),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(const Key('today-task-a')));
          await tester.pumpAndSettle();
          final action = find.byKey(const Key('today-task-a'));
          expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
          expect(
            find.descendant(of: action, matching: find.byType(TodayActionRow)),
            findsNothing,
          );
          expect(find.text('事项a'), findsOneWidget);
          expect(find.bySemanticsLabel(RegExp('事项a')), findsOneWidget);
          expect(
            find.bySemanticsLabel(RegExp('截止.*事项a', dotAll: true)),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await clear(tester);
        }
      } finally {
        semantics.dispose();
      }
    },
  );
}
