import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/collection_window.dart';
import 'package:ginkgo_mirror/collection_toolbar.dart';

void main() {
  testWidgets(
    'page navigation wraps at large type and supports a direct jump',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final window = CollectionWindow()
        ..reconcile(List.generate(600, (index) => '$index'));
      await tester.pumpWidget(
        CupertinoApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 1000),
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: CupertinoPageScaffold(
              child: StatefulBuilder(
                builder: (context, setState) => Center(
                  child: CollectionToolbar(
                    window: window,
                    unit: '个座位',
                    onPageChanged: (page) =>
                        setState(() => window.select(page)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collection-page-picker')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('第 12 页'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('第 12 页'));
      await tester.pumpAndSettle();
      expect(find.text('551–600 / 600 个座位'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
