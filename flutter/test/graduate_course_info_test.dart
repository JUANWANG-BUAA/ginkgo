import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/academic_widgets.dart';
import 'package:ginkgo_mirror/graduate_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart';

void main() {
  testWidgets(
    'course code search opens structured school fields at large type',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final fixture = jsonDecode(
        File('../fixtures/graduate/execution-course-info-v1.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      await tester.pumpWidget(
        ginkgoApp(
          brightness: Brightness.dark,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.8),
                disableAnimations: true,
              ),
              child: GraduatePage(
                loader: ({required report, required forceRefresh}) async {
                  calls++;
                  return ReadOnlyResponse(
                    stale: false,
                    payload: jsonEncode(
                      report ? fixture['expected'] : {'sections': []},
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Large type uses the same Cupertino selection sheet as the existing page.
      final viewPicker = find.text('显示内容');
      if (viewPicker.evaluate().isNotEmpty) {
        await tester.tap(viewPicker);
        await tester.pumpAndSettle();
        await tester.tap(find.text('课程').last);
      } else {
        await tester.tap(find.text('课程'));
      }
      await tester.pumpAndSettle();
      final search = find.byKey(const Key('graduate-search'));
      await tester.scrollUntilVisible(
        search,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(search, 'SYN-101');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final course = find.text('合成课程');
      await tester.scrollUntilVisible(
        course,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(course);
      await tester.pumpAndSettle();
      for (final value in ['SYN-101', '优秀', '合成课程类别', '学校原值', '合成学期']) {
        final field = find.widgetWithText(AcademicFactRow, value);
        await tester.scrollUntilVisible(
          field,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(field, findsOneWidget);
      }
      expect(find.text('考核方式'), findsNothing);
      expect(find.text('必修标记'), findsNothing);
      expect(
        calls,
        2,
        reason: 'Opening details must use the existing snapshot',
      );
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      final restored = tester.widget<CupertinoSearchTextField>(search);
      expect(restored.controller!.text, 'SYN-101');
      expect(calls, 2);
    },
  );
}
