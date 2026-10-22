import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/long_page_scroll.dart';

void main() {
  testWidgets(
    'long lists expose a return action without interfering with the list position',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: LongPageScroll(
              controller: controller,
              child: ListView.builder(
                controller: controller,
                itemExtent: 60,
                itemCount: 200,
                itemBuilder: (_, index) => Text('合成条目 $index'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('page-back-to-top')), findsNothing);
      controller.jumpTo(6000);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('page-back-to-top')), findsOneWidget);
      expect(controller.offset, 6000);
      await tester.tap(find.byKey(const Key('page-back-to-top')));
      await tester.pumpAndSettle();
      expect(controller.offset, 0);
      expect(find.byKey(const Key('page-back-to-top')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
