import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/diagnostic_log.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/features/settings/maintenance_pages.dart';
import 'package:ginkgo_mirror/platform/maintenance_service.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/platform/startup_update.dart';
import 'package:ginkgo_mirror/platform/update_gate.dart';
import 'package:package_info_plus/package_info_plus.dart';

const available = UpdateResult(
  latest: '0.1.0-alpha.7',
  available: true,
  apkAvailable: true,
);

class Updates extends Fake implements MaintenanceService {
  int versions = 0, checks = 0;
  bool supported = true;
  Completer<InstalledVersion>? versionPending;
  Completer<UpdateResult>? updatePending;
  UpdateResult response = available;
  bool fails = false;
  @override
  bool get supportsUpdates => supported;
  @override
  Future<InstalledVersion> version() {
    versions++;
    return versionPending?.future ??
        Future.value(const InstalledVersion('0.1.0-alpha.6', '7'));
  }

  @override
  Future<UpdateResult> checkUpdate(String current) async {
    checks++;
    expect(current, '0.1.0-alpha.6');
    if (fails) throw StateError('synthetic');
    return updatePending?.future ?? response;
  }
}

class SignedOutService extends Fake implements MirrorService {
  @override
  Future<SessionResponse> restoreSession() async =>
      const SessionResponse(state: SessionState.signedOut, remembered: false);
}

void main() {
  setUp(() {
    DiagnosticLog.shared.current = null;
    DiagnosticLog.shared.entries.clear();
  });
  tearDown(() {
    DiagnosticLog.shared.current = null;
  });

  testWidgets(
    'startup is nonblocking, checks once and keeps dismissal on root rebuild',
    (tester) async {
      final service = Updates()..updatePending = Completer<UpdateResult>();
      final root = GinkgoRoot(
        liveService: SignedOutService(),
        startupUpdates: service,
      );
      await tester.pumpWidget(root);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('startup-update-hint')), findsNothing);
      expect(service.checks, 1);
      expect(find.text('登录'), findsWidgets);
      service.updatePending!.complete(available);
      await tester.pumpAndSettle();
      expect(find.text('发现新版本'), findsOneWidget);
      await tester.tap(find.byKey(const Key('startup-update-dismiss')));
      await tester.pumpWidget(
        GinkgoRoot(liveService: SignedOutService(), startupUpdates: service),
      );
      await tester.pumpAndSettle();
      expect(service.checks, 1);
      expect(find.text('发现新版本'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'view shows cached update without requesting again; error hint takes priority',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = Updates();
      final controller = StartupUpdateController(service);
      addTearDown(controller.dispose);
      await controller.checkOnce();
      DiagnosticLog.shared.record(FailureCode.serviceUnavailable);
      await tester.pumpWidget(
        ginkgoApp(
          startupUpdate: controller,
          brightness: Brightness.dark,
          home: const CupertinoPageScaffold(child: Center(child: Text('合成首页'))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('发现新版本'), findsNothing);
      DiagnosticLog.shared.dismiss();
      await tester.pumpAndSettle();
      expect(find.text('发现新版本'), findsOneWidget);
      await tester.tap(find.byKey(const Key('startup-update-view')));
      await tester.pumpAndSettle();
      expect(find.byType(SoftwareUpdatePage), findsOneWidget);
      expect(find.text('Android 0.1.0-alpha.7'), findsOneWidget);
      expect(service.checks, 1);
      expect(service.versions, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'unsupported, latest, missing APK, empty version and failed checks remain quiet',
    (tester) async {
      for (final response in [
        const UpdateResult(
          latest: '0.1.0-alpha.6',
          available: false,
          apkAvailable: true,
        ),
        const UpdateResult(
          latest: '0.1.0-alpha.7',
          available: true,
          apkAvailable: false,
        ),
        const UpdateResult(latest: ' ', available: true, apkAvailable: true),
        const UpdateResult(latest: null, available: true, apkAvailable: true),
      ]) {
        final service = Updates()..response = response;
        final controller = StartupUpdateController(service);
        await controller.checkOnce();
        expect(controller.visible, isFalse);
        controller.dispose();
      }
      final unsupported = Updates()..supported = false;
      final disabled = StartupUpdateController(unsupported);
      await disabled.checkOnce();
      expect(unsupported.versions, 0);
      disabled.dispose();
      final failure = StartupUpdateController(Updates()..fails = true);
      await failure.checkOnce();
      expect(failure.visible, isFalse);
      expect(DiagnosticLog.shared.current, isNull);
      failure.dispose();
    },
  );

  testWidgets(
    'total timeout prevents late version from starting a request and late results from hinting',
    (tester) async {
      for (final delayVersion in [true, false]) {
        final service = Updates();
        if (delayVersion) {
          service.versionPending = Completer<InstalledVersion>();
        } else {
          service.updatePending = Completer<UpdateResult>();
        }
        final controller = StartupUpdateController(
          service,
          timeout: const Duration(seconds: 1),
        );
        final pending = controller.checkOnce();
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await pending;
        if (delayVersion) {
          service.versionPending!.complete(
            const InstalledVersion('0.1.0-alpha.6', '7'),
          );
        } else {
          service.updatePending!.complete(available);
        }
        await tester.pump();
        expect(controller.visible, isFalse);
        expect(service.checks, delayVersion ? 0 : 1);
        await controller.checkOnce();
        expect(service.versions, 1);
        controller.dispose();
      }
    },
  );

  testWidgets(
    'dispose ignores in-flight result and background hides without rechecking',
    (tester) async {
      final service = Updates()..updatePending = Completer<UpdateResult>();
      final disposed = StartupUpdateController(service);
      final pending = disposed.checkOnce();
      await tester.pump();
      disposed.dispose();
      service.updatePending!.complete(available);
      await pending;
      expect(disposed.result, isNull);
      final fresh = Updates();
      final controller = StartupUpdateController(fresh);
      await controller.checkOnce();
      await tester.pumpWidget(
        ginkgoApp(
          startupUpdate: controller,
          home: const CupertinoPageScaffold(child: SizedBox()),
        ),
      );
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('发现新版本'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('发现新版本'), findsOneWidget);
      expect(fresh.checks, 1);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('minimum build gate takes precedence over optional hint', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'Ginkgo',
      packageName: 'synthetic',
      version: '0.1.0-alpha.6',
      buildNumber: '7',
      buildSignature: '',
    );
    final service = Updates();
    await tester.pumpWidget(
      GinkgoRoot(
        liveService: SignedOutService(),
        startupUpdates: service,
        loadUpdateGate: () async => const UpdateGate(minBuild: 8),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('需要更新'), findsOneWidget);
    expect(find.text('发现新版本'), findsNothing);
    expect(service.checks, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
