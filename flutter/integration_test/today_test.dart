import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());

  testWidgets('today tab crosses real FFI with date and courses', (
    tester,
  ) async {
    await launch(tester);
    await show(
      tester,
      find.text('2026年10月20日 · 周二'),
      scrollKey: 'today-scroll',
    );
    expect(find.text('课表日期待更新'), findsOneWidget);
    await tester.tap(find.byKey(const Key('today-toggle-courses')));
    await settle(tester);
    expect(find.byKey(const Key('today-course-0-算法设计与分析')), findsOneWidget);
    await show(tester, find.text('近期考试'), scrollKey: 'today-scroll');
    expect(find.text('近期考试'), findsOneWidget);
    expect(find.textContaining('2026-11-16'), findsOneWidget);
    expect(find.text('近期时间线'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
