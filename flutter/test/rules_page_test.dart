import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/features/tasks/rules_page.dart';

import 'mirror_widget_test.dart' show ControlledService;

class PendingRulesService extends ControlledService {
  final pending = Completer<RuleExamples>();
  @override
  Future<RuleExamples> rules() => pending.future;
}

void main() {
  testWidgets('rules loads with the brand leaf and a named academic header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = PendingRulesService();
    await tester.pumpWidget(ginkgoApp(home: RulesPage(service: service)));
    await tester.pump();
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(find.widgetWithText(GinkgoLoadingView, '正在读取共享规则…'), findsOneWidget);
    final loading = tester.widget<GinkgoLoadingView>(
      find.byType(GinkgoLoadingView),
    );
    expect(loading.compact, isFalse);
    expect(tester.widget<GinkgoActivity>(find.byType(GinkgoActivity)).size, 36);

    service.pending.complete(
      RuleExamples(
        localDate: '2026-10-20',
        minutesSinceMidnight: 600,
        timeZone: 'Asia/Shanghai',
        cachedWeeks: Int32List.fromList([1, 2]),
        selectedWeek: 2,
        courseNames: ['合成课程'],
      ),
    );
    await tester.pumpAndSettle();
    final heading = find.byKey(const Key('desktop-page-heading'));
    expect(heading, findsOneWidget);
    expect(
      find.descendant(of: heading, matching: find.text('学业')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: heading, matching: find.text('学校日期与课表周次的只读示例')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: heading,
        matching: find.byIcon(CupertinoIcons.doc_text),
      ),
      findsOneWidget,
    );
    expect(find.text('共享规则示例'), findsWidgets);
    expect(find.text('第 2 周'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
