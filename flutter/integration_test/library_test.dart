import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart';

/// Demo-mode device test for the booking.lib read-only hierarchy: the Rust
/// bridge parses synthetic fixtures, Flutter only renders venue -> area ->
/// slot -> seat.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());

  testWidgets('demo library drills from venues to seats', (tester) async {
    await launch(tester);
    await tapTab(tester, '图书馆');
    await settle(tester, frames: 30);

    expect(find.text('当前预约'), findsOneWidget);
    expect(find.text('选择场馆'), findsOneWidget);
    expect(find.text('学院路馆'), findsOneWidget);
    expect(find.text('空闲 12 / 30'), findsOneWidget);
    expect(find.byKey(const Key('library-public-stats')), findsOneWidget);

    await tap(tester, '全部预约记录', scrollKey: 'library-scroll');
    await show(tester, find.text('已取消'), scrollKey: 'library-history-scroll');
    expect(find.text('已取消'), findsOneWidget);
    expect(
      tester
          .widget<CupertinoButton>(
            find.byKey(const Key('library-history-next')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await settle(tester);
    await tap(tester, '学院路馆', scrollKey: 'library-scroll');
    expect(find.text('区域'), findsOneWidget);
    expect(find.text('空闲 4 / 20'), findsOneWidget);

    await tap(tester, 'A区', scrollKey: 'library-areas-scroll');
    expect(find.text('时段'), findsOneWidget);
    expect(find.text('08:00–10:00'), findsOneWidget);

    await tap(tester, '08:00–10:00', scrollKey: 'library-slots-scroll');
    expect(find.byKey(const Key('library-seat-s1')), findsOneWidget);
    expect(find.text('A-01'), findsOneWidget);
    expect(find.text('空闲'), findsOneWidget);
    expect(find.text('已占用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
