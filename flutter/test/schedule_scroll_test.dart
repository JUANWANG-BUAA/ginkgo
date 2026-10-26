import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
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
    'narrow timetable keeps horizontal scrollbar above dates and supports controls and swipes',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
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
      final scrollbar = tester.widget<CupertinoScrollbar>(
        find.byKey(const Key('schedule-grid-top-scrollbar')),
      );
      expect(scrollbar.scrollbarOrientation, ScrollbarOrientation.top);
      expect(scrollbar.thumbVisibility, isTrue);
      final controls = tester.getRect(
        find.byKey(const Key('schedule-grid-next-days')),
      );
      final dates = tester.getRect(find.text('周一\n10/19'));
      expect(controls.bottom, lessThanOrEqualTo(dates.top));
      final horizontal = find.byKey(const Key('schedule-grid-horizontal'));
      final scroll = tester
          .widget<SingleChildScrollView>(horizontal)
          .controller!;
      expect(scroll.offset, 0);
      final first = tester.getTopLeft(
        find.byKey(const Key('schedule-grid-course-first-day')),
      );
      final axis = tester.getTopLeft(
        find.byKey(const Key('schedule-fixed-time-axis')),
      );
      await tester.tap(find.byKey(const Key('schedule-grid-next-days')));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(100));
      expect(
        tester.getTopLeft(find.byKey(const Key('schedule-fixed-time-axis'))),
        axis,
      );
      expect(
        tester
            .getTopLeft(find.byKey(const Key('schedule-grid-course-first-day')))
            .dx,
        lessThan(first.dx),
      );
      await tester.tap(find.byKey(const Key('schedule-grid-previous-days')));
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      await tester.drag(horizontal, const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      expect(
        scroll.offset == scroll.position.maxScrollExtent ||
            (scroll.offset / 106 - (scroll.offset / 106).round()).abs() < 0.01,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('schedule-day-jump')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('周日').last);
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(scroll.position.maxScrollExtent, 1));
      await tester.tap(find.byKey(const Key('schedule-grid-previous-days')));
      await tester.pumpAndSettle();
      // Trackpads/wheels continue to target the actual horizontal viewport.
      final beforeWheel = scroll.offset;
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(horizontal),
          scrollDelta: const Offset(80, 0),
        ),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(beforeWheel));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('wide timetable needs no horizontal scroll controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 1100);
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
    expect(find.byKey(const Key('schedule-grid-top-scrollbar')), findsNothing);
    expect(find.byKey(const Key('schedule-grid-next-days')), findsNothing);
    expect(find.text('周日\n10/25'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
