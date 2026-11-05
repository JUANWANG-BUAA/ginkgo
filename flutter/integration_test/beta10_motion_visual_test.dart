import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';
import 'package:ginkgo_mirror/workspace/workspace_shell.dart';
import 'package:ginkgo_mirror/widgets/apple_surfaces.dart';

import 'support.dart' show settle;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => RustLib.init());
  testWidgets(
    'actual shell press, cancellation, navigation and theme changes',
    (tester) async {
      Future<void> capture(String name) async {
        expect(tester.takeException(), isNull, reason: name);
        await tester.runAsync(() async {
          final socket = await Socket.connect('127.0.0.1', 18765);
          socket.add(
            'GET /$name.png HTTP/1.0\r\nHost: localhost\r\n\r\n'.codeUnits,
          );
          await socket.flush();
          await socket.drain<void>();
          socket.destroy();
        });
      }

      for (final mode in Brightness.values) {
        final preferences = AppPreferences(writer: (_) async {});
        await tester.pumpWidget(
          GinkgoApp(
            key: UniqueKey(),
            service: const DemoMirrorService(),
            platformActions: const PlatformActions(),
            brightness: mode,
            preferences: preferences,
            accountName: '合成演示账号',
            accountId: '__visual_review__',
            onSignOut: () async {},
          ),
        );
        await settle(tester, frames: 30);
        for (final label in ['课表', '作业', '图书馆', '更多', '今天']) {
          await tester.tap(
            find.descendant(
              of: find.byType(CupertinoTabBar),
              matching: find.text(label),
            ),
          );
          await tester.pump(const Duration(milliseconds: 80));
          await capture(
            'motion-${mode.name}-$label-transition'
                .replaceAll('课表', 'schedule')
                .replaceAll('作业', 'homework')
                .replaceAll('图书馆', 'library')
                .replaceAll('更多', 'more')
                .replaceAll('今天', 'today'),
          );
          await settle(tester, frames: 20);
        }
        await tester.tap(
          find.descendant(
            of: find.byType(CupertinoTabBar),
            matching: find.text('更多'),
          ),
        );
        await settle(tester, frames: 20);
        final row = find.widgetWithText(AppleListTile, '账号与设置');
        expect(row, findsOneWidget);
        final gesture = await tester.startGesture(tester.getCenter(row));
        // Start the implicit animation, then advance beyond the 120ms press.
        // A single pump can capture its first frame with scale still at 1.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final compression = find.descendant(
          of: row,
          matching: find.byType(ScaleTransition),
        );
        expect(tester.widget<ScaleTransition>(compression).scale.value, 0.985);
        await capture('motion-${mode.name}-row-pressed');
        await gesture.cancel();
        await settle(tester, frames: 10);
        expect(tester.widget<ScaleTransition>(compression).scale.value, 1);
        await capture('motion-${mode.name}-row-cancelled');
        await tester.tap(row);
        await settle(tester, frames: 30);
        await capture('motion-${mode.name}-settings-open');
        expect(find.text('显示与阅读'), findsOneWidget);
        await tester.pageBack();
        await settle(tester, frames: 30);
        expect(find.widgetWithText(AppleListTile, '账号与设置'), findsOneWidget);
        await capture('motion-${mode.name}-returned');
        await tester.pumpWidget(const SizedBox());
        preferences.dispose();
      }
    },
  );
}
