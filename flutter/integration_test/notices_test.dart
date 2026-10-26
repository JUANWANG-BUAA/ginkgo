import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/features/notices/notices_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());
  testWidgets('notices opens sanitized summary and offers original source', (
    tester,
  ) async {
    await tester.pumpWidget(ginkgoApp(home: const NoticesPage(demo: true)));
    await settle(tester);
    await tester.tap(find.text('合成校园通知'));
    await settle(tester);
    expect(find.text('合成摘要，不含真实校园信息'), findsOneWidget);
    expect(find.text('在浏览器查看原文'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
