import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/apple_widgets.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';
import 'package:ginkgo_mirror/today_page.dart';

import 'mirror_widget_test.dart' show ControlledService;
import 'session_widget_test.dart' show FakeService, signedOut;

class WorkspaceService extends ControlledService {
  int scheduleReads = 0;
  int libraryReads = 0;
  TodayResponse result = const TodayResponse(
    date: '2026-10-21',
    courses: [
      TodayCourse(name: '合成课程名称', time: '08:00–09:35', place: '合成教学楼 101'),
    ],
    fetchedAt: '2026-10-21T00:03:00Z',
  );

  @override
  Future<TodayResponse> today({bool forceRefresh = false}) async => result;

  @override
  Future<ScheduleResponse> schedule({
    String? termId,
    int? week,
    bool forceRefresh = false,
  }) {
    scheduleReads++;
    return super.schedule(
      termId: termId,
      week: week,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<LibraryVenuesResponse> libraryVenues({bool forceRefresh = false}) {
    libraryReads++;
    return super.libraryVenues(forceRefresh: forceRefresh);
  }
}

void viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'Android back remains handled after login switches into the demo app',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      viewport(tester, const Size(430, 932));
      final backSignals = <bool>[];
      var exits = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
            backSignals.add(call.arguments as bool);
          }
          if (call.method == 'SystemNavigator.pop') exits++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        GinkgoRoot(
          liveService: FakeService(
            restoreResponse: signedOut,
            loginResponse: signedOut,
          ),
          demoService: WorkspaceService(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('先看看离线演示'));
      await tester.pumpAndSettle();
      expect(backSignals.last, isTrue);
      backSignals.clear();
      await tester.tap(find.text('预约').last);
      await tester.pumpAndSettle();
      expect(backSignals, everyElement(isTrue));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(exits, 0);
      expect(find.text('查看完整课表'), findsOneWidget);
      expect(backSignals.last, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets('Android back returns to workspace before a guarded exit', (
    tester,
  ) async {
    viewport(tester, const Size(430, 932));
    var exits = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.pop') exits++;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(GinkgoApp(service: WorkspaceService()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('课表').last);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('查看完整课表'), findsOneWidget);
    expect(find.text('再返回一次退出 Ginkgo'), findsNothing);
    expect(exits, 0);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('再返回一次退出 Ginkgo'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(exits, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'Android detail back, timeout and tab changes never leak exit state',
    (tester) async {
      viewport(tester, const Size(430, 932));
      await tester.pumpWidget(GinkgoApp(service: WorkspaceService()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('作业').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('homework-spoc:a')));
      await tester.pumpAndSettle();
      expect(find.text('作业详情'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('作业详情'), findsNothing);
      expect(find.text('再返回一次退出 Ginkgo'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('再返回一次退出 Ginkgo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('再返回一次退出 Ginkgo'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      // Changing tabs cancels a pending exit window.
      await tester.tap(find.text('课表').last);
      await tester.pumpAndSettle();
      expect(find.text('再返回一次退出 Ginkgo'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('desktop details retain their sidebar and independent history', (
    tester,
  ) async {
    viewport(tester, const Size(1280, 1000));
    final service = WorkspaceService();
    await tester.pumpWidget(GinkgoApp(service: service));
    await tester.pumpAndSettle();
    expect(service.scheduleReads, 0);
    expect(service.libraryReads, 0);
    await tester.tap(find.text('图书馆'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-venue-v1')));
    await tester.pumpAndSettle();
    expect(find.text('区域'), findsOneWidget);
    expect(find.text('课表'), findsOneWidget);
    await tester.tap(find.text('课表'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('schedule-search')), findsOneWidget);
    await tester.tap(find.text('图书馆'));
    await tester.pumpAndSettle();
    expect(find.text('区域'), findsOneWidget);
    expect(service.libraryReads, 1);
    await tester.tap(find.byKey(const Key('library-area-a1')));
    await tester.pumpAndSettle();
    // One system back pops one detail, even with the sidebar visible.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('区域'), findsOneWidget);
    expect(find.byKey(const Key('library-area-a1')), findsOneWidget);
    // Selecting the visible destination again returns to its root.
    await tester.tap(find.text('图书馆'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-venue-v1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('workspace puts course times before compact service entries', (
    tester,
  ) async {
    viewport(tester, const Size(430, 932));
    await tester.pumpWidget(GinkgoApp(service: WorkspaceService()));
    await tester.pumpAndSettle();
    final course = find.byKey(const Key('today-course-0-合成课程名称'));
    expect(tester.getRect(course).top, lessThan(400));
    expect(
      tester.getRect(course).top,
      lessThan(tester.getRect(find.text('课程签到')).top),
    );
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('09:35'), findsOneWidget);
    expect(find.text('课表同步：10月21日 08:03'), findsOneWidget);
    await tester.tap(find.text('查看完整课表'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('schedule-search')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('windows smoke destinations preserve homework across settings', (
    tester,
  ) async {
    viewport(tester, const Size(1280, 900));
    await tester.pumpWidget(GinkgoApp(service: WorkspaceService()));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Row).first).width, 1280);
    await tester.tap(find.byKey(const Key('desktop-sidebar-grades')));
    await tester.pumpAndSettle();
    expect(find.text('90.3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('desktop-sidebar-homework')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('homework-spoc:a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('desktop-sidebar')), findsOneWidget);
    expect(find.text('作业详情'), findsOneWidget);
    await tester.tap(find.byKey(const Key('desktop-sidebar-grades')));
    await tester.pumpAndSettle();
    expect(find.text('90.3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('desktop-sidebar-homework')));
    await tester.pumpAndSettle();
    expect(find.text('作业详情'), findsOneWidget);
    await tester.tap(find.byKey(const Key('desktop-sidebar-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-scroll')), findsOneWidget);
    await tester.tap(find.byKey(const Key('desktop-sidebar-homework')));
    await tester.pumpAndSettle();
    expect(find.text('作业详情'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'large course text preserves its time, location and missing data',
    (tester) async {
      viewport(tester, const Size(320, 1000));
      final service = WorkspaceService()
        ..result = const TodayResponse(
          date: '2026-10-21',
          courses: [TodayCourse(name: '这是一门用于验证大字号完整换行的合成课程名称')],
        );
      await tester.pumpWidget(
        ginkgoApp(
          brightness: Brightness.dark,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.8),
                disableAnimations: true,
              ),
              child: TodayPage(service: service),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('时间未提供'), findsOneWidget);
      expect(find.text('地点未提供'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop navigation responds to keyboard focus and activation', (
    tester,
  ) async {
    var activated = 0;
    await tester.pumpWidget(
      ginkgoApp(
        home: Center(
          child: SizedBox(
            width: 220,
            child: AppleNavigationItem(
              title: '课程签到',
              icon: CupertinoIcons.checkmark_seal,
              selected: false,
              onPressed: () => activated++,
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(activated, 1);
    final decoration =
        tester
                .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                .decoration
            as BoxDecoration;
    expect((decoration.border! as Border).top.color.a, 1);
    expect(tester.takeException(), isNull);
  });
}
