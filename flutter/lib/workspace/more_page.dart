import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart' show RouteChoice;
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/design/tokens/spacing.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/workspace/service_directory.dart';
import 'package:ginkgo_mirror/workspace/service_search.dart';
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
    required this.openFeature,
    this.accountName,
    this.accountId,
    this.route,
  });

  final MirrorService service;
  final PlatformActions platformActions;
  final List<WorkspaceDestination> destinations;
  final Future<void> Function() onSignOut;
  final ValueChanged<String> openFeature;
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
  final _searchController = TextEditingController();
  String _searchQuery = '';

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

  WorkspaceContext _workspaceContext(BuildContext context) =>
      buildDirectoryContext(
        service: widget.service,
        platformActions: widget.platformActions,
        destinations: widget.destinations,
        onSignOut: widget.onSignOut,
        accountName: widget.accountName,
        accountId: widget.accountId,
        route: widget.route,
        openDestination: widget.openFeature,
      );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              ServiceSearchContent(
                workspace: _workspaceContext(context),
                destinations: widget.destinations,
                controller: _searchController,
                query: _searchQuery,
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              if (_searchQuery.trim().isEmpty) ...[
                AppleSection(
                  children: [
                    AppleListTile(
                      key: const Key('more-account-settings'),
                      leading: const Icon(CupertinoIcons.person_crop_circle),
                      title: const Text('账号与设置'),
                      subtitle: const Text('账号、外观、通知与数据隐私'),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => widget.openFeature('settings'),
                    ),
                  ],
                ),
                WorkspaceShortcuts(
                  accountId: widget.accountId,
                  demo: widget.service.isDemo,
                  choices: choices,
                  onOpen: widget.openFeature,
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
                const SizedBox(height: GinkgoSpacing.bottomScrollClearance),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
