import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/apple_controls.dart';
import 'package:ginkgo_mirror/widgets/apple_surfaces.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

class AppleRefreshPageHeader extends StatelessWidget {
  const AppleRefreshPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.section = '空间资源',
    this.refreshLabel,
    this.busy = false,
    this.onRefresh,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String section;
  final String? refreshLabel;
  final bool busy;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) => ApplePageHeader(
    largeTitle: Text(title),
    section: section,
    subtitle: subtitle,
    icon: icon,
    border: null,
    trailing: refreshLabel == null
        ? null
        : AppleGlassButton(
            label: refreshLabel!,
            onPressed: busy || onRefresh == null ? null : () => onRefresh!(),
            child: busy
                ? const GinkgoActivity(size: 17)
                : const Icon(CupertinoIcons.refresh, size: 24),
          ),
  );
}

class AppleStatusSection extends StatelessWidget {
  const AppleStatusSection({
    super.key,
    required this.title,
    required this.description,
    this.action,
    this.onAction,
    this.error = false,
    this.animateSize = true,
  });

  final String title;
  final String description;
  final String? action;
  final VoidCallback? onAction;
  final bool error;
  final bool animateSize;

  @override
  Widget build(BuildContext context) => AppleSection(
    animateSize: animateSize,
    children: [
      AppleEmptyState(
        title: title,
        description: description,
        action: action ?? (onAction == null ? null : '重试'),
        onAction: onAction,
        error: error,
      ),
    ],
  );
}
