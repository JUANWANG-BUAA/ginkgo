import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/bykc_detail_page.dart';
import 'package:ginkgo_mirror/main.dart';

void main() {
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
        home: const MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(1.8),
            disableAnimations: true,
          ),
          child: BykcDetailPage(
            course: {
              'name': '合成课程长标题用于验证自动换行与可读性',
              'details': {'enrolled': 0},
            },
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
