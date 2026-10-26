import 'package:flutter/cupertino.dart';

import '../application/contracts.dart' show RouteChoice;
import '../mirror_service.dart';
import '../reminder_badge.dart';
import '../reminders.dart';
import '../workspace_back_guard.dart';
import '../workspace_catalog.dart';
import 'workspace_shell.dart' show WorkspaceShellState;
import '../workspace_tab_transition.dart';

/// 移动标签壳：底部导航 + 每个目的地一个常驻导航栈。选中状态与导航栈
/// key 由 [WorkspaceShellState] 持有，跨断点旋转时随共享壳层保留。
class MobileWorkspaceShell extends StatefulWidget {
  const MobileWorkspaceShell({
    super.key,
    required this.shell,
    required this.service,
    this.accountName,
    this.accountId,
    this.route,
    this.onSignOut,
  });
  final WorkspaceShellState shell;
  final MirrorService service;
  final String? accountName;
  final String? accountId;
  final RouteChoice? route;
  final Future<void> Function()? onSignOut;
  @override
  State<MobileWorkspaceShell> createState() => _MobileWorkspaceShellState();
}

class _MobileWorkspaceShellState extends State<MobileWorkspaceShell> {
  late final tabs = CupertinoTabController(
    initialIndex: widget.shell.mobileIndex,
  );
  final back = WorkspaceBackController();

  @override
  void initState() {
    super.initState();
    // Whatever tab this shell actually starts on becomes the selection, so a
    // desktop-only destination does not survive an impossible mobile state.
    widget.shell.onMobileTab(tabs.index);
    tabs.addListener(back.disarm);
    tabs.addListener(_readActive);
  }

  @override
  void dispose() {
    tabs.removeListener(back.disarm);
    tabs.removeListener(_readActive);
    back.dispose();
    tabs.dispose();
    super.dispose();
  }

  void _readActive() {
    widget.shell.onMobileTab(tabs.index);
    ReminderScope.of(context)?.setActive(mobileDestinations[tabs.index].id);
  }

  WorkspaceContext _contextFor(BuildContext navigatorContext) =>
      WorkspaceContext(
        service: widget.service,
        mobile: true,
        accountName: widget.accountName,
        accountId: widget.accountId,
        route: widget.route,
        onSignOut: widget.onSignOut,
        openFeature: (id) {
          final index = mobileDestinations.indexWhere(
            (destination) => destination.id == id,
          );
          if (!mounted || !navigatorContext.mounted) return;
          if (index >= 0) {
            tabs.index = index;
            return;
          }
          final destination = destinationById(id);
          if (destination == null) return;
          Navigator.of(navigatorContext).push(
            CupertinoPageRoute<void>(
              builder: (detailContext) =>
                  destination.build(_contextFor(detailContext)),
            ),
          );
        },
        openSettings: () => Navigator.of(navigatorContext).push(
          CupertinoPageRoute<void>(
            builder: (_) =>
                destinationById('settings')!
                    .build(_contextFor(navigatorContext)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final destinations = mobileDestinations;
    return guardWorkspaceBack(
      // Keep Android back delivery in Flutter while a newly selected tab's
      // navigator is mounting. Its own first-route guard handles the action.
      onBack: () {},
      child: Stack(
        children: [
          WorkspaceTabMotion(
            controller: tabs,
            child: WorkspaceTabScaffold(
              controller: tabs,
              tabBar: CupertinoTabBar(
                items: [
                  for (final destination in destinations)
                    BottomNavigationBarItem(
                      icon: ReminderBadge(
                        count:
                            ReminderScope.of(context)?.unread(destination.id) ??
                            0,
                        child: Icon(destination.icon),
                      ),
                      label: destination.mobileLabel ?? destination.title,
                    ),
                ],
              ),
              tabBuilder: (tabContext, index) => WorkspaceTabTransition(
                index: index,
                child: CupertinoTabView(
                  navigatorKey: widget.shell.navigatorFor(
                    destinations[index].id,
                  ),
                  navigatorObservers: [_DisarmExitOnNavigation(back)],
                  builder: (navigatorContext) => guardWorkspaceBack(
                    onBack: () => back.back(
                      atWorkspace: tabs.index == 0,
                      goToWorkspace: () => tabs.index = 0,
                    ),
                    child: destinations[index].build(
                      _contextFor(navigatorContext),
                    ),
                  ),
                ),
              ),
            ),
          ),
          WorkspaceBackHint(controller: back),
        ],
      ),
    );
  }
}

class _DisarmExitOnNavigation extends NavigatorObserver {
  _DisarmExitOnNavigation(this.back);
  final WorkspaceBackController back;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    back.disarm();
  }
}
