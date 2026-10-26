import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/shared/reminders.dart';
import 'package:ginkgo_mirror/workspace/workspace_catalog.dart';

/// 品牌区与侧栏条目：桌面壳的静态装饰部分，不持有任何状态。
Widget workspaceBrandIdentity(
  BuildContext context, {
  required String? accountName,
  required bool isDemo,
}) {
  final accent = CupertinoTheme.of(context).primaryColor;
  final accountText = accountName ?? (isDemo ? '离线演示' : '校园工作台');
  return Container(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: CupertinoColors.separator
              .resolveFrom(context)
              .withValues(alpha: 0.16),
          width: 0.5,
        ),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, accent.withValues(alpha: 0.72)],
            ),
          ),
          child: const Center(
            child: Icon(
              CupertinoIcons.leaf_arrow_circlepath,
              size: 20,
              color: CupertinoColors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ginkgo',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      accountText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDemo
                          ? GinkgoColors.connectionOffline
                          : GinkgoColors.connectionOnline,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isDemo ? '演示' : '已连接',
                    style: TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget workspaceSidebarItem(
  BuildContext context, {
  required WorkspaceDestination destination,
  required bool selected,
  required VoidCallback onPressed,
}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
  child: AppleNavigationItem(
    key: ValueKey('desktop-sidebar-${destination.id}'),
    title: destination.title,
    unreadCount: ReminderScope.of(context)?.unread(destination.id) ?? 0,
    icon: destination.icon,
    selected: selected,
    onPressed: onPressed,
  ),
);

Widget workspaceSidebarFooter(
  BuildContext context, {
  required bool Function(String id) isSelected,
  required void Function(String id) onSelect,
}) => Container(
  decoration: BoxDecoration(
    border: Border(
      top: BorderSide(
        color: CupertinoColors.separator
            .resolveFrom(context)
            .withValues(alpha: 0.16),
        width: 0.5,
      ),
    ),
  ),
  padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final destination in footerDestinations)
        workspaceSidebarItem(
          context,
          destination: destination,
          selected: isSelected(destination.id),
          onPressed: () => onSelect(destination.id),
        ),
    ],
  ),
);
