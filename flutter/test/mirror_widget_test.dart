import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart'
    show GradeTermsResponse, RouteChoice, SessionResponse, SessionState;
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
    ScheduleTerm(id: '2025-2026-2', name: '2025-2026学年第2学期', selected: false),
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
final checkInFixture = CheckInResponse(
  date: '2026-10-20',
  courses: const [
    CheckInCourse(
      id: '501',
      courseName: '高等数学',
      beginsAt: '08:00',
      endsAt: '09:35',
      status: CheckInStatus.notSigned,
      teacherName: '张老师',
      classroomName: '主楼A101',
      mergedRecordCount: 1,
      conflicting: false,
    ),
    CheckInCourse(
      id: '502',
      courseName: '大学物理',
      beginsAt: '10:00',
      endsAt: '11:35',
      status: CheckInStatus.signed,
      teacherName: '李老师',
      classroomName: '主楼B202',
      mergedRecordCount: 2,
      conflicting: false,
    ),
    CheckInCourse(
      id: '503',
      courseName: '数据结构',
      beginsAt: '14:00',
      endsAt: '15:35',
      status: CheckInStatus.unknown,
      mergedRecordCount: 2,
      conflicting: true,
    ),
  ],
  fetchedAt: '2026-10-20T15:30:00+08:00',
  fromCache: false,
  stale: false,
);

const emptyCheckIn = CheckInResponse(
  date: '2026-10-20',
  courses: [],
  fromCache: false,
  stale: false,
);

final libraryVenuesFixture = LibraryVenuesResponse(
  venues: const [
    LibraryVenue(id: 'v1', name: '学院路馆', free: 12, total: 30),
    LibraryVenue(id: 'v2', name: '沙河馆', free: 0, total: 8),
  ],
  fetchedAt: '2026-10-20T15:30:00+08:00',
  fromCache: false,
  stale: false,
);

const libraryBookingsFixture = LibraryBookingsResponse(
  bookings: [
    LibraryBooking(
      id: 'b1',
      title: '学院路馆 · A区 · 12号',
      areaName: 'A区',
      seatNumber: '12',
      day: '2026-10-20',
      startTime: '08:00',
      endTime: '12:00',
      statusName: '使用中',
    ),
  ],
  fromCache: false,
  stale: false,
);

const libraryAreasFixture = LibraryAreasResponse(
  areas: [LibraryArea(id: 'a1', name: 'A区', free: 4, total: 20)],
);

const librarySlotsFixture = LibrarySlotsResponse(
  slots: [
    LibrarySlot(
      id: '2026-10-20/t1',
      day: '2026-10-20',
      start: '08:00',
      end: '10:00',
    ),
  ],
);

const librarySeatsFixture = LibrarySeatsResponse(
  seats: [
    LibrarySeat(id: 's1', name: 'A-01', statusName: '空闲', available: true),
    LibrarySeat(id: 's2', name: 'A-02', statusName: '已占用', available: false),
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
  String? requestedScheduleTerm;
  final requests = <Completer<ClassroomResponse>>[];
  final checkinRequests = <Completer<CheckInResponse>>[];
  LibraryVenuesResponse libraryVenuesResult = libraryVenuesFixture;
  LibraryBookingsResponse libraryBookingsResult = libraryBookingsFixture;
  LibraryAreasResponse libraryAreasResult = libraryAreasFixture;
  LibrarySlotsResponse librarySlotsResult = librarySlotsFixture;
  LibrarySeatsResponse librarySeatsResult = librarySeatsFixture;
  @override
  bool get isDemo => true;
  @override
  Future<SessionResponse> restoreSession() async =>
      const SessionResponse(state: SessionState.signedOut, remembered: false);
  @override
  Future<SessionResponse> login({
    required String account,
    required String password,
    String? captcha,
    required bool remember,
  }) async =>
      const SessionResponse(state: SessionState.signedIn, remembered: false);
  @override
  Future<SessionResponse> setRoute(RouteChoice route) async =>
      const SessionResponse(state: SessionState.signedOut, remembered: false);
  @override
  Future<bool> clearCache() async => true;
  @override
  Future<SessionResponse> signOut() async =>
      const SessionResponse(state: SessionState.signedOut, remembered: false);
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
  Future<ScheduleResponse> schedule({
    String? termId,
    int? week,
    bool forceRefresh = false,
  }) async {
    requestedScheduleTerm = termId;
    return ScheduleResponse(
      terms: scheduleFixture.terms,
      weeks: scheduleFixture.weeks,
      termId: termId ?? scheduleFixture.termId,
      weekNumber: scheduleFixture.weekNumber,
      courses: scheduleFixture.courses,
      exams: scheduleFixture.exams,
    );
  }

  @override
  Future<GradeTermsResponse> gradeTerms() async => const GradeTermsResponse(
    terms: [
      ScheduleTerm(id: '2026-2027-1', name: '2026-2027学年第1学期', selected: true),
    ],
  );

  @override
  Future<GradeResponse> grades({
    String? termCode,
    bool forceRefresh = false,
  }) async => gradesFixture;

  @override
  Future<TodayResponse> today({bool forceRefresh = false}) async =>
      todayFixture;

  @override
  Future<CheckInResponse> checkin({bool forceRefresh = false}) {
    final completer = Completer<CheckInResponse>();
    checkinRequests.add(completer);
    return completer.future;
  }

  @override
  Future<LibraryVenuesResponse> libraryVenues({
    bool forceRefresh = false,
  }) async => libraryVenuesResult;
  @override
  Future<LibraryAreasResponse> libraryAreas(String libraryId) async =>
      libraryAreasResult;
  @override
  Future<LibrarySlotsResponse> librarySlots(String areaId) async =>
      librarySlotsResult;
  @override
  Future<LibrarySeatsResponse> librarySeats({
    required String areaId,
    required LibrarySlot slot,
  }) async => librarySeatsResult;
  @override
  Future<LibraryBookingsResponse> libraryBookings({
    bool forceRefresh = false,
  }) async => libraryBookingsResult;

  @override
  Future<HomeworkResponse> homework() async => homeworkFixture;
}

Future<void> openMore(WidgetTester tester, String label) async {
  await tester.tap(find.text('更多'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> start(WidgetTester tester, ControlledService service) async {
  tester.view.physicalSize = const Size(430, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(GinkgoApp(service: service));
  await tester.pumpAndSettle();
  await openMore(tester, '空教室');
  await tester.tap(find.text('查询空教室'));
  await tester.pump();
}

Future<void> openCheckin(WidgetTester tester, ControlledService service) async {
  tester.view.physicalSize = const Size(430, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(GinkgoApp(service: service));
  await tester.pumpAndSettle();
  await tester.tap(find.text('更多'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('课程签到'));
  // The page starts loading immediately; a repeating spinner would make
  // pumpAndSettle time out, so drive the route transition explicitly.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
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
    await openMore(tester, '空教室');
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
    await openMore(tester, '空教室');
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
    final context = tester.element(find.text('更多').first);
    expect(CupertinoTheme.brightnessOf(context), Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'schedule term switching, detail and unavailable week preserve courses',
    (tester) async {
      final service = ControlledService();
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(GinkgoApp(service: service));
      await tester.pumpAndSettle();
      await tester.tap(find.text('课表'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('schedule-course-u-0-1-1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('schedule-course-u-0-1-1')));
      await tester.pumpAndSettle();
      expect(find.text('课程详情'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026-2027学年第1学期'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2025-2026学年第2学期'));
      await tester.pumpAndSettle();
      expect(service.requestedScheduleTerm, '2025-2026-2');
      expect(find.text('2025-2026学年第2学期'), findsOneWidget);
      await tester.tap(find.byKey(const Key('schedule-week-3')));
      await tester.pumpAndSettle();
      expect(find.textContaining('第 3 周尚未缓存'), findsOneWidget);
      expect(find.byKey(const Key('schedule-course-u-0-1-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'schedule search matches teacher/place and has a clear empty state',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(GinkgoApp(service: ControlledService()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('课表'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('schedule-search')), '张三');
      await tester.pumpAndSettle();
      expect(find.text('算法设计与分析'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('schedule-search')), '不存在');
      await tester.pumpAndSettle();
      expect(find.text('没有匹配的课程'), findsOneWidget);
      expect(find.text('算法设计与分析'), findsNothing);
      await tester.enterText(find.byKey(const Key('schedule-search')), '');
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('today tab shows date and today courses', (tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GinkgoApp(service: ControlledService()));
    await tester.pumpAndSettle();

    expect(find.text('2026年10月20日 · 周二'), findsOneWidget);
    expect(find.text('今天 1 节课'), findsOneWidget);
    expect(find.byKey(const Key('today-course-0-算法设计与分析')), findsOneWidget);
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
    await openMore(tester, '成绩');

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

  testWidgets('library tab shows current bookings and venues', (tester) async {
    final service = ControlledService();
    tester.view.physicalSize = const Size(430, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GinkgoApp(service: service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('图书馆'));
    await tester.pumpAndSettle();

    expect(find.text('当前预约'), findsOneWidget);
    expect(find.text('学院路馆 · A区 · 12号'), findsOneWidget);
    expect(find.text('使用中'), findsOneWidget);
    expect(find.text('选择场馆'), findsOneWidget);
    expect(find.text('空闲 12 / 30'), findsOneWidget);
    expect(find.textContaining('仅用于演示只读座位层级'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('library drills from venue to area, slot and seats', (
    tester,
  ) async {
    final service = ControlledService();
    tester.view.physicalSize = const Size(430, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GinkgoApp(service: service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('图书馆'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('library-venue-v1')));
    await tester.pumpAndSettle();
    expect(find.text('区域'), findsOneWidget);
    expect(find.text('空闲 4 / 20'), findsOneWidget);

    await tester.tap(find.byKey(const Key('library-area-a1')));
    await tester.pumpAndSettle();
    expect(find.text('时段'), findsOneWidget);
    expect(find.text('08:00–10:00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('library-slot-2026-10-20/t1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-seat-s1')), findsOneWidget);
    expect(find.text('A-01'), findsOneWidget);
    expect(find.text('空闲'), findsOneWidget);
    expect(find.text('已占用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('library empty state is explicit, not an error', (tester) async {
    final service = ControlledService()
      ..libraryVenuesResult = const LibraryVenuesResponse(
        venues: [],
        fromCache: false,
        stale: false,
      )
      ..libraryBookingsResult = const LibraryBookingsResponse(
        bookings: [],
        fromCache: false,
        stale: false,
      );
    tester.view.physicalSize = const Size(430, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GinkgoApp(service: service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('图书馆'));
    await tester.pumpAndSettle();

    expect(find.text('当前没有进行中的预约'), findsOneWidget);
    expect(find.text('暂无可用场馆'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkin shows the day, statuses and read-only boundary', (
    tester,
  ) async {
    final service = ControlledService();
    await openCheckin(tester, service);
    service.checkinRequests.single.complete(checkInFixture);
    await tester.pumpAndSettle();

    expect(find.text('2026年10月20日 · 周二'), findsOneWidget);
    expect(find.text('今天 3 节课'), findsOneWidget);
    expect(find.text('已签到 1 · 未签到 1 · 待确认 1'), findsOneWidget);
    expect(find.text('核对 15:30'), findsOneWidget);
    expect(find.text('高等数学'), findsOneWidget);
    expect(find.text('未签到'), findsOneWidget);
    expect(find.text('已签到'), findsOneWidget);
    expect(find.text('待确认'), findsOneWidget);
    expect(find.textContaining('合并 2 条'), findsWidgets);
    expect(find.textContaining('记录不一致'), findsWidgets);
    expect(find.textContaining('仅用于演示只读签到页'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkin empty day is an empty state, not an error', (
    tester,
  ) async {
    final service = ControlledService();
    await openCheckin(tester, service);
    service.checkinRequests.single.complete(emptyCheckIn);
    await tester.pumpAndSettle();

    expect(find.text('今天没有课程'), findsWidgets);
    expect(find.textContaining('仅用于演示只读签到页'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkin failure is visible and retry can recover', (
    tester,
  ) async {
    final service = ControlledService();
    await openCheckin(tester, service);
    service.checkinRequests.single.complete(
      const CheckInResponse(
        date: '2026-10-20',
        courses: [],
        fromCache: false,
        stale: false,
        failure: FailureCode.changedResponse,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('数据格式无法识别，请重试'), findsOneWidget);
    await tester.ensureVisible(find.text('重试'));
    await tester.tap(find.text('重试'));
    await tester.pump();
    service.checkinRequests.last.complete(checkInFixture);
    await tester.pumpAndSettle();
    expect(find.text('高等数学'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkin keeps the last snapshot when a refresh fails', (
    tester,
  ) async {
    final service = ControlledService();
    await openCheckin(tester, service);
    service.checkinRequests.single.complete(checkInFixture);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.refresh));
    await tester.pump();
    service.checkinRequests.last.complete(
      CheckInResponse(
        date: '2026-10-20',
        courses: checkInFixture.courses,
        fetchedAt: checkInFixture.fetchedAt,
        fromCache: true,
        stale: true,
        failure: FailureCode.serviceUnavailable,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('正在显示上次结果'), findsOneWidget);
    expect(find.text('高等数学'), findsOneWidget);
    expect(find.text('待确认'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
