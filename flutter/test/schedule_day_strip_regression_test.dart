import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_day_strip.dart';

void main() {
  for (final width in [320.0, 360.0, 430.0]) {
    for (final scale in [1.0, 2.0, 3.2]) {
      testWidgets(
        'all school days are reachable at $width dp and $scale type',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          int? selected;
          await tester.pumpWidget(
            CupertinoApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 900),
                  textScaler: TextScaler.linear(scale),
                ),
                child: CupertinoPageScaffold(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ScheduleDayStrip(
                      weekStart: '2026-10-19',
                      selectedDay: 1,
                      onSelected: (day) => selected = day,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final sunday = find.byKey(const Key('schedule-day-7'));
          if (find.byType(Scrollable).evaluate().isNotEmpty) {
            await tester.scrollUntilVisible(
              sunday,
              100,
              scrollable: find.byType(Scrollable),
            );
            await tester.pumpAndSettle();
          }
          expect(sunday.hitTestable(), findsOneWidget);
          final size = tester.getSize(sunday);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
          await tester.tap(sunday);
          expect(selected, 7);
          expect(tester.takeException(), isNull);
          if (width == 430 && scale == 1) {
            expect(find.byType(Scrollable), findsNothing);
            expect(
              tester.getTopLeft(find.byKey(const Key('schedule-day-1'))).dx,
              greaterThan(0),
            );
          }
        },
      );
    }
  }
}
