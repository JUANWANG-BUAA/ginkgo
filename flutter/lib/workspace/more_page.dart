import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart' show RouteChoice;
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/workspace/service_directory.dart';
import 'package:ginkgo_mirror/workspace/workspace_shortcuts.dart';
import 'package:ginkgo_mirror/workspace/workspace_types.dart';

/// The "更多" surface: the five primary destinations live in the tab bar,
/// everything else lives here.
///
/// The page owns one job — list the remaining features and let the user pin
/// the ones they use most. It never shows today's data, so it can never
/// duplicate the workbench.
class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    required this.service,
    required this.platformActions,
    required this.destinations,
    required this.onSignOut,
    this.accountName,
    this.accountId,
    this.route,
  });

  final MirrorService service;
  final PlatformActions platformActions;
  final List<WorkspaceDestination> destinations;
  final Future<void> Function() onSignOut;
  final String? accountName;
  final String? accountId;
  final RouteChoice? route;

  /// Destinations that already own a tab do not repeat in the list.
  static const tabIds = {'today', 'schedule', 'homework', 'library', 'more'};

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));
  }

  WorkspaceDestination? _destinationById(String id) {
    for (final destination in destinations) {
      if (destination.id == id) return destination;
    }
    return null;
  }

  void _pushDestination(BuildContext context, String id) {
    final destination = _destinationById(id);
    if (destination == null) return;
    _push(
      context,
      destination.build(
        buildDirectoryContext(
          service: service,
          platformActions: platformActions,
          destinations: destinations,
          onSignOut: onSignOut,
          accountName: accountName,
          accountId: accountId,
          route: route,
          openDestination: (target) => _pushDestination(context, target),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final choices = [
      for (final destination in destinations)
        if (!tabIds.contains(destination.id))
          WorkspaceShortcut(
            id: destination.id,
            title: destination.title,
            icon: destination.icon,
          ),
    ];
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: CustomScrollView(
        key: const Key('more-scroll'),
        slivers: [
          ApplePageHeader(
            largeTitle: const Text('更多'),
            section: '工作台',
            subtitle: '全部功能与服务入口',
            icon: CupertinoIcons.ellipsis_circle_fill,
            border: null,
          ),
          SliverList.list(
            children: [
              WorkspaceShortcuts(
                accountId: accountId,
                demo: service.isDemo,
                choices: choices,
                onOpen: (id) => _pushDestination(context, id),
              ),
              ServiceDirectory(
                service: service,
                platformActions: platformActions,
                destinations: destinations,
                onSignOut: onSignOut,
                accountName: accountName,
                accountId: accountId,
                route: route,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
