import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/settings/maintenance_pages.dart';
import 'package:ginkgo_mirror/features/settings/network_diagnostics_page.dart';
import 'package:ginkgo_mirror/features/tasks/tasks_page.dart';
import 'package:ginkgo_mirror/application/maintenance.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/main.dart';

import 'mirror_widget_test.dart' show ControlledService;
import 'platform_actions_fake.dart';

/// `CupertinoPageScaffold` only removes the top inset for its child; without a
/// `SafeArea` the page content can extend into the home-indicator area.
void main() {
  testWidgets('the tasks page keeps its slivers inside the safe area', (
    tester,
  ) async {
    await tester.pumpWidget(
      ginkgoApp(
        home: TasksPage(
          service: ControlledService(),
          fileActions: platformActions,
          storageRoot: '/synthetic/tasks',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.byType(CustomScrollView),
        matching: find.byType(SafeArea),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the maintenance scaffold keeps its slivers inside the safe area', (
    tester,
  ) async {
    await tester.pumpWidget(
      ginkgoApp(home: const SoftwareUpdatePage(service: _StubMaintenance())),
    );
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.byType(CustomScrollView),
        matching: find.byType(SafeArea),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the diagnostics page keeps its slivers inside the safe area', (
    tester,
  ) async {
    await tester.pumpWidget(
      ginkgoApp(home: NetworkDiagnosticsPage(service: ControlledService())),
    );
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.byType(CustomScrollView),
        matching: find.byType(SafeArea),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _StubMaintenance implements MaintenanceService {
  const _StubMaintenance();

  @override
  bool get supportsUpdates => false;

  @override
  Future<InstalledVersion> version() async => const InstalledVersion('0', '0');

  @override
  Future<UpdateResult> checkUpdate(String current) async =>
      const UpdateResult(latest: null, available: false, apkAvailable: false);

  @override
  Future<bool> openReleases(String? page) async => false;

  @override
  Future<bool> checkBridge() async => true;

  @override
  Future<bool> checkStorage() async => true;

  @override
  Future<bool> checkVault() async => true;

  @override
  Future<bool> checkPublicService(MirrorService service) async => false;
}
