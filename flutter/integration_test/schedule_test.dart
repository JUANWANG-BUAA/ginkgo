import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());

  testWidgets('schedule tab crosses real FFI with grid, week and exam states', (
    tester,
  ) async {
    await launch(tester);
    await tapTab(tester, '课表');
    await show(
      tester,
      find.text('2026-2027学年第1学期'),
      scrollKey: 'schedule-scroll',
    );
    expect(
      find.byKey(const Key('schedule-grid-course-u-0-1-1')),
      findsOneWidget,
    );
    await show(tester, find.text('考试安排'), scrollKey: 'schedule-scroll');
    expect(find.text('考试安排'), findsOneWidget);

    await tap(tester, '第 3 周', scrollKey: 'schedule-scroll');
    await show(tester, find.text('该周课表尚未缓存'), scrollKey: 'schedule-scroll');
    expect(find.text('该周课表尚未缓存'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
