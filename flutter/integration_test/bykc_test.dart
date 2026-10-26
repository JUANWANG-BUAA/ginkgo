import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/features/bykc/bykc_page.dart';
import 'package:ginkgo_mirror/features/bykc/bykc_detail_page.dart';
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
    await tester.tap(find.text('合成博雅课程'));
    await settle(tester);
    expect(find.byType(BykcDetailPage), findsOneWidget);
    expect(find.text('学院路、沙河'), findsOneWidget);
    await show(
      tester,
      find.text('合成课程简介：讨论艺术与生活。'),
      scrollKey: 'bykc-detail-scroll',
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('bykc-search')), '不存在');
    await settle(tester);
    expect(find.text('没有匹配的课程'), findsOneWidget);
    await tester.tap(find.text('已选课程'));
    await settle(tester);
    expect(find.text('合成已选课程'), findsOneWidget);
    expect(find.text('已签到'), findsOneWidget);
    expect(find.text('已通过'), findsOneWidget);
    expect(find.text('成绩 92'), findsOneWidget);
    await tester.tap(find.text('合成已选课程'));
    await settle(tester);
    expect(find.text('学习记录'), findsOneWidget);
    expect(find.text('10月20日 09:00'), findsOneWidget);
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await settle(tester);
    await tester.tap(find.text('完成统计'));
    await settle(tester);
    expect(find.text('5 门'), findsOneWidget);
    expect(find.text('本项暂无要求'), findsOneWidget);
    await show(tester, find.text('3 / 2'), scrollKey: 'bykc-scroll');
    expect(find.text('已完成'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
