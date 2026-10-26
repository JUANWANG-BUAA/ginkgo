import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/features/settings/maintenance_pages.dart';
import 'package:ginkgo_mirror/platform/maintenance_service.dart';

import 'mirror_widget_test.dart' show ControlledService;

class TestMaintenance implements MaintenanceService {
  int calls = 0;
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
  Future<bool> checkBridge() async => true;
  @override
  Future<bool> checkStorage() async => false;
  @override
  Future<bool> checkVault() async => true;
}

class HoldingMaintenance extends TestMaintenance {
  final bridge = Completer<bool>();
  @override
  Future<bool> checkBridge() => bridge.future;
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
      expect(
        tester.widget<GinkgoActivity>(find.byType(GinkgoActivity)).size,
        16,
      );
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
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

  testWidgets('diagnostic running check uses the brand leaf', (tester) async {
    final service = HoldingMaintenance();
    await tester.pumpWidget(
      ginkgoApp(
        home: DiagnosticsPage(service: service, mirror: ControlledService()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始本机自检'));
    await tester.pump();
    final activities = tester.widgetList<GinkgoActivity>(
      find.byType(GinkgoActivity),
    );
    expect(activities, isNotEmpty);
    expect(activities.every((item) => item.size == 16), isTrue);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    service.bridge.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(GinkgoActivity), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('maintenance pages pass an explicit header identity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cases = <(Widget, String, String, IconData)>[
      (
        SoftwareUpdatePage(service: TestMaintenance()),
        'Ginkgo',
        '检查 Android 发布并下载更新',
        CupertinoIcons.arrow_down_circle,
      ),
      (
        DiagnosticsPage(
          service: TestMaintenance(),
          mirror: ControlledService(),
        ),
        'Ginkgo',
        '检查组件、存储与公开服务连通性',
        CupertinoIcons.checkmark_shield,
      ),
    ];
    for (final (page, section, subtitle, icon) in cases) {
      await tester.pumpWidget(ginkgoApp(home: page));
      await tester.pumpAndSettle();
      final heading = find.byKey(const Key('desktop-page-heading'));
      expect(
        find.descendant(of: heading, matching: find.text(section)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: heading, matching: find.text(subtitle)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: heading, matching: find.byIcon(icon)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
