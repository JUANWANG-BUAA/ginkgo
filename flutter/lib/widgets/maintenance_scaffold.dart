import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';

class MaintenanceScaffold extends StatelessWidget {
  const MaintenanceScaffold({
    super.key,
    required this.title,
    required this.children,
    this.onRefresh,
    this.busy = false,
    this.section,
    this.subtitle,
    this.icon,
  });
  final String title;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final bool busy;
  final String? section, subtitle;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: SafeArea(
      child: CustomScrollView(
        key: ValueKey('maintenance-$title'),
        slivers: [
          ApplePageHeader(
            largeTitle: Text(title),
            border: null,
            section: section,
            subtitle: subtitle,
            icon: icon,
          ),
          if (onRefresh != null)
            CupertinoSliverRefreshControl(onRefresh: onRefresh),
          SliverList.list(children: [...children, const SizedBox(height: 96)]),
        ],
      ),
    ),
  );
}
