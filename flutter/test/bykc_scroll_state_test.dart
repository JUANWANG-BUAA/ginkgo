import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/bykc_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart';

void main() {
  testWidgets(
    'BYKC restores each loaded segment scroll without another request',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <BykcPart, int>{};
      Map<String, dynamic> course(int index) => {
        'id': index,
        'name': '合成课程 $index',
        'category': '合成类别',
      };
      await tester.pumpWidget(
        ginkgoApp(
          home: BykcPage(
            loader: ({required part, required forceRefresh}) async {
              calls[part] = (calls[part] ?? 0) + 1;
              return ReadOnlyResponse(
                stale: false,
                payload: jsonEncode(switch (part) {
                  BykcPart.catalog => {
                    'terms': [],
                    'courses': [for (var i = 0; i < 40; i++) course(i)],
                  },
                  BykcPart.chosen => {
                    'term': {'name': '合成学期'},
                    'courses': [
                      for (var i = 0; i < 40; i++)
                        {'id': i, 'course': course(i)},
                    ],
                  },
                  BykcPart.statistics => {'entries': [], 'validCourseCount': 0},
                }),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<CustomScrollView>(find.byKey(const Key('bykc-scroll')))
          .controller!;
      final selector = tester
          .widget<CupertinoSlidingSegmentedControl<BykcPart>>(
            find.byType(CupertinoSlidingSegmentedControl<BykcPart>),
          );
      await tester.drag(
        find.byKey(const Key('bykc-scroll')),
        const Offset(0, -1800),
      );
      await tester.pumpAndSettle();
      final catalogOffset = controller.position.pixels;
      expect(catalogOffset, greaterThan(300));
      // Invoke the actual selector callback even when the selector has scrolled away.
      selector.onValueChanged(BykcPart.chosen);
      await tester.pumpAndSettle();
      expect(controller.position.pixels, 0);
      await tester.drag(
        find.byKey(const Key('bykc-scroll')),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      final chosenOffset = controller.position.pixels;
      expect(chosenOffset, greaterThan(300));
      selector.onValueChanged(BykcPart.catalog);
      await tester.pumpAndSettle();
      expect(controller.position.pixels, closeTo(catalogOffset, 1));
      selector.onValueChanged(BykcPart.chosen);
      await tester.pumpAndSettle();
      expect(controller.position.pixels, closeTo(chosenOffset, 1));
      expect(calls, {BykcPart.catalog: 1, BykcPart.chosen: 1});
      expect(tester.takeException(), isNull);
    },
  );
}
