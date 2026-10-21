import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());

  testWidgets('homework tab crosses real FFI with status filters', (
    tester,
  ) async {
    await launch(tester);
    await tapTab(tester, '作业');
    await show(
      tester,
      find.byKey(const Key('homework-spoc:a')),
      scrollKey: 'homework-scroll',
    );
    expect(find.text('作业一'), findsOneWidget);
    for (final label in ['待完成', '已提交']) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('homework-summary-$label')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    }

    await tester.tap(find.byKey(const Key('homework-spoc:a')));
    await settle(tester);
    expect(find.text('作业详情'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('授课教师'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    expect(find.text('授课教师'), findsOneWidget);
    expect(find.text('张三'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('合成作业说明：阅读教材并完成练习。'),
      -180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('合成作业说明：阅读教材并完成练习。'), findsOneWidget);
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await settle(tester);
    await show(
      tester,
      find.byKey(const Key('homework-filter-pending')),
      scrollKey: 'homework-scroll',
    );
    await tester.tap(find.byKey(const Key('homework-filter-pending')));
    await settle(tester);
    await show(
      tester,
      find.byKey(const Key('homework-spoc:b')),
      scrollKey: 'homework-scroll',
    );
    expect(find.text('作业二'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
