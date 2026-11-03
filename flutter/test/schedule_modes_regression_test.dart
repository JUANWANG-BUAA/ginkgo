import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_page.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_widgets.dart';
import 'package:ginkgo_mirror/main.dart';

import 'mirror_widget_test.dart' show ControlledService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Ginkgo Sans',
    )..addFont(rootBundle.load('assets/fonts/Inter.ttf'))).load();
    await (FontLoader(
      'Ginkgo Han',
    )..addFont(rootBundle.load('assets/fonts/NotoSansSC.ttf'))).load();
  });
  for (final width in [320.0, 360.0, 430.0]) {
    for (final scale in [1.0, 1.3, 1.4, 2.0, 3.2]) {
      testWidgets('four schedule modes stay operable at $width dp / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ginkgoApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 1200),
                textScaler: TextScaler.linear(scale),
              ),
              child: SchedulePage(service: ControlledService()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale <= 1.4) {
          final segmented = find.byType(
            CupertinoSlidingSegmentedControl<ScheduleViewMode>,
          );
          expect(segmented, findsOneWidget);
          final boundary = tester.getRect(segmented);
          expect(boundary.left, greaterThanOrEqualTo(0));
          expect(boundary.right, lessThanOrEqualTo(width));
          for (final label in ['周课表', '每日清单', '学期', '考试']) {
            final item = find.descendant(
              of: segmented,
              matching: find.text(label),
            );
            expect(item, findsOneWidget);
            final bounds = tester.getRect(item);
            expect(bounds.left, greaterThanOrEqualTo(boundary.left));
            expect(bounds.right, lessThanOrEqualTo(boundary.right));
            final paragraph = tester.renderObject<RenderParagraph>(item);
            expect(
              paragraph.getMaxIntrinsicWidth(double.infinity),
              lessThanOrEqualTo(paragraph.size.width + 0.01),
              reason:
                  '$label must fit its own text box without wrapping or clipping',
            );
            await tester.tap(item);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        } else {
          for (final label in ['周课表 · 大字号使用每日清单', '每日清单', '学期', '考试']) {
            await tester.scrollUntilVisible(
              find.text('显示方式'),
              180,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('显示方式'));
            await tester.pumpAndSettle();
            final action = find.widgetWithText(
              CupertinoActionSheetAction,
              label,
            );
            expect(action, findsOneWidget);
            await tester.ensureVisible(action);
            await tester.pumpAndSettle();
            await tester.tap(action);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
