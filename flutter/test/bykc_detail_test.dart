import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/bykc_detail_page.dart';
import 'package:ginkgo_mirror/bykc_models.dart';
import 'package:ginkgo_mirror/main.dart';

void main() {
  testWidgets(
    'BYKC details separate attendance, result and grade at large type',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ginkgoApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.8),
              disableAnimations: true,
            ),
            child: BykcDetailPage(
              course: BykcCourse.fromJson({
                'name': '合成课程长标题用于验证自动换行',
                'teacher': '合成教师',
                'position': '合成教室',
                'category': '美育',
                'details': {
                  'start': '2026-10-21 14:00:00',
                  'end': '2026-10-21 16:00:00',
                  'enrolled': 0,
                },
              }),
              chosenRecord: BykcChosenRecord.fromJson({
                'checkin': 1,
                'passed': 1,
                'score': 92,
                'selectedAt': '2026-10-20 09:00:00',
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('合成课程长标题用于验证自动换行'), findsOneWidget);
      expect(find.text('合成教师'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('10月21日 14:00'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('上课安排'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('考核结果'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('已签到'), findsOneWidget);
      expect(find.text('已通过'), findsOneWidget);
      expect(find.text('92'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('missing BYKC capacity stays unknown and large text wraps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ginkgoApp(
        brightness: Brightness.dark,
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(1.8),
            disableAnimations: true,
          ),
          child: BykcDetailPage(
            course: BykcCourse.fromJson({
              'name': '合成课程长标题用于验证自动换行与可读性',
              'details': {'enrolled': 0},
            }),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('容量'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final tile = find.ancestor(
      of: find.text('容量'),
      matching: find.byType(CupertinoListTile),
    );
    expect(
      find.descendant(of: tile, matching: find.text('上游未提供')),
      findsOneWidget,
    );
    expect(find.text('0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
