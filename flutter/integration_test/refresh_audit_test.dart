import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());
  testWidgets('navigation refresh and cache invalidation', (
    tester,
  ) async {
    await tester.pumpWidget(const GinkgoApp(service: DemoMirrorService()));
    await settle(tester, frames: 30);
    await tapMore(tester, '成绩');
    expect(find.text('操作系统'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('刷新成绩').first);
    await settle(tester);
    expect(find.text('操作系统'), findsOneWidget);
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await settle(tester);
    await tap(tester, '账户与设置', scrollKey: 'today-scroll');
    await tester.scrollUntilVisible(
      find.text('清除查询快照'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('清除查询快照'));
    await settle(tester);
    await tester.tap(find.text('继续'));
    await settle(tester, frames: 30);
    expect(find.byKey(const Key('today-scroll')), findsOneWidget);
    expect(find.text('清除查询快照'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
