import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';
import 'package:ginkgo_mirror/features/settings/preferences_pages.dart';
import 'package:ginkgo_mirror/workspace/workspace_shell.dart';
import 'package:ginkgo_mirror/features/today/today_page.dart';
import 'package:ginkgo_mirror/features/tasks/tasks_page.dart';
import 'package:ginkgo_mirror/workspace/workspace_catalog.dart';
import 'package:ginkgo_mirror/workspace/more_page.dart';

import 'ios_visual_refinement_test.dart' show VisualService;
import 'support.dart' show platformActions, settle, show;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  var converted = false;
  Future<void> capture(WidgetTester tester, String name) async {
    await settle(tester, frames: 5);
    expect(tester.takeException(), isNull);
    if (!converted) {
      await binding.convertFlutterSurfaceToImage();
      converted = true;
    }
    await binding.takeScreenshot(name);
  }

  testWidgets(
    'synthetic compact workspace, shortcuts, tasks and theme previews',
    (tester) async {
      final service = VisualService();
      final settings = AppPreferences(writer: (_) async {});
      for (final brightness in Brightness.values) {
        await settings.update(
          appearance: brightness == Brightness.dark
              ? AppAppearance.dark
              : AppAppearance.light,
          accent: brightness == Brightness.dark
              ? AppAccent.teal
              : AppAccent.amber,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          ginkgoApp(
            preferences: settings,
            home: TodayPage(
              fileActions: platformActions,
              service: service,
              storageRoot: '/synthetic-visual-only',
              accountId: 'synthetic-demo',
              now: () => DateTime.utc(2026, 10, 22, 1, 40),
              onOpenFeature: (_) {},
            ),
          ),
        );
        await settle(tester, frames: 20);
        expect(find.text('算法设计与分析'), findsNothing);
        await capture(tester, 'polish-today-${brightness.name}');
        // The pinned shortcuts live on the "更多" surface now.
        await tester.pumpWidget(
          ginkgoApp(
            preferences: settings,
            home: MorePage(
              service: service,
              platformActions: platformActions,
              destinations: workspaceDestinations,
              accountId: 'synthetic-demo',
              onSignOut: () async {},
              openFeature: (_) {},
            ),
          ),
        );
        await settle(tester, frames: 20);
        await show(
          tester,
          find.byKey(const Key('shortcuts-edit')),
          scrollKey: 'more-scroll',
        );
        await capture(tester, 'polish-shortcuts-${brightness.name}');
        await tester.tap(find.byKey(const Key('shortcuts-edit')));
        await settle(tester);
        await show(
          tester,
          find.byKey(const ValueKey('shortcut-choice-checkin')),
          scrollKey: 'more-scroll',
        );
        await capture(tester, 'polish-shortcuts-edit-${brightness.name}');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          ginkgoApp(
            preferences: settings,
            home: TasksPage(
              fileActions: platformActions,
              service: service,
              academicService: service,
              storageRoot: '/synthetic-visual-only',
            ),
          ),
        );
        await settle(tester, frames: 20);
        expect(find.text('阅读课程参考资料'), findsNothing);
        await capture(tester, 'polish-tasks-${brightness.name}');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          ginkgoApp(preferences: settings, home: const AppearancePage()),
        );
        await settle(tester, frames: 15);
        await show(
          tester,
          find.byKey(const ValueKey('accent-course-preview')),
          scrollKey: 'maintenance-显示与阅读',
        );
        await capture(tester, 'polish-theme-preview-${brightness.name}');
        await show(
          tester,
          find.byKey(const ValueKey('accent-amber')),
          scrollKey: 'maintenance-显示与阅读',
        );
        await capture(tester, 'polish-appearance-${brightness.name}');
      }
      expect(service.writes, 0);
      await tester.pumpWidget(const SizedBox());
      await settle(tester, frames: 3);
      settings.dispose();
    },
  );
}
