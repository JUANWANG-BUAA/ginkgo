import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart' show RouteChoice;
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/reminders.dart';
import 'package:ginkgo_mirror/workspace/workspace_catalog.dart';

/// Shared navigation state above the mobile/desktop breakpoint. The concrete
/// shells are injected so this controller never imports their implementations.
class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({
    super.key,
    required this.service,
    required this.mobileBuilder,
    required this.desktopBuilder,
    this.accountName,
    this.accountId,
    this.route,
    this.onSignOut,
  });

  final MirrorService service;
  final Widget Function(WorkspaceShellState shell) mobileBuilder;
  final Widget Function(WorkspaceShellState shell) desktopBuilder;
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

  int get mobileIndex {
    final index = mobileDestinations.indexWhere(
      (destination) => destination.id == selectedId,
    );
    return index < 0 ? 0 : index;
  }

  GlobalKey<NavigatorState> navigatorFor(String id) =>
      navigators.putIfAbsent(id, () => GlobalKey<NavigatorState>());

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
        ? widget.desktopBuilder(this)
        : widget.mobileBuilder(this),
  );
}
