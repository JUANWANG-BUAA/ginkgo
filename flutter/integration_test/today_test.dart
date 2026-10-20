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
    expect(find.text('今天 2 节课'), findsOneWidget);
    expect(find.byKey(const Key('today-course-算法设计与分析')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
