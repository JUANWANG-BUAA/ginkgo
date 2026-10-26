import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import '../application/contracts.dart' show RouteChoice;
import '../mirror_service.dart';
import 'package:ginkgo_mirror/workspace/workspace_catalog.dart';
import 'package:ginkgo_mirror/workspace/desktop_workspace_sidebar.dart';
import 'package:ginkgo_mirror/workspace/workspace_shell.dart' show WorkspaceShellState;

/// 桌面侧栏壳：侧栏 + IndexedStack 惰性挂载各目的地。选中状态、已访问
/// 集合与导航栈 key 由 [WorkspaceShellState] 持有，与移动壳共享。
class DesktopWorkspaceShell extends StatelessWidget {
  const DesktopWorkspaceShell({
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

  WorkspaceContext _contextFor() => WorkspaceContext(
    service: service,
    mobile: false,
    accountName: accountName,
    accountId: accountId,
    route: route,
    onSignOut: onSignOut,
    // 移动端专属的“预约”聚合页在桌面没有对应目的地，沿用旧行为落到图书馆。
    openFeature: (id) => shell.select(id == 'reservations' ? 'library' : id),
    openSettings: () => shell.select('settings'),
  );

  @override
  Widget build(BuildContext context) {
    final selected = shell.selectedId;
    return Row(
      children: [
        Container(
          key: const Key('desktop-sidebar'),
          width: GinkgoLayout.desktopSidebarWidth,
          color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                workspaceBrandIdentity(
                  context,
                  accountName: accountName,
                  isDemo: service.isDemo,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    children: [
                      for (final section in WorkspaceSection.values) ...[
                        _section(section.title),
                        for (final destination in sidebarDestinations(section))
                          workspaceSidebarItem(
                            context,
                            destination: destination,
                            selected: selected == destination.id,
                            onPressed: () => shell.select(destination.id),
                          ),
                      ],
                    ],
                  ),
                ),
                workspaceSidebarFooter(
                  context,
                  isSelected: (id) => selected == id,
                  onSelect: shell.select,
                ),
              ],
            ),
          ),
        ),
        Container(
          width: 0.5,
          color: CupertinoColors.separator.resolveFrom(context),
        ),
        Expanded(
          child: Container(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: IndexedStack(
              index: workspaceDestinations.indexWhere(
                (destination) => destination.id == selected,
              ),
              children: [
                for (final destination in workspaceDestinations)
                  if (shell.visited.contains(destination.id))
                    ExcludeFocus(
                      excluding: selected != destination.id,
                      child: TickerMode(
                        enabled: selected == destination.id,
                        child: CupertinoTabView(
                          key: ValueKey('desktop-destination-${destination.id}'),
                          navigatorKey: shell.navigatorFor(destination.id),
                          builder: (_) => destination.build(_contextFor()),
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: CupertinoColors.secondaryLabel,
      ),
    ),
  );
}
