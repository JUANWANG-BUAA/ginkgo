import 'package:flutter/cupertino.dart';

import '../application/contracts.dart' show RouteChoice;
import '../application/platform_actions.dart';

import 'package:ginkgo_mirror/shared/course_visibility.dart';
import 'package:ginkgo_mirror/widgets/diagnostic_hints.dart';
import 'package:ginkgo_mirror/app/ginkgo_app.dart';
import 'package:ginkgo_mirror/infrastructure/reminder_store.dart';
import 'package:ginkgo_mirror/infrastructure/native_reminder_platform.dart';
import 'package:ginkgo_mirror/infrastructure/serial_reminder_platform.dart';
import 'package:ginkgo_mirror/infrastructure/task_storage.dart';

import '../mirror_service.dart';

import 'package:ginkgo_mirror/shared/query_cache_scope.dart';
import 'package:ginkgo_mirror/shared/reminders.dart';
import 'package:ginkgo_mirror/platform/startup_update.dart';
import 'package:ginkgo_mirror/workspace/desktop_workspace_shell.dart';
import 'package:ginkgo_mirror/workspace/mobile_workspace_shell.dart';
import 'package:ginkgo_mirror/workspace/workspace_shell_controller.dart';

// 保持历史导入面：调用方与测试仍从本文件取应用根与主题。
export 'package:ginkgo_mirror/app/ginkgo_app.dart' show ginkgoApp;
export 'package:ginkgo_mirror/design/ginkgo_theme.dart' show ginkgoTheme;
export 'package:ginkgo_mirror/workspace/workspace_shell_controller.dart'
    show WorkspaceShell, WorkspaceShellState;

/// 工作区外壳：只负责会话切换、移动/桌面布局与功能登记表的消费，
/// 具体页面由 workspace_catalog.dart 登记，壳层不维护功能索引。
class GinkgoApp extends StatelessWidget {
  const GinkgoApp({
    super.key,
    required this.service,
    this.platformActions = const PlatformActions(),
    this.brightness,
    this.startupUpdate,
    this.accountName,
    this.accountId,
    this.route,
    this.onSignOut,
  });
  final MirrorService service;

  /// The platform actions the pages may use. The app root binds the real
  /// implementations; a test that does not need them keeps them empty.
  final PlatformActions platformActions;
  final Brightness? brightness;
  final StartupUpdateController? startupUpdate;
  final String? accountName;
  final String? accountId;
  final RouteChoice? route;
  final Future<void> Function()? onSignOut;
  @override
  Widget build(BuildContext context) => ginkgoApp(
    brightness: brightness,
    startupUpdate: startupUpdate,
    home: CourseVisibilityScope(
      key: ValueKey(service.isDemo ? 'demo' : accountId ?? 'account'),
      account: service.isDemo ? '__demo__' : accountId ?? '__account__',
      child: ReminderScope(
        service: service,
        account: service.isDemo ? '__demo__' : accountId ?? '__account__',
        controllerFactory: _createReminderController,
        child: DiagnosticHintOverlay(
          child: QueryCacheScope(
            child: WorkspaceShell(
              service: service,
              platformActions: platformActions,
              accountName: accountName,
              accountId: accountId,
              route: route,
              onSignOut: onSignOut,
              mobileBuilder: (shell) => MobileWorkspaceShell(
                shell: shell,
                service: service,
                platformActions: platformActions,
                accountName: accountName,
                accountId: accountId,
                route: route,
                onSignOut: onSignOut,
              ),
              desktopBuilder: (shell) => DesktopWorkspaceShell(
                shell: shell,
                service: service,
                platformActions: platformActions,
                accountName: accountName,
                accountId: accountId,
                route: route,
                onSignOut: onSignOut,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

final _reminderPlatform = SerialReminderPlatform(
  const NativeReminderPlatform(),
);

ReminderController _createReminderController(
  MirrorService service,
  String account,
  CourseVisibility? visibility,
) => ReminderController(
  service: service,
  account: account,
  visibility: visibility,
  store: FileReminderStore(account),
  tasksRoot: localTasksStorageRoot,
  platform: _reminderPlatform,
);
