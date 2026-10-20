import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/cgyy_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());
  testWidgets('cgyy public venues day slots and orders remain read only', (
    tester,
  ) async {
    await tester.pumpWidget(ginkgoApp(home: const CgyyPage(demo: true)));
    await settle(tester);
    await tester.tap(find.text('合成研讨室'));
    await settle(tester);
    expect(find.text('08:00–09:00'), findsOneWidget);
    expect(find.text('空闲'), findsOneWidget);
    expect(find.text('立即预约'), findsNothing);
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await settle(tester);
    await tester.tap(find.text('我的预约记录'));
    await settle(tester);
    expect(find.text('合成场馆 · 合成研讨室 · 合成空间'), findsOneWidget);
    expect(find.text('取消预约'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
