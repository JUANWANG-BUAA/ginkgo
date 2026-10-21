import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/settings_page.dart';
import 'package:ginkgo_mirror/maintenance_pages.dart';
import 'package:ginkgo_mirror/maintenance_service.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());
  testWidgets(
    'settings diagnostics and Android release check with three appearances',
    (tester) async {
      const service = NativeMaintenanceService();
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
                child: SettingsPage(
                  key: UniqueKey(),
                  service: const DemoMirrorService(),
                  onSignOut: () async {},
                ),
              ),
            ),
          ),
        );
        await settle(tester);
        await show(tester, find.text('运行自检'), scrollKey: 'settings-scroll');
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('运行自检'));
      await settle(tester);
      await tester.tap(find.text('开始本机自检'));
      // File I/O and JNI complete outside the synthetic frame clock.
      for (
        var i = 0;
        i < 100 && find.textContaining('完成于').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await show(
        tester,
        find.textContaining('完成于'),
        scrollKey: 'maintenance-运行自检',
      );
      expect(find.textContaining('未通过'), findsNothing);
      for (final title in ['Rust 组件', '本地数据目录', '系统安全存储']) {
        await show(tester, find.text(title), scrollKey: 'maintenance-运行自检');
        final tile = find.ancestor(
          of: find.text(title),
          matching: find.byType(CupertinoListTile),
        );
        expect(
          find.descendant(of: tile, matching: find.textContaining('通过')),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        ginkgoApp(home: const SoftwareUpdatePage(service: service)),
      );
      await settle(tester);
      await tester.tap(find.text('检查更新'));
      await tester.pump();
      for (
        var i = 0;
        i < 350 && find.text('正在检查…').evaluate().isNotEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('检查结果'), findsOneWidget);
      expect(find.textContaining('未能完成更新'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
