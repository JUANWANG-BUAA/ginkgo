import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart';

/// Demo-mode device test for the iclass read-only page: real Rust FFI parses
/// the shared synthetic fixture, Flutter only renders the result.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());

  testWidgets('demo checkin page renders statuses from the Rust bridge', (
    tester,
  ) async {
    await launch(tester);
    await tapMore(tester, '课程签到');
    await settle(tester, frames: 30);

    expect(find.text('2026年10月20日 · 周二'), findsOneWidget);
    expect(find.text('今天 2 节课'), findsOneWidget);
    expect(find.text('高等数学'), findsOneWidget);
    expect(find.text('大学物理'), findsOneWidget);
    expect(find.text('未签到'), findsOneWidget);
    expect(find.text('已签到'), findsOneWidget);
    expect(find.textContaining('仅用于演示只读签到页'), findsOneWidget);
    await tap(tester, '历史日期查询', scrollKey: 'checkin-scroll');
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CupertinoSliverNavigationBar &&
            widget.largeTitle is Text &&
            (widget.largeTitle as Text).data == '签到历史',
      ),
      findsOneWidget,
    );
    await tap(tester, '前一天', scrollKey: 'checkin-scroll');
    expect(find.text('当天 2 节课'), findsOneWidget);
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await settle(tester);
    expect(find.text('今天 2 节课'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
