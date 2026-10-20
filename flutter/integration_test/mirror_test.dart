import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart'
    show GradeTermsResponse, RouteChoice, SessionResponse, SessionState;
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart';

const native = DemoMirrorService();

class FailOnceNativeService implements MirrorService {
  bool first = true;
  @override
  bool get isDemo => true;
  @override
  Future<SessionResponse> restoreSession() => native.restoreSession();
  @override
  Future<SessionResponse> login({
    required String account,
    required String password,
    String? captcha,
    required bool remember,
  }) => native.login(
    account: account,
    password: password,
    captcha: captcha,
    remember: remember,
  );
  @override
  Future<SessionResponse> setRoute(RouteChoice route) async =>
      const SessionResponse(state: SessionState.signedOut, remembered: false);
  @override
  Future<bool> clearCache() async => true;
  @override
  Future<SessionResponse> signOut() => native.signOut();
  @override
  Future<QueryDates> dates(String instant) => native.dates(instant);
  @override
  Future<ClassroomResponse> classrooms(DemoScope scope, ClassroomQuery query) {
    if (first) {
      first = false;
      return queryDemoClassrooms(
        scope: scope,
        query: const ClassroomQuery(
          search: '',
          section: 15,
          minimumFreeSections: 0,
          minimumConsecutiveSections: 0,
          sort: ClassroomSort.name,
        ),
      );
    }
    return native.classrooms(scope, query);
  }

  @override
  Future<RuleExamples> rules() => native.rules();
  @override
  Future<ScheduleResponse> schedule({bool forceRefresh = false}) =>
      native.schedule(forceRefresh: forceRefresh);
  @override
  Future<GradeTermsResponse> gradeTerms() => native.gradeTerms();
  @override
  Future<GradeResponse> grades({String? termCode, bool forceRefresh = false}) =>
      native.grades(termCode: termCode, forceRefresh: forceRefresh);
  @override
  Future<TodayResponse> today({bool forceRefresh = false}) =>
      native.today(forceRefresh: forceRefresh);
  @override
  Future<CheckInResponse> checkin({bool forceRefresh = false}) =>
      native.checkin(forceRefresh: forceRefresh);

  @override
  Future<LibraryVenuesResponse> libraryVenues({bool forceRefresh = false}) =>
      native.libraryVenues(forceRefresh: forceRefresh);
  @override
  Future<LibraryAreasResponse> libraryAreas(String libraryId) =>
      native.libraryAreas(libraryId);
  @override
  Future<LibrarySlotsResponse> librarySlots(String areaId) =>
      native.librarySlots(areaId);
  @override
  Future<LibrarySeatsResponse> librarySeats({
    required String areaId,
    required LibrarySlot slot,
  }) => native.librarySeats(areaId: areaId, slot: slot);
  @override
  Future<LibraryBookingsResponse> libraryBookings({
    bool forceRefresh = false,
  }) => native.libraryBookings(forceRefresh: forceRefresh);
  @override
  Future<HomeworkResponse> homework() => native.homework();
}

Future<void> launchClassroom(
  WidgetTester tester, {
  MirrorService service = native,
}) async {
  await launch(tester, service: service);
  await tapMore(tester, '空教室');
}

late IntegrationTestWidgetsFlutterBinding binding;
bool surfaceConverted = false;
bool captureUnavailable = false;
Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('GINKGO_CAPTURE') ||
      !Platform.isAndroid ||
      captureUnavailable) {
    return;
  }
  if (!surfaceConverted) {
    // On some emulator/plugin combinations the Android image-surface channel
    // never answers. Do not let a visual aid block the functional suite.
    try {
      await binding.convertFlutterSurfaceToImage().timeout(
        const Duration(seconds: 15),
      );
    } on Exception catch (error) {
      captureUnavailable = true;
      debugPrint('Screenshot surface unavailable: $error');
      return;
    }
    surfaceConverted = true;
  }
  await settle(tester);
  try {
    await binding.takeScreenshot(name).timeout(const Duration(seconds: 15));
  } on Exception catch (error) {
    captureUnavailable = true;
    debugPrint('Screenshot capture failed: $error');
  }
}

Future<void> select(WidgetTester tester, String field, String value) async {
  debugPrint('MIRROR_SELECT $field -> $value');
  await tap(tester, field);
  final menu = find.byType(ListView).last;
  // Scope to the menu and do not call `.last` before scrolling: lazy list
  // children beyond the viewport are not built yet, and `.last` throws on an
  // empty finder instead of letting `dragUntilVisible` scroll.
  final option = find.descendant(of: menu, matching: find.text(value));
  await tester.dragUntilVisible(
    option,
    menu,
    const Offset(0, -80),
    maxIteration: 30,
  );
  await Scrollable.ensureVisible(
    tester.element(option.last),
    alignment: 0.5,
    duration: const Duration(milliseconds: 100),
  );
  await settle(tester);
  await tester.tap(option.last);
  await settle(tester);
  debugPrint('MIRROR_SELECT done $field -> $value');
}

Future<void> expectSummary(WidgetTester tester, String expected) async {
  await show(tester, find.byKey(const Key('classroom-summary')));
  expect(find.text(expected), findsOneWidget);
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Live mode otherwise only pumps on engine frame requests, which can stall
  // `pump` after a platform-channel interaction on the emulator.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUp(() {
    surfaceConverted = false;
    captureUnavailable = false;
  });
  setUpAll(() async => RustLib.init());

  testWidgets(
    'shared fixture crosses real FFI with typed results and fourteen section states',
    (tester) async {
      final result = await loadDemoClassrooms(
        query: const ClassroomQuery(
          search: '',
          section: 0,
          minimumFreeSections: 3,
          minimumConsecutiveSections: 0,
          sort: ClassroomSort.availability,
        ),
      );
      expect(result.failure, isNull);
      expect(result.roomCount, 3);
      expect(result.freeSlotCount, 12);
      expect(result.buildings.first.rooms.first.sectionStates.length, 14);
      final sorted = await loadDemoClassrooms(
        query: const ClassroomQuery(
          search: '',
          section: 0,
          minimumFreeSections: 3,
          minimumConsecutiveSections: 0,
          building: '主楼',
          sort: ClassroomSort.consecutive,
        ),
      );
      expect(sorted.buildings.single.rooms.map((r) => r.id), ['A102', 'A101']);

      // Search runs through the same Rust filter path; the widget suite covers
      // the text field and clear affordance without relying on Android IME
      // automation, which is flaky on this emulator.
      final searched = await loadDemoClassrooms(
        query: const ClassroomQuery(
          search: '101',
          section: 0,
          minimumFreeSections: 0,
          minimumConsecutiveSections: 0,
          sort: ClassroomSort.name,
        ),
      );
      expect(searched.roomCount, 1);
      final noMatch = await loadDemoClassrooms(
        query: const ClassroomQuery(
          search: 'no-match',
          section: 0,
          minimumFreeSections: 0,
          minimumConsecutiveSections: 0,
          sort: ClassroomSort.name,
        ),
      );
      expect(noMatch.roomCount, 0);
    },
  );

  testWidgets('initial query, classroom detail and back navigation', (
    tester,
  ) async {
    debugPrint('MIRROR_STEP launch');
    await launchClassroom(tester);
    debugPrint('MIRROR_STEP initial-state');
    await capture(tester, 'classroom-initial');
    await show(tester, find.text('选择范围后查询'));
    expect(find.text('选择范围后查询'), findsOneWidget);
    debugPrint('MIRROR_STEP query');
    await tap(tester, '查询空教室');
    debugPrint('MIRROR_STEP summary');
    await expectSummary(tester, '3 间 · 1 栋');
    await capture(tester, 'classroom-results');
    debugPrint('MIRROR_STEP detail');
    await tap(tester, '101');
    expect(find.text('节次状态'), findsOneWidget);
    await capture(tester, 'classroom-detail');
    for (var n = 1; n <= 14; n++) {
      expect(find.text('第 $n 节'), findsOneWidget);
    }
    expect(find.textContaining('不代表已确认占用'), findsOneWidget);
    debugPrint('MIRROR_STEP back');
    // `WidgetTester.pageBack` ends with `pumpAndSettle`, which can wait on
    // the Android IME/route ticker. Tap the Cupertino back button directly.
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await settle(tester);
    debugPrint('MIRROR_STEP done');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all section options, minimum slots, consecutive slots and all sort modes',
    (tester) async {
      await launchClassroom(tester);
      debugPrint('MIRROR_STEP sections query');
      await tap(tester, '查询空教室');
      await tap(tester, '筛选与排序');
      for (var n = 1; n <= 14; n++) {
        await select(tester, '空闲节次', '第 $n 节');
        final expectedCount = n == 1
            ? 3
            : n == 2
            ? 2
            : n == 3
            ? 2
            : (n == 5 || n == 7)
            ? 1
            : 0;
        await expectSummary(
          tester,
          '$expectedCount 间 · ${expectedCount == 0 ? 0 : 1} 栋',
        );
      }
      await select(tester, '空闲节次', '任意节次');
      for (final n in [3, 5, 8, 0]) {
        await select(tester, '最少空闲', n == 0 ? '不限制' : '至少 $n 节');
        await expectSummary(
          tester,
          '${n == 0
              ? 3
              : n == 3
              ? 2
              : 0} 间 · ${n >= 5 ? 0 : 1} 栋',
        );
      }
      for (final n in [2, 4, 0]) {
        await select(tester, '连续空闲', n == 0 ? '不限制' : '至少 $n 节');
        await expectSummary(
          tester,
          '${n == 0
              ? 3
              : n == 2
              ? 2
              : 0} 间 · ${n == 4 ? 0 : 1} 栋',
        );
      }
      for (final label in ['空闲节数优先', '连续空闲优先', '教室名称']) {
        await select(tester, '排序', label);
        await expectSummary(tester, '3 间 · 1 栋');
      }
      await select(tester, '最少空闲', '至少 3 节');
      await select(tester, '连续空闲', '至少 2 节');
      await expectSummary(tester, '1 间 · 1 栋');
      await tap(tester, '清除筛选');
      await expectSummary(tester, '3 间 · 1 栋');
    },
  );

  testWidgets(
    'campuses, date picker, today/tomorrow, cache reuse and force refresh',
    (tester) async {
      await launchClassroom(tester);
      await tap(tester, '查询空教室');
      await select(tester, '校区', '沙河');
      await show(tester, find.text('选择范围后查询'));
      await tap(tester, '查询空教室');
      await expectSummary(tester, '2 间 · 1 栋');
      await select(tester, '校区', '杭州');
      await tap(tester, '查询空教室');
      await expectSummary(tester, '0 间 · 0 栋');
      await select(tester, '校区', '学院路');
      await tester.tap(find.byKey(const Key('classroom-shortcut-明天')));
      await settle(tester);
      await tap(tester, '查询空教室');
      await expectSummary(tester, '3 间 · 1 栋');
      await tester.tap(find.byKey(const Key('classroom-shortcut-今天')));
      await settle(tester);
      await tap(tester, '日期');
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      await tester.tap(find.text('完成'));
      await settle(tester);
      await tap(tester, '查询空教室');
      await tap(tester, '查询空教室');
      await show(tester, find.text('本机样例缓存'));
      expect(find.text('本机样例缓存'), findsOneWidget);
      // The toolbar refresh bypasses the Rust repository TTL.
      final refresh = find.bySemanticsLabel('刷新空教室');
      await tester.tap(refresh);
      await settle(tester);
      await expectSummary(tester, '3 间 · 1 栋');
      expect(find.text('合成样例'), findsOneWidget);
      await tap(tester, '查询空教室');
      await show(tester, find.text('本机样例缓存'));
      await tester.fling(
        find.byKey(const Key('classroom-scroll')),
        const Offset(0, 1400),
        1600,
      );
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await expectSummary(tester, '3 间 · 1 栋');
      expect(find.text('合成样例'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stable native failure code is shown and retry restores the query',
    (tester) async {
      await launchClassroom(tester, service: FailOnceNativeService());
      await tap(tester, '查询空教室');
      await show(tester, find.text('查询或筛选条件无效，请调整后重试'));
      expect(find.text('查询或筛选条件无效，请调整后重试'), findsOneWidget);
      await capture(tester, 'classroom-error');
      await tap(tester, '重试');
      await expectSummary(tester, '3 间 · 1 栋');
    },
  );

  testWidgets(
    'Beijing day and retained schedule weeks appear through native bridge',
    (tester) async {
      await launchClassroom(tester);
      await tap(tester, '查看共享规则示例');
      expect(find.text('2026-10-19 · Asia/Shanghai'), findsOneWidget);
      expect(find.text('30 分钟'), findsOneWidget);
      expect(find.text('4、5、6'), findsOneWidget);
      expect(find.text('第 5 周'), findsOneWidget);
      expect(find.text('缓存第5周'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'schedule tab crosses real FFI with week, course and exam states',
    (tester) async {
      await launch(tester);
      await tapTab(tester, '课表');
      await show(
        tester,
        find.text('2026-2027学年第1学期'),
        scrollKey: 'schedule-scroll',
      );
      expect(find.text('算法设计与分析'), findsNWidgets(2));
      expect(find.text('考试安排'), findsOneWidget);
      await tap(tester, '第 3 周', scrollKey: 'schedule-scroll');
      await show(tester, find.text('该周课表尚未缓存'), scrollKey: 'schedule-scroll');
      expect(find.text('该周课表尚未缓存'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('dark appearance and large text retain query and detail access', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      GinkgoApp(key: UniqueKey(), brightness: Brightness.dark),
    );
    await settle(tester);
    await tapMore(tester, '空教室');
    await tap(tester, '查询空教室');
    await expectSummary(tester, '3 间 · 1 栋');
    await capture(tester, 'classroom-dark-large');
    await tap(tester, '101');
    expect(find.text('节次状态'), findsOneWidget);
    await capture(tester, 'classroom-detail-dark-large');
    expect(tester.takeException(), isNull);
  });
}
