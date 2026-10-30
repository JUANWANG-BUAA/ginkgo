import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/platform/android_update_controller.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/platform/update_download_section.dart';
import 'package:ginkgo_mirror/application/maintenance.dart';

/// The download never leaves its directory wait, so the busy phase is observed
/// without network traffic or file writes.
class _StuckRoot {
  final pending = Completer<Directory>();
  Future<Directory> call() => pending.future;
}

void main() {
  testWidgets('busy download uses the brand leaf, not a spinner', (
    tester,
  ) async {
    final root = _StuckRoot();
    final controller = AndroidUpdateController(root: root.call);
    const asset = AndroidDownload(
      version: '0.1.0-alpha.4',
      name: 'Ginkgo-0.1.0-alpha.4-android-arm64.apk',
      url:
          'https://github.com/JUANWANG-BUAA/ginkgo/releases/download/'
          'android-v0.1.0-alpha.4/Ginkgo-0.1.0-alpha.4-android-arm64.apk',
      apiUrl: 'https://api.github.com/repos/JUANWANG-BUAA/ginkgo/releases/assets/123',
      size: 4096,
      sha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    unawaited(controller.download(asset));
    await tester.pumpWidget(
      ginkgoApp(
        home: UpdateDownloadSection(asset: asset, controller: controller),
      ),
    );
    await tester.pump();
    expect(find.text('正在下载…'), findsOneWidget);
    expect(controller.busy, isTrue);
    expect(tester.widget<GinkgoActivity>(find.byType(GinkgoActivity)).size, 16);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    controller.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
