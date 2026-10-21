import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/maintenance_pages.dart';
import 'package:ginkgo_mirror/maintenance_service.dart';

import 'mirror_widget_test.dart' show ControlledService;

class TestMaintenance implements MaintenanceService {
  int calls = 0;
  final downloads = <(String, bool)>[];
  Completer<UpdateResult>? pending;
  @override
  bool get supportsUpdates => true;
  @override
  Future<InstalledVersion> version() async =>
      const InstalledVersion('0.1.0-alpha.1', '2');
  @override
  Future<UpdateResult> checkUpdate(String current) {
    calls++;
    return (pending = Completer<UpdateResult>()).future;
  }

  @override
  Future<bool> openReleases(String? page) async => false;
  @override
  Future<bool> openDownload(String url, {required bool accelerated}) async {
    downloads.add((url, accelerated));
    return true;
  }

  @override
  Future<bool> checkBridge() async => true;
  @override
  Future<bool> checkStorage() async => false;
  @override
  Future<bool> checkVault() async => true;
}

void main() {
  testWidgets(
    'update coalesces requests and preserves the dated last result on failure',
    (tester) async {
      final service = TestMaintenance();
      await tester.pumpWidget(
        ginkgoApp(home: SoftwareUpdatePage(service: service)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('检查更新'));
      await tester.pump();
      await tester.tap(find.text('正在检查…'));
      expect(service.calls, 1);
      service.pending!.complete(
        const UpdateResult(
          latest: '0.1.0-alpha.2',
          available: true,
          apkAvailable: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('发布尚未提供 Android 安装包'), findsOneWidget);
      await tester.tap(find.text('检查更新'));
      service.pending!.completeError(StateError('synthetic'));
      await tester.pumpAndSettle();
      expect(find.text('发布尚未提供 Android 安装包'), findsOneWidget);
      expect(find.textContaining('保留上次'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('download links accept only the matching Android APK and wrap public URL', () {
    const url =
        'https://github.com/JUANWANG-BUAA/ginkgo/releases/download/android-v0.1.0-alpha.2/Ginkgo-0.1.0-alpha.2-android-arm64.apk';
    expect(updateDownloadUri(url, accelerated: false).toString(), url);
    expect(
      updateDownloadUri(url, accelerated: true).toString(),
      'https://gh-proxy.com/$url',
    );
    for (final invalid in [
      url.replaceFirst('github.com', 'github.com.evil.example'),
      url.replaceFirst('github.com', 'name:secret@github.com'),
      url.replaceFirst('github.com', 'github.com:8443'),
      url.replaceFirst('JUANWANG-BUAA', 'other'),
      url.replaceFirst('Ginkgo-0.1.0-alpha.2', 'Ginkgo-0.1.0-alpha.1'),
      '$url?token=synthetic',
      '$url#fragment',
      url.replaceFirst('https:', 'http:'),
    ]) {
      expect(updateDownloadUri(invalid, accelerated: true), isNull);
    }
  });

  testWidgets(
    'verified download choices keep official and proxy actions separate',
    (tester) async {
      final service = TestMaintenance();
      await tester.pumpWidget(
        ginkgoApp(home: SoftwareUpdatePage(service: service)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('检查更新'));
      const url =
          'https://github.com/JUANWANG-BUAA/ginkgo/releases/download/android-v0.1.0-alpha.2/Ginkgo-0.1.0-alpha.2-android-arm64.apk';
      service.pending!.complete(
        const UpdateResult(
          latest: '0.1.0-alpha.2',
          available: true,
          apkAvailable: true,
          downloadUrl: url,
        ),
      );
      await tester.pumpAndSettle();
      for (final title in ['GitHub 下载 APK', '第三方加速下载']) {
        await tester.scrollUntilVisible(
          find.text(title),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
      }
      expect(service.downloads, [(url, false), (url, true)]);
      expect(find.text('gh-proxy.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'diagnostic reports per-item failure at large text without networking',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ginkgoApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.8),
              disableAnimations: true,
            ),
            child: DiagnosticsPage(
              service: TestMaintenance(),
              mirror: ControlledService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('开始本机自检'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('未通过，请重试'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('未通过，请重试'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
