import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart' show RouteChoice;
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/workspace/service_directory.dart';
import 'package:ginkgo_mirror/workspace/workspace_shortcut_preferences.dart';
import 'package:ginkgo_mirror/workspace/workspace_shortcuts.dart';
import 'package:ginkgo_mirror/workspace/workspace_types.dart';

/// The "更多" surface: the five primary destinations live in the tab bar,
/// everything else lives here.
///
/// Pinned services are promoted to the top of this list and removed from their
/// normal group below, so every service has one navigable row on this surface.
class MorePage extends StatefulWidget {
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

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  late Set<String> _pinnedIds;

  @override
  void initState() {
    super.initState();
    _pinnedIds = _defaultPinnedIds();
  }

  @override
  void didUpdateWidget(covariant MorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId ||
        oldWidget.service != widget.service ||
        oldWidget.destinations != widget.destinations) {
      _pinnedIds = _defaultPinnedIds();
    }
  }

  Set<String> _defaultPinnedIds() => WorkspaceShortcutPreferences.defaultIds
      .where(
        (id) =>
            !MorePage.tabIds.contains(id) &&
            widget.destinations.any((destination) => destination.id == id),
      )
      .toSet();

  void _updatePinnedIds(Set<String> ids) {
    if (_pinnedIds.length == ids.length && _pinnedIds.containsAll(ids)) return;
    setState(() => _pinnedIds = Set.of(ids));
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));
  }

  WorkspaceDestination? _destinationById(String id) {
    for (final destination in widget.destinations) {
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
          service: widget.service,
          platformActions: widget.platformActions,
          destinations: widget.destinations,
          onSignOut: widget.onSignOut,
          accountName: widget.accountName,
          accountId: widget.accountId,
          route: widget.route,
          openDestination: (target) => _pushDestination(context, target),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final choices = [
      for (final destination in widget.destinations)
        if (!MorePage.tabIds.contains(destination.id))
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
                accountId: widget.accountId,
                demo: widget.service.isDemo,
                choices: choices,
                onOpen: (id) => _pushDestination(context, id),
                onSelectedIdsChanged: _updatePinnedIds,
              ),
              ServiceDirectory(
                service: widget.service,
                platformActions: widget.platformActions,
                destinations: widget.destinations,
                excludedDestinationIds: _pinnedIds,
                onSignOut: widget.onSignOut,
                accountName: widget.accountName,
                accountId: widget.accountId,
                route: widget.route,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
