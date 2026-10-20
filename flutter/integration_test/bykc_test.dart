import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/bykc_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());
  testWidgets('BYKC catalog searches synthetic display data', (tester) async {
    await tester.pumpWidget(ginkgoApp(home: const BykcPage(demo: true)));
    await settle(tester);
    expect(find.text('合成博雅课程'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('bykc-search')), '不存在');
    await settle(tester);
    expect(find.text('没有匹配的课程'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
