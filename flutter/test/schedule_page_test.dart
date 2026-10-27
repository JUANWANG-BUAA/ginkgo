import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_grid.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

import 'mirror_widget_test.dart' show ControlledService;

class DayScheduleService extends ControlledService {
  @override
  Future<ScheduleResponse> schedule({
    String? termId,
    int? week,
    bool forceRefresh = false,
  }) async => ScheduleResponse(
    terms: const [ScheduleTerm(id: 'synthetic', name: '合成学期', selected: true)],
    weeks: const [
      ScheduleWeek(
        number: 7,
        startDate: '2026-10-19',
        endDate: '2026-10-25',
        current: true,
      ),
    ],
    termId: 'synthetic',
    weekNumber: 7,
    courses: const [
      ScheduleCourse(
        id: 'monday',
        name: '算法设计与分析',
        day: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:35',
      ),
      ScheduleCourse(
        id: 'tuesday',
        name: '操作系统',
        day: 2,
        startSection: 3,
        endSection: 4,
        startTime: '10:00',
        endTime: '11:35',
      ),
    ],
    exams: const [],
  );
}

void main() {
  testWidgets(
    'narrow schedule defaults to a selected day and searches all week',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ginkgoApp(home: SchedulePage(service: DayScheduleService())),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleGrid), findsNothing);
      expect(find.byKey(const Key('schedule-day-strip')), findsOneWidget);
      expect(find.text('算法设计与分析'), findsOneWidget);
      expect(find.text('操作系统'), findsNothing);

      await tester.tap(find.byKey(const Key('schedule-day-2')));
      await tester.pumpAndSettle();
      expect(find.text('算法设计与分析'), findsNothing);
      expect(find.text('操作系统'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('schedule-search')), '算法');
      await tester.pumpAndSettle();
      expect(find.text('算法设计与分析'), findsOneWidget);
      expect(find.text('操作系统'), findsNothing);
    },
  );

  testWidgets('wide schedule keeps the week grid', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ginkgoApp(home: SchedulePage(service: DayScheduleService())),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleGrid), findsOneWidget);
  });
}
