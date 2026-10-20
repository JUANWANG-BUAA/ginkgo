import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

const empty = ClassroomResponse(
  buildings: [],
  roomCount: 0,
  buildingCount: 0,
  freeSlotCount: 0,
  fromCache: false,
);
const failure = ClassroomResponse(
  buildings: [],
  roomCount: 0,
  buildingCount: 0,
  freeSlotCount: 0,
  fromCache: false,
  failure: FailureCode.changedResponse,
);
final examples = RuleExamples(
  localDate: '2026-10-19',
  minutesSinceMidnight: 30,
  timeZone: 'Asia/Shanghai',
  cachedWeeks: Int32List.fromList([4, 5, 6]),
  selectedWeek: 5,
  courseNames: ['缓存第5周'],
);
final scheduleFixture = ScheduleResponse(
  terms: const [
    ScheduleTerm(id: '2026-2027-1', name: '2026-2027学年第1学期', selected: true),
  ],
  weeks: const [
    ScheduleWeek(
      number: 2,
      startDate: '2026-09-07',
      endDate: '2026-09-13',
      current: true,
    ),
    ScheduleWeek(
      number: 3,
      startDate: '2026-09-14',
      endDate: '2026-09-20',
      current: false,
    ),
  ],
  termId: '2026-2027-1',
  weekNumber: 2,
  courses: const [
    ScheduleCourse(
      id: 'u-0-1-1',
      name: '算法设计与分析',
      day: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:35',
      place: '新主楼A101',
      teacher: '1-16周 张三',
      color: '#4A90D9',
    ),
  ],
  exams: const [
    ScheduleExam(
      id: 'exam-1',
      courseName: '算法设计与分析',
      examDate: '2026-11-16',
      startTime: '08:00',
      endTime: '10:00',
      examPlace: '主楼A101',
      examSeatNo: '12',
    ),
  ],
);
final gradesFixture = GradeResponse(
  termId: '2026-2027-1',
  summary: const GradeSummary(
    courseCount: 2,
    creditTotal: 7,
    weightedAverage: 90.2857,
    gradePointAverage: 3.8157,
  ),
  courses: const [
    GradeCourse(id: 'b', name: '操作系统', credit: 3, score: '88', scoreValue: 88),
    GradeCourse(
      id: 'a',
      name: '算法设计与分析',
      code: 'CS101',
      credit: 4,
      score: '92',
      scoreValue: 92,
      scoreType: '百分制',
      courseType: '必修',
    ),
  ],
);
final todayFixture = TodayResponse(
  date: '2026-10-20',
  courses: const [
    TodayCourse(
      name: '算法设计与分析',
      place: '新主楼A101',
      time: '08:00-09:35',
      shortName: '算法',
    ),
  ],
);
final homeworkFixture = HomeworkResponse(
  termName: '2026-2027学年第1学期',
  termCode: '2026-2027-1',
  items: const [
    HomeworkItem(
      id: 'spoc:a',
      courseName: '软件工程',
      title: '作业一',
      status: HomeworkStatus.submitted,
      score: '100',
    ),
    HomeworkItem(
      id: 'spoc:b',
      courseName: 'SPOC 课程',
      title: '作业二',
      status: HomeworkStatus.pending,
    ),
  ],
);

class ControlledService implements MirrorService {
  final requests = <Completer<ClassroomResponse>>[];
  @override
  Future<QueryDates> dates(String instant) async =>
      const QueryDates(today: '2026-10-20', tomorrow: '2026-10-21');
  @override
  Future<ClassroomResponse> classrooms(DemoScope scope, ClassroomQuery query) {
    final completer = Completer<ClassroomResponse>();
    requests.add(completer);
    return completer.future;
  }

  @override
  Future<RuleExamples> rules() async => examples;

  @override
  Future<ScheduleResponse> schedule() async => scheduleFixture;

  @override
  Future<GradeResponse> grades() async => gradesFixture;

  @override
  Future<TodayResponse> today() async => todayFixture;

  @override
  Future<HomeworkResponse> homework() async => homeworkFixture;
}

Future<void> start(WidgetTester tester, ControlledService service) async {
  tester.view.physicalSize = const Size(430, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(GinkgoApp(service: service));
  await tester.pumpAndSettle();
  await tester.tap(find.text('空教室'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('查询空教室'));
  await tester.pump();
}

void main() {
  testWidgets('latest query wins when native responses finish out of order', (
    tester,
  ) async {
    final service = ControlledService();
    await start(tester, service);
    service.requests[0].complete(empty);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoSearchTextField), '101');
    await tester.enterText(find.byType(CupertinoSearchTextField), '不存在');
    service.requests.last.complete(empty);
    await tester.pumpAndSettle();
    service.requests[1].complete(failure);
    await tester.pumpAndSettle();
    expect(find.text('没有符合条件的空教室'), findsOneWidget);
    expect(find.text('数据格式无法识别，请重试'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('domain error is visible and retry can recover', (tester) async {
    final service = ControlledService();
    await start(tester, service);
    service.requests.single.complete(failure);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('重试'));
    await tester.tap(find.text('重试'));
    await tester.pump();
    service.requests.last.complete(empty);
    await tester.pumpAndSettle();
    expect(find.text('没有符合条件的空教室'), findsOneWidget);
    expect(find.text('数据格式无法识别，请重试'), findsNothing);
  });
  testWidgets('disposed page ignores an in-flight result', (tester) async {
    final service = ControlledService();
    await start(tester, service);
    service.requests.single.complete(empty);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoSearchTextField), '101');
    // A scope change is allowed after a pending filter result is superseded by
    // another interaction; refresh completion after disposal must also be safe.
    await tester.pumpWidget(const CupertinoApp(home: Text('其他页面')));
    service.requests.last.complete(failure);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('wide layout has a sidebar and rule examples', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GinkgoApp(service: ControlledService()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('规则示例'));
    await tester.pumpAndSettle();
    expect(find.text('2026-10-19 · Asia/Shanghai'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('floating campus menu remains accessible and applies selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GinkgoApp(service: ControlledService()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('空教室'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('校区'));
    await tester.pumpAndSettle();
    expect(find.text('沙河'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('沙河'));
    await tester.pumpAndSettle();
    expect(find.text('沙河'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('custom typography survives Cupertino navigation transitions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GinkgoApp(service: ControlledService()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('空教室'));
    await tester.pumpAndSettle();
    final rules = find.text('查看共享规则示例');
    await tester.ensureVisible(rules);
    await tester.tap(rules);
    await tester.pumpAndSettle();
    expect(find.text('共享规则示例'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('large text in dark mode has no layout overflow', (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GinkgoApp(service: ControlledService(), brightness: Brightness.dark),
    );
    await tester.pumpAndSettle();
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    final context = tester.element(find.text('空教室').first);
    expect(CupertinoTheme.brightnessOf(context), Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('schedule tab shows current week, courses and exams', (
    tester,
  ) async {
    final service = ControlledService();
    // Tall viewport keeps the whole timetable and exam section mounted so the
    // test can assert on grid blocks without extra scrolling.
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GinkgoApp(service: service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('课表'));
    await tester.pumpAndSettle();

    expect(find.text('2026-2027学年第1学期'), findsOneWidget);
    expect(
      find.byKey(const Key('schedule-grid-course-u-0-1-1')),
      findsOneWidget,
    );
    expect(find.text('考试安排'), findsOneWidget);
    expect(find.text('座位 12'), findsOneWidget);

    await tester.tap(find.byKey(const Key('schedule-grid-course-u-0-1-1')));
    await tester.pumpAndSettle();
    expect(find.text('关闭'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('列表'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('schedule-course-u-0-1-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('schedule-week-3')));
    await tester.pumpAndSettle();
    expect(find.text('该周课表尚未缓存'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('today tab shows date and today courses', (tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GinkgoApp(service: ControlledService()));
    await tester.pumpAndSettle();

    expect(find.text('2026年10月20日 · 周二'), findsOneWidget);
    expect(find.text('今天 1 节课'), findsOneWidget);
    expect(find.byKey(const Key('today-course-算法设计与分析')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grades tab shows summary and course scores', (tester) async {
    final service = ControlledService();
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GinkgoApp(service: service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('成绩'));
    await tester.pumpAndSettle();

    expect(find.text('加权平均'), findsOneWidget);
    expect(find.text('90.3'), findsOneWidget);
    expect(find.text('平均绩点'), findsOneWidget);
    expect(find.text('3.82'), findsOneWidget);
    expect(find.text('总学分'), findsOneWidget);
    expect(find.byKey(const Key('grade-course-a')), findsOneWidget);
    expect(find.byKey(const Key('grade-course-b')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('homework tab filters pending and submitted items', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GinkgoApp(service: ControlledService()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('作业'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('作业一'), findsOneWidget);
    expect(find.text('作业二'), findsOneWidget);

    await tester.tap(find.text('待完成').first);
    await tester.pumpAndSettle();
    expect(find.text('作业二'), findsOneWidget);
    expect(find.text('作业一'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
