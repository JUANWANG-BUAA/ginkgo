import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());

  testWidgets('grades tab crosses real FFI with summary and courses', (
    tester,
  ) async {
    await launch(tester);
    await tapTab(tester, '成绩');
    await show(tester, find.text('加权平均'), scrollKey: 'grades-scroll');
    expect(find.text('90.3'), findsOneWidget);
    expect(find.text('3.82'), findsOneWidget);
    await show(
      tester,
      find.byKey(const Key('grade-course-a')),
      scrollKey: 'grades-scroll',
    );
    expect(find.text('算法设计与分析'), findsOneWidget);
    expect(find.text('92'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
