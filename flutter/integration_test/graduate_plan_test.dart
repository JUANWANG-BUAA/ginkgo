import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/graduate_plan_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());
  testWidgets('synthetic plan chapters cross the native bridge', (
    tester,
  ) async {
    await tester.pumpWidget(
      ginkgoApp(home: const GraduatePlanPage(demo: true)),
    );
    await settle(tester);
    expect(find.text('合成培养方案'), findsOneWidget);
    await tap(tester, '培养目标', scrollKey: 'graduate-plan-scroll');
    await show(
      tester,
      find.text('合成方案正文 & 要求'),
      scrollKey: 'graduate-plan-scroll',
    );
    expect(find.text('合成方案正文 & 要求'), findsOneWidget);
    await tap(tester, '计划课程池（不等于毕业学分要求）', scrollKey: 'graduate-plan-scroll');
    await show(tester, find.text('合成计划课程'), scrollKey: 'graduate-plan-scroll');
    expect(find.text('必修'), findsOneWidget);
    expect(find.text('考试'), findsOneWidget);
    await tester.pumpWidget(
      ginkgoApp(
        brightness: Brightness.dark,
        home: const MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(1.8),
            disableAnimations: true,
          ),
          child: GraduatePlanPage(demo: true),
        ),
      ),
    );
    await settle(tester);
    await tap(tester, '培养目标', scrollKey: 'graduate-plan-scroll');
    await show(
      tester,
      find.text('合成方案正文 & 要求'),
      scrollKey: 'graduate-plan-scroll',
    );
    expect(tester.takeException(), isNull);
  });
}
