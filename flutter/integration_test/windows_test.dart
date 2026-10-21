import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' as live;
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async {
    // The real application must load its adjacent bundled DLL, not a developer
    // workspace fallback that happens to exist on the CI host.
    expect(Platform.isWindows, isTrue);
    final executableDirectory = File(Platform.resolvedExecutable).parent;
    expect(
      File('${executableDirectory.path}/ginkgo_flutter_bridge.dll')
          .existsSync(),
      isTrue,
      reason: 'Rust DLL must be bundled next to the Windows executable',
    );
    await RustLib.init();
  });

  testWidgets('desktop secure storage and independent workspace navigation', (
    tester,
  ) async {
    for (final secret in ['fixture-one', 'fixture-two']) {
      expect(
        await live.verifyCredentialStorage(
          account: '__ginkgo_vault_test__windows',
          secret: secret,
        ),
        isTrue,
      );
    }
    // Override the logical test viewport; this does not resize the native host
    // window. LiveTestWidgetsFlutterBinding applies this to root constraints.
    await binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => binding.setSurfaceSize(null));
    await tester.pumpWidget(const GinkgoApp(service: DemoMirrorService()));
    await settle(tester, frames: 30);
    expect(find.byKey(const Key('desktop-sidebar')), findsOneWidget);
    expect(tester.getSize(find.byType(Row).first).width, 1280);
    await tester.tap(find.byKey(const Key('desktop-sidebar-3')));
    await settle(tester);
    await show(tester, find.text('加权平均'), scrollKey: 'grades-scroll');
    expect(find.text('90.3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('desktop-sidebar-4')));
    await settle(tester);
    final homework = find.byKey(const Key('homework-spoc:a'));
    await show(tester, homework, scrollKey: 'homework-scroll');
    await tester.tap(homework);
    await settle(tester);
    expect(find.byKey(const Key('desktop-sidebar')), findsOneWidget);
    expect(find.text('作业详情'), findsOneWidget);
    await tester.tap(find.byKey(const Key('desktop-sidebar-3')));
    await settle(tester);
    expect(find.text('90.3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('desktop-sidebar-4')));
    await settle(tester);
    expect(find.text('作业详情'), findsOneWidget);
    await tester.tap(find.byKey(const Key('desktop-sidebar-8')));
    await settle(tester);
    expect(find.byKey(const Key('settings-scroll')), findsOneWidget);
    await tester.tap(find.byKey(const Key('desktop-sidebar-4')));
    await settle(tester);
    expect(find.text('作业详情'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
