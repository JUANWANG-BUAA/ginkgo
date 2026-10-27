import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

/// The today header carries the account / settings shortcut and the refresh
/// button. Both stay disabled while a read is in flight, so a tap can never
/// queue a second request behind the first one.
class TodayPageHeader extends StatelessWidget {
  const TodayPageHeader({
    super.key,
    required this.title,
    required this.busy,
    required this.onRefresh,
    this.onOpenSettings,
    this.onAccountAction,
    this.demo = false,
  });

  final String title;
  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onAccountAction;
  final bool demo;

  @override
  Widget build(BuildContext context) => ApplePageHeader(
    largeTitle: Text(title),
    border: null,
    section: '工作台',
    subtitle: '从今日课程开始安排一天',
    icon: CupertinoIcons.sun_max,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onOpenSettings != null || onAccountAction != null) ...[
          AppleGlassButton(
            key: const Key('workspace-settings'),
            label: onOpenSettings != null
                ? '设置'
                : demo
                ? '演示模式'
                : '账号',
            onPressed: onOpenSettings ?? (busy ? null : onAccountAction),
            child: Icon(
              onOpenSettings != null
                  ? CupertinoIcons.gear_alt
                  : demo
                  ? CupertinoIcons.eye
                  : CupertinoIcons.person_crop_circle,
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
        ],
        AppleGlassButton(
          label: '刷新今天',
          onPressed: busy ? null : onRefresh,
          child: busy
              ? const GinkgoActivity()
              : const Icon(CupertinoIcons.refresh, size: 24),
        ),
      ],
    ),
  );
}
