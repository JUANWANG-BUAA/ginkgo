import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/local_tasks.dart';
import 'package:ginkgo_mirror/application/schedule_ics.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_grid.dart';
import 'package:ginkgo_mirror/features/tasks/tasks_widgets.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_modal_sheet.dart';

void main() {
  test('buildScheduleIcs outputs standard VCALENDAR/VEVENT entries', () {
    const response = ScheduleResponse(
      terms: [ScheduleTerm(id: '20261', name: '2026秋', selected: true)],
      weeks: [
        ScheduleWeek(
          number: 3,
          startDate: '2026-09-21',
          endDate: '2026-09-27',
          current: true,
        ),
      ],
      termId: '20261',
      weekNumber: 3,
      courses: [
        ScheduleCourse(
          id: 'alg-1',
          name: '算法设计',
          day: 2,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:35',
          place: '主M201',
          teacher: '张老师',
        ),
      ],
      exams: [],
    );

    final ics = buildScheduleIcs(response);
    expect(ics, contains('BEGIN:VCALENDAR'));
    expect(ics, contains('DTSTART;TZID=Asia/Shanghai:20260922T080000'));
    expect(ics, contains('DTEND;TZID=Asia/Shanghai:20260922T093500'));
    expect(ics, contains('SUMMARY:算法设计'));
    expect(ics, contains('LOCATION:主M201'));
    expect(scheduleIcsFileName(response), 'ginkgo-20261-week3.ics');
  });

  testWidgets(
    'ScheduleGrid stacks overlapping courses with +1 badge and supports week swipe',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      List<ScheduleCourse>? tappedOverlap;
      int? swipedDelta;

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: ScheduleGrid(
                weekStart: '2026-10-19',
                courses: const [
                  ScheduleCourse(
                    id: 'a',
                    name: '离散数学',
                    day: 1,
                    startSection: 1,
                    endSection: 2,
                  ),
                  ScheduleCourse(
                    id: 'b',
                    name: '概率统计',
                    day: 1,
                    startSection: 1,
                    endSection: 2,
                  ),
                ],
                onCourseTap: (_) {},
                onConflictTap: (cluster) => tappedOverlap = cluster,
                onSwipeWeek: (delta) => swipedDelta = delta,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('schedule-grid-overlap-a')), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('schedule-grid-course-a')));
      await tester.pump();
      expect(tappedOverlap?.length, 2);

      await tester.drag(
        find.byKey(const Key('schedule-grid-swipe')),
        const Offset(-120, 0),
      );
      await tester.pump();
      expect(swipedDelta, 1);
    },
  );

  testWidgets('showGinkgoModalSheet dismisses on downward drag', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                onPressed: () => showGinkgoModalSheet<void>(
                  context: context,
                  builder: (_) => const SizedBox(
                    height: 220,
                    child: Center(child: Text('弹层主体')),
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('弹层主体'), findsOneWidget);

    await tester.drag(find.text('弹层主体'), const Offset(0, 160));
    await tester.pumpAndSettle();
    expect(find.text('弹层主体'), findsNothing);
  });

  testWidgets('TaskRowCard supports swipe right to toggle and swipe left to delete', (
    tester,
  ) async {
    var toggled = 0;
    var deleted = 0;
    const task = LocalTaskRecord(
      id: 't1',
      title: '复习线性代数',
      due: '',
      completed: false,
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: ListView(
            children: [
              TaskRowCard(
                task: task,
                highlighted: false,
                targetKey: GlobalKey(),
                busy: false,
                readable: true,
                locating: false,
                onToggle: () => toggled++,
                onMore: () {},
                onSource: () {},
                onDelete: () => deleted++,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.drag(find.text('复习线性代数'), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(toggled, 1);

    await tester.drag(find.text('复习线性代数'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });
}
