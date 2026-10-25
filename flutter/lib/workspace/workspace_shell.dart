import 'package:flutter/cupertino.dart';

import '../apple_design.dart';
import '../application/contracts.dart' show RouteChoice;
import '../course_visibility.dart';
import '../diagnostic_hints.dart';
import '../ginkgo_app.dart';
import '../mirror_service.dart';
import '../query_cache_scope.dart';
import '../reminders.dart';
import '../startup_update.dart';
import '../workspace_catalog.dart';
import 'desktop_workspace_shell.dart';
import 'mobile_workspace_shell.dart';

// 保持历史导入面：调用方与测试仍从本文件取应用根与主题。
export '../ginkgo_app.dart' show ginkgoApp;
export '../ginkgo_theme.dart' show ginkgoTheme;

/// 工作区外壳：只负责会话切换、移动/桌面布局与功能登记表的消费，
/// 具体页面由 workspace_catalog.dart 登记，壳层不维护功能索引。
class GinkgoApp extends StatelessWidget {
  const GinkgoApp({
    super.key,
    required this.service,
    this.brightness,
    this.startupUpdate,
    this.accountName,
    this.accountId,
    this.route,
    this.onSignOut,
  });
  final MirrorService service;
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
        child: DiagnosticHintOverlay(
          child: QueryCacheScope(child: WorkspaceShell(service: service)),
        ),
      ),
    ),
  );
}

/// 断点两侧共享的壳层状态。旋转跨越 760dp 时移动标签壳与桌面侧栏壳会
/// 整体重建；把选中目的地、已访问集合与各目的地的导航栈 key 提升到断点
/// 之上，配合每个目的地复用的 navigator GlobalKey，跨断点旋转不再丢失
/// 当前位置与已推入的页面（含未提交表单）。
class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({
    super.key,
    required this.service,
    this.accountName,
    this.accountId,
    this.route,
    this.onSignOut,
  });
  final MirrorService service;
  final String? accountName;
  final String? accountId;
  final RouteChoice? route;
  final Future<void> Function()? onSignOut;
  @override
  State<WorkspaceShell> createState() => WorkspaceShellState();
}

class WorkspaceShellState extends State<WorkspaceShell> {
  String selectedId = mobileDestinations.first.id;
  final navigators = <String, GlobalKey<NavigatorState>>{};
  final Set<String> visited = {};

  WorkspaceShellState() {
    visited.add(selectedId);
  }

  /// 桌面选中的目的地可能是移动端没有的页面（如成绩）；此时移动壳回到
  /// 第一个标签，并让实际展示的标签成为新的选中目的地。
  int get mobileIndex {
    final index = mobileDestinations.indexWhere(
      (destination) => destination.id == selectedId,
    );
    return index < 0 ? 0 : index;
  }

  GlobalKey<NavigatorState> navigatorFor(String id) =>
      navigators.putIfAbsent(id, () => GlobalKey<NavigatorState>());

  /// 移动标签切换只同步字段不触发重建：可见页面已由 tab 控制器驱动。
  void onMobileTab(int index) {
    final id = mobileDestinations[index].id;
    selectedId = id;
    visited.add(id);
  }

  void select(String id) {
    ReminderScope.of(context)?.setActive(id);
    if (selectedId == id) {
      navigators[id]?.currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() {
      selectedId = id;
      visited.add(id);
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        constraints.maxWidth >= GinkgoLayout.desktopBreakpoint
        ? DesktopWorkspaceShell(
            shell: this,
            service: widget.service,
            accountName: widget.accountName,
            accountId: widget.accountId,
            route: widget.route,
            onSignOut: widget.onSignOut,
          )
        : MobileWorkspaceShell(
            shell: this,
            service: widget.service,
            accountName: widget.accountName,
            accountId: widget.accountId,
            route: widget.route,
            onSignOut: widget.onSignOut,
          ),
  );
}
