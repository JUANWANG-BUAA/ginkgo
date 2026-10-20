import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/graduate_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());
  testWidgets('graduate execution report shows upstream category credits', (
    tester,
  ) async {
    await tester.pumpWidget(ginkgoApp(home: const GraduatePage(demo: true)));
    await settle(tester);
    await show(
      tester,
      find.text('要求 6 · 已获 2 · 待考核 1 学分'),
      scrollKey: 'graduate-scroll',
    );
    expect(find.text('合成课程'), findsOneWidget);
    expect(find.text('2 学分 · 已完成'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
