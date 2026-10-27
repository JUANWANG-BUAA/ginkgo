// 宣传截图采集：只跑离线演示数据，不登录、不访问学校系统。
//
// 产物通过 `adb reverse` + 本机接收器（scripts/capture-android-module-visual.py）
// 传回宿主机，用于 README 与 GitHub Pages 的界面预览。
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart' show settle;

const demo = DemoMirrorService();
const captureToHost = bool.fromEnvironment('GINKGO_VISUAL_CAPTURE');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await RustLib.init();
  });

  testWidgets('promo screenshots from the offline demo shell', (tester) async {
    await binding.convertFlutterSurfaceToImage();
    final root = await getTemporaryDirectory();
    final directory = Directory('${root.path}/goal-promo')
      ..createSync(recursive: true);

    Future<void> capture(String name) async {
      await settle(tester, frames: 12);
      expect(tester.takeException(), isNull);
      final bytes = await binding.takeScreenshot(name);
      binding.reportData?.remove('screenshots');
      if (captureToHost) {
        await tester.runAsync(() async {
          final socket = await Socket.connect(
            '127.0.0.1',
            18765,
            timeout: const Duration(seconds: 5),
          );
          socket.add(
            'POST /$name.png HTTP/1.0\r\nHost: 127.0.0.1\r\nContent-Length: ${bytes.length}\r\n\r\n'
                .codeUnits,
          );
          socket.add(bytes);
          await socket.flush();
          await socket.drain<void>();
          socket.destroy();
        });
      }
      await File('${directory.path}/$name.png').writeAsBytes(bytes, flush: true);
    }

    Future<void> openTab(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoTabBar),
          matching: find.text(label),
        ),
      );
      await settle(tester, frames: 20);
    }

    await tester.pumpWidget(
      GinkgoApp(key: UniqueKey(), service: demo),
    );
    await settle(tester, frames: 30);
    await capture('android-today');

    await openTab('课表');
    await capture('android-schedule');

    await openTab('作业');
    await capture('android-homework');

    await openTab('签到');
    await capture('android-checkin');

    await openTab('预约');
    await capture('android-reservations');

    await tester.tap(find.text('查看时段'));
    await settle(tester, frames: 24);
    await capture('android-cgyy');
    final back = find.byType(CupertinoNavigationBarBackButton);
    if (back.evaluate().isNotEmpty) {
      await tester.tap(back.first);
      await settle(tester, frames: 20);
    }

    await tester.tap(find.text('选择座位'));
    await settle(tester, frames: 24);
    await capture('android-library');
  });
}
