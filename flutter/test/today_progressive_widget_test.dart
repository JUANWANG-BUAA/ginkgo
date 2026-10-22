import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/diagnostic_log.dart';
import 'package:ginkgo_mirror/loading_widgets.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/today_page.dart';

import 'mirror_widget_test.dart' show ControlledService, todayFixture;

class ProgressiveService extends ControlledService {
  @override
  Future<ReadOnlyResponse> editTasks({
    required String root,
    required String action,
    String? id,
    String? title,
    String? due,
    bool? completed,
  }) async => const ReadOnlyResponse(stale: false, payload: '[]');
  final courses = <Completer<TodayResponse>>[];
  final assignments = <Completer<HomeworkResponse>>[];
  final forceCourses = <bool>[];
  final forceAssignments = <bool>[];

  @override
  Future<TodayResponse> today({bool forceRefresh = false}) {
    forceCourses.add(forceRefresh);
    final request = Completer<TodayResponse>();
    courses.add(request);
    return request.future;
  }

  @override
  Future<HomeworkResponse> homework({bool forceRefresh = false}) {
    forceAssignments.add(forceRefresh);
    final request = Completer<HomeworkResponse>();
    assignments.add(request);
    return request.future;
  }
}

const assignments = HomeworkResponse(
  termName: '合成学期',
  termCode: 'synthetic-term',
  items: [
    HomeworkItem(
      id: 'one',
      courseName: '合成课程',
      title: '合成作业',
      status: HomeworkStatus.pending,
    ),
    HomeworkItem(
      id: 'two',
      courseRole: 'assistant',
      courseName: '助教课程',
      title: '助教作业',
      status: HomeworkStatus.pending,
    ),
    HomeworkItem(
      id: 'three',
      courseName: '合成课程',
      title: '待确认作业',
      status: HomeworkStatus.unknown,
    ),
  ],
);

void size(WidgetTester tester, Size value) {
  tester.view.physicalSize = value;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('successful section loading never creates an error hint', (
    tester,
  ) async {
    DiagnosticLog.shared.entries.clear();
    DiagnosticLog.shared.current = null;
    final service = ProgressiveService();
    await tester.pumpWidget(
      ginkgoApp(
        home: TodayPage(storageRoot: '/synthetic/tasks', service: service),
      ),
    );
    expect(DiagnosticLog.shared.entries, isEmpty);
    service.courses.single.complete(todayFixture);
    service.assignments.single.complete(assignments);
    await tester.pumpAndSettle();
    expect(DiagnosticLog.shared.entries, isEmpty);
    expect(DiagnosticLog.shared.current, isNull);
  });

  testWidgets(
    'homework publishes before courses; retry only reads the failed section',
    (tester) async {
      size(tester, const Size(430, 1500));
      final service = ProgressiveService();
      await tester.pumpWidget(
        ginkgoApp(
          home: TodayPage(storageRoot: '/synthetic/tasks', service: service),
        ),
      );
      expect(service.courses.length, 1);
      expect(service.assignments.length, 1);
      service.assignments.single.complete(assignments);
      await tester.pump();
      expect(find.text('1 项作业待处理'), findsOneWidget);
      expect(find.text('合成作业'), findsOneWidget);
      expect(find.text('助教作业'), findsNothing);
      expect(find.text('1 项状态待确认，请进入作业核对'), findsOneWidget);
      expect(find.text('正在读取今天课程…'), findsOneWidget);
      service.courses.single.complete(todayFixture);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('today-toggle-courses')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('刷新今天').first);
      await tester.pump();
      expect(find.text('算法设计与分析'), findsOneWidget);
      expect(find.text('合成作业'), findsOneWidget);
      service.courses.last.complete(
        const TodayResponse(
          date: '2026-10-22',
          courses: [],
          failure: FailureCode.serviceUnavailable,
        ),
      );
      service.assignments.last.complete(assignments);
      await tester.pumpAndSettle();
      expect(find.text('算法设计与分析'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(service.courses.length, 3);
      expect(service.assignments.length, 2);
      expect(service.forceCourses, [false, true, true]);
      service.courses.last.complete(todayFixture);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switching provider discards late responses and old content', (
    tester,
  ) async {
    size(tester, const Size(430, 1500));
    final old = ProgressiveService();
    final current = ProgressiveService();
    await tester.pumpWidget(
      ginkgoApp(
        home: TodayPage(storageRoot: '/synthetic/tasks', service: old),
      ),
    );
    await tester.pumpWidget(
      ginkgoApp(
        home: TodayPage(storageRoot: '/synthetic/tasks', service: current),
      ),
    );
    old.courses.single.complete(todayFixture);
    old.assignments.single.complete(assignments);
    await tester.pump();
    expect(find.text('合成作业'), findsNothing);
    expect(find.text('算法设计与分析'), findsNothing);
    current.courses.single.complete(
      const TodayResponse(date: '2026-10-22', courses: []),
    );
    current.assignments.single.complete(
      const HomeworkResponse(termName: '', termCode: 'new', items: []),
    );
    await tester.pumpAndSettle();
    expect(find.text('今天没有课程'), findsOneWidget);
    expect(find.text('当前没有待处理作业'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop refresh shortcut reloads both sections', (tester) async {
    size(tester, const Size(1100, 1000));
    final service = ProgressiveService();
    await tester.pumpWidget(
      ginkgoApp(
        home: TodayPage(storageRoot: '/synthetic/tasks', service: service),
      ),
    );
    service.courses.single.complete(todayFixture);
    service.assignments.single.complete(assignments);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(service.forceCourses, [false, true]);
    expect(service.forceAssignments, [false, true]);
    service.courses.last.complete(todayFixture);
    service.assignments.last.complete(assignments);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion and inactive tabs do not schedule animation frames',
    (tester) async {
      for (final reduced in [true, false]) {
        await tester.pumpWidget(
          ginkgoApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: TickerMode(
                enabled: reduced,
                child: const SectionFeedback(
                  loading: true,
                  label: '正在读取课程…',
                  hasData: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(find.text('正在读取课程…'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'small dark window and large text keep loading and content readable',
    (tester) async {
      size(tester, const Size(320, 1200));
      final service = ProgressiveService();
      await tester.pumpWidget(
        ginkgoApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 1200),
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
              platformBrightness: Brightness.dark,
            ),
            child: TodayPage(storageRoot: '/synthetic/tasks', service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      service.courses.single.complete(todayFixture);
      service.assignments.single.complete(assignments);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('today-scroll')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
