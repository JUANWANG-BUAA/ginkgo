import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_grid.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

const course = ScheduleCourse(
  id: 'first-day',
  name: '合成课程',
  day: 1,
  startSection: 1,
  endSection: 2,
  startTime: '08:00',
  endTime: '09:35',
);

void main() {
  testWidgets(
    'standard 393dp phone fits all 7 days onto one single screen without horizontal scrollbars',
    (tester) async {
      tester.view.physicalSize = const Size(393, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ScheduleGrid(
                  courses: const [course],
                  weekStart: '2026-10-19',
                  onCourseTap: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('schedule-grid-horizontal')), findsNothing);
      expect(find.text('一'), findsOneWidget);
      expect(find.text('日'), findsOneWidget);
      expect(find.text('19'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
      expect(
        find.byKey(const Key('schedule-grid-course-first-day')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ultra-narrow 300dp viewport falls back to horizontal scroll while keeping fixed time axis',
    (tester) async {
      tester.view.physicalSize = const Size(300, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: ScheduleGrid(
                courses: const [course],
                weekStart: '2026-10-19',
                onCourseTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final horizontal = find.byKey(const Key('schedule-grid-horizontal'));
      expect(horizontal, findsOneWidget);
      final axisBefore = tester.getTopLeft(
        find.byKey(const Key('schedule-fixed-time-axis')),
      );
      await tester.drag(horizontal, const Offset(-80, 0));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const Key('schedule-fixed-time-axis'))),
        axisBefore,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
