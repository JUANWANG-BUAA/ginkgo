// This is an offline shell navigation smoke test. Native background scheduling,
// process death and persisted reminders are covered by background_reminders_test
// and scripts/check-android-background-reminders.sh, not by this test.
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';
import 'package:ginkgo_mirror/workspace/workspace_shell.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => RustLib.init());

  testWidgets('offline demo shell keeps navigation usable after resize', (
    tester,
  ) async {
    await tester.pumpWidget(
      GinkgoApp(
        service: const DemoMirrorService(),
        platformActions: const PlatformActions(),
        accountName: '合成演示账号',
        accountId: '__visual_review__',
        onSignOut: () async {},
      ),
    );
    Future<void> settle() async {
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
    }

    await settle();
    for (final label in ['课表', '作业', '图书馆', '更多', '今天']) {
      final tab = find.descendant(
        of: find.byType(CupertinoTabBar),
        matching: find.text(label),
      );
      expect(tab, findsOneWidget);
      await tester.tap(tab);
      await settle();
      expect(find.byType(CupertinoTabBar), findsOneWidget);
    }
    final original = tester.view.physicalSize;
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = Size(original.width, original.height * 0.8);
    await settle();
    expect(find.byType(CupertinoTabBar), findsOneWidget);
  });
}
