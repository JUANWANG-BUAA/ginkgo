import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart' show RouteChoice;
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/application/service_capabilities.dart';

enum WorkspaceSection {
  workbench('工作台'),
  academics('学业'),
  spaces('空间资源'),
  campus('校园');

  const WorkspaceSection(this.title);
  final String title;
}

/// Page construction context: capabilities are resolved once above the page.
class WorkspaceContext {
  WorkspaceContext({
    required this.service,
    required this.platformActions,
    required this.mobile,
    required this.openFeature,
    required this.openSettings,
    this.accountName,
    this.accountId,
    this.route,
    this.onSignOut,
  }) : capabilities = ServiceCapabilities.resolve(service);

  final MirrorService service;

  /// The platform actions the pages may use, bound once by the composition
  /// root. A page never names an adapter itself.
  final PlatformActions platformActions;
  final ServiceCapabilities capabilities;
  final bool mobile;
  final String? accountName;
  final String? accountId;
  final RouteChoice? route;
  final Future<void> Function()? onSignOut;
  final ValueChanged<String> openFeature;
  final VoidCallback openSettings;
}

class WorkspaceDestination {
  const WorkspaceDestination({
    required this.id,
    required this.title,
    required this.icon,
    required this.build,
    this.mobileLabel,
    this.section,
    this.mobileTab,
    this.sidebar = true,
    this.footer = false,
  });

  final String id;
  final String title;
  final IconData icon;
  final Widget Function(WorkspaceContext context) build;
  final String? mobileLabel;
  final WorkspaceSection? section;
  final int? mobileTab;
  final bool sidebar;
  final bool footer;
}
