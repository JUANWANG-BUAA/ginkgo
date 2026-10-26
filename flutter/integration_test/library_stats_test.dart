import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/features/library/library_stats_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());

  testWidgets('public statistics FFI in light dark and large text', (
    tester,
  ) async {
    for (final appearance in [
      (Brightness.light, 1.0),
      (Brightness.dark, 1.0),
      (Brightness.dark, 1.8),
    ]) {
      await tester.pumpWidget(
        ginkgoApp(
          brightness: appearance.$1,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(appearance.$2),
                disableAnimations: appearance.$2 > 1,
              ),
              child: LibraryStatsPage(
                key: UniqueKey(),
                service: const DemoMirrorService(),
              ),
            ),
          ),
        ),
      );
      await settle(tester, frames: 30);
      expect(find.text('120 人', findRichText: true), findsOneWidget);
      await show(tester, find.text('沙河校区'), scrollKey: 'library-stats-scroll');
      expect(find.text('60 人', findRichText: true), findsOneWidget);
      await show(
        tester,
        find.text('个可用 · 共 6 个'),
        scrollKey: 'library-stats-scroll',
      );
      expect(find.text('官网未提供数量'), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });
}
