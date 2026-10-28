import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_page.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

import 'mirror_widget_test.dart' show ControlledService;

class ManyWeekService extends ControlledService {
  @override
  Future<ScheduleResponse> schedule({
    String? termId,
    int? week,
    bool forceRefresh = false,
  }) async => ScheduleResponse(
    terms: const [ScheduleTerm(id: 'synthetic', name: '合成学期', selected: true)],
    weeks: List.generate(
      30,
      (index) => ScheduleWeek(
        number: index + 1,
        startDate: '2026-10-19',
        endDate: '2026-10-25',
        current: index == 6,
      ),
    ),
    termId: 'synthetic',
    weekNumber: week ?? 7,
    courses: const [],
    exams: const [],
  );
}

/// Week 8 never loads: the response carries a failure without snapshot
/// metadata, the same shape an unsuccessful upstream read produces.
class FailingWeekService extends ControlledService {
  @override
  Future<ScheduleResponse> schedule({
    String? termId,
    int? week,
    bool forceRefresh = false,
  }) async {
    if (week == 8) {
      return const ScheduleResponse(
        terms: [],
        weeks: [],
        termId: '',
        weekNumber: 0,
        courses: [],
        exams: [],
        failure: FailureCode.serviceUnavailable,
      );
    }
    return ScheduleResponse(
      terms: const [
        ScheduleTerm(id: 'synthetic', name: '合成学期', selected: true),
      ],
      weeks: List.generate(
        30,
        (index) => ScheduleWeek(
          number: index + 1,
          startDate: '2026-10-19',
          endDate: '2026-10-25',
          current: index == 6,
        ),
      ),
      termId: 'synthetic',
      weekNumber: week ?? 7,
      courses: const [],
      exams: const [],
    );
  }
}

void main() {
  testWidgets(
    'week seven centers initially and selection survives large type and resizing',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scale = ValueNotifier(1.0);
      addTearDown(scale.dispose);
      final service = ManyWeekService();
      await tester.pumpWidget(
        ginkgoApp(
          home: ValueListenableBuilder<double>(
            valueListenable: scale,
            builder: (context, value, _) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(value)),
              child: SchedulePage(service: service),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final strip = find.byKey(const Key('schedule-weeks'));
      void centered(int number) {
        final viewport = tester.getRect(strip);
        final chip = tester.getRect(find.byKey(Key('schedule-week-$number')));
        expect(chip.left, greaterThanOrEqualTo(viewport.left));
        expect(chip.right, lessThanOrEqualTo(viewport.right));
        expect((chip.center.dx - viewport.center.dx).abs(), lessThan(1));
      }

      centered(7);
      final term = tester.getRect(
        find.byKey(const Key('schedule-term-picker')),
      );
      final picker = tester.getRect(
        find.byKey(const Key('schedule-week-picker')),
      );
      final current = tester.getRect(
        find.byKey(const Key('schedule-current-week')),
      );
      final chip = tester.getRect(find.byKey(const Key('schedule-week-7')));
      expect(tester.getRect(strip).bottom - term.top, lessThanOrEqualTo(140));
      for (final target in [term, picker, current, chip]) {
        expect(target.height, greaterThanOrEqualTo(48));
      }
      expect(
        find.descendant(
          of: find.byKey(const Key('schedule-week-picker')),
          matching: find.text('10/19 – 10/25'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('schedule-week-30')), findsNothing);
      await tester.tap(find.byKey(const Key('schedule-week-8')));
      await tester.pumpAndSettle();
      centered(8);
      scale.value = 1.8;
      tester.view.physicalSize = const Size(320, 1200);
      await tester.pumpAndSettle();
      centered(8);
      for (final number in [7, 8]) {
        final text = find.descendant(
          of: find.byKey(Key('schedule-week-$number')),
          matching: find.byType(Text),
        );
        final paragraph = tester.renderObject<RenderParagraph>(text);
        expect(
          paragraph.getMaxIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(paragraph.size.width + 0.01),
        );
      }
      final scrollable = find
          .descendant(of: strip, matching: find.byType(Scrollable))
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('schedule-week-30')));
      await tester.pumpAndSettle();
      final last = tester.getRect(find.byKey(const Key('schedule-week-30')));
      final viewport = tester.getRect(strip);
      expect(last.left, greaterThanOrEqualTo(viewport.left));
      expect(last.right, lessThanOrEqualTo(viewport.right));
      await tester.tap(find.byKey(const Key('schedule-current-week')));
      await tester.pumpAndSettle();
      centered(7);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a failed week load keeps the confirmed snapshot in the header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ginkgoApp(home: SchedulePage(service: FailingWeekService())),
    );
    await tester.pumpAndSettle();
    expect(find.text('第 7 周'), findsWidgets);
    await tester.tap(find.byKey(const Key('schedule-week-8')));
    await tester.pumpAndSettle();
    // The picker still names the confirmed week: a failed load must not label
    // the still-visible week 7 courses as week 8.
    expect(
      find.descendant(
        of: find.byKey(const Key('schedule-week-picker')),
        matching: find.text('第 7 周'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('正在显示'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
