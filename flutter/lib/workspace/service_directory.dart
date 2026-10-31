import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart' show RouteChoice;
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/reminders.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';
import 'package:ginkgo_mirror/workspace/workspace_types.dart';

/// Builds the context every feature row is opened with. The rows never
/// construct a page by hand: they go through the catalog so a feature keeps
/// one factory, one title and one icon everywhere.
WorkspaceContext buildDirectoryContext({
  required MirrorService service,
  required PlatformActions platformActions,
  required List<WorkspaceDestination> destinations,
  required Future<void> Function() onSignOut,
  String? accountName,
  String? accountId,
  RouteChoice? route,
  required void Function(String id) openDestination,
}) => WorkspaceContext(
  service: service,
  platformActions: platformActions,
  mobile: true,
  accountName: accountName,
  accountId: accountId,
  route: route,
  onSignOut: onSignOut,
  openFeature: openDestination,
  openSettings: () => openDestination('settings'),
);

/// The grouped feature list of the "更多" surface.
///
/// The tab bar owns the five primary destinations. The caller may promote
/// pinned destinations above this list; those IDs are omitted here so they
/// retain exactly one navigable row on the surface. Grouping mirrors the
/// shared Apple "More" list.
class ServiceDirectory extends StatelessWidget {
  const ServiceDirectory({
    super.key,
    required this.service,
    required this.platformActions,
    required this.destinations,
    required this.onSignOut,
    this.excludedDestinationIds = const {},
    this.accountName,
    this.accountId,
    this.route,
  });

  final MirrorService service;
  final PlatformActions platformActions;
  final List<WorkspaceDestination> destinations;
  final Future<void> Function() onSignOut;
  final Set<String> excludedDestinationIds;
  final String? accountName;
  final String? accountId;
  final RouteChoice? route;

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _section(
        context,
        header: '工作台',
        destinationIds: const ['checkin', 'tasks'],
        children: [
          _destination(
            context,
            'checkin',
            GinkgoColors.resourceBlue,
            badge: ReminderScope.of(context)?.unread('checkin') ?? 0,
          ),
          _destination(
            context,
            'tasks',
            GinkgoColors.accent,
            badge: ReminderScope.of(context)?.unread('tasks') ?? 0,
          ),
        ],
      ),
      _section(
        context,
        header: '学业',
        destinationIds: const ['grades', 'bykc', 'graduate', 'learning'],
        children: [
          _destination(context, 'grades', GinkgoColors.resourcePurple),
          _destination(context, 'bykc', GinkgoColors.resourceTeal),
          _destination(context, 'graduate', GinkgoColors.accent),
          _destination(context, 'learning', GinkgoColors.resourceBlue),
        ],
      ),
      _section(
        context,
        header: '空间资源',
        destinationIds: const ['cgyy', 'classroom'],
        children: [
          _destination(context, 'cgyy', GinkgoColors.resourcePurple),
          _destination(context, 'classroom', GinkgoColors.resourceTeal),
        ],
      ),
      _section(
        context,
        header: '图书与借阅',
        destinationIds: const ['library-loans'],
        children: [
          _destination(context, 'library-loans', GinkgoColors.resourceTeal),
        ],
      ),
      _section(
        context,
        header: '校园',
        destinationIds: const [
          'campus-card',
          'notices',
          'career-events',
          'campus-activities',
          'shuttle',
        ],
        children: [
          _destination(context, 'campus-card', GinkgoColors.accent),
          _destination(context, 'notices', GinkgoColors.resourceBlue),
          _destination(context, 'career-events', GinkgoColors.resourcePurple),
          _destination(context, 'campus-activities', GinkgoColors.resourceTeal),
          _destination(context, 'shuttle', GinkgoColors.resourceBlue),
        ],
      ),
      const SizedBox(height: GinkgoSpacing.xxl),
    ],
  );

  Widget _section(
    BuildContext context, {
    String? header,
    required List<String> destinationIds,
    required List<Widget> children,
  }) {
    final hasVisibleDestination = destinationIds.any(
      (id) =>
          !excludedDestinationIds.contains(id) && _destinationById(id) != null,
    );
    if (!hasVisibleDestination) return const SizedBox.shrink();
    return AppleSection(
      header: header == null ? null : Text(header),
      children: children,
    );
  }

  WorkspaceContext _featureContext(BuildContext context) =>
      buildDirectoryContext(
        service: service,
        platformActions: platformActions,
        destinations: destinations,
        onSignOut: onSignOut,
        accountName: accountName,
        accountId: accountId,
        route: route,
        openDestination: (id) => _pushDestination(context, id),
      );

  WorkspaceDestination? _destinationById(String id) {
    for (final destination in destinations) {
      if (destination.id == id) return destination;
    }
    return null;
  }

  void _pushDestination(BuildContext context, String id) {
    final destination = _destinationById(id);
    if (destination != null) {
      _push(context, destination.build(_featureContext(context)));
    }
  }

  /// Reuse the catalog metadata and factories, including the injected
  /// account context. A row never builds a second, parallel page.
  Widget _destination(
    BuildContext context,
    String id,
    Color tint, {
    int badge = 0,
  }) {
    final destination = _destinationById(id);
    if (destination == null || excludedDestinationIds.contains(id)) {
      return const SizedBox.shrink();
    }
    return AppleListTile(
      key: ValueKey('directory-$id'),
      leading: GinkgoIconTile(
        icon: destination.icon,
        size: 34,
        iconSize: 18,
        color: tint,
      ),
      leadingSize: 34,
      title: Text(destination.title),
      trailing: badge > 0
          ? Text(
              '$badge',
              style: TextStyle(
                fontSize: GinkgoTypography.callout.fontSize,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            )
          : const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: CupertinoColors.tertiaryLabel,
            ),
      onTap: () => _pushDestination(context, id),
    );
  }
}
