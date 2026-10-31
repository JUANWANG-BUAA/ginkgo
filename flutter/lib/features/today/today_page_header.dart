import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

/// The today header carries the page refresh action; account settings live in
/// the dedicated workspace destination.
class TodayPageHeader extends StatelessWidget {
  const TodayPageHeader({
    super.key,
    required this.title,
    required this.busy,
    required this.onRefresh,
  });

  final String title;
  final bool busy;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => ApplePageHeader(
    largeTitle: Text(title),
    border: null,
    section: '工作台',
    subtitle: '从今日课程开始安排一天',
    icon: CupertinoIcons.sun_max,
    trailing: AppleToolbarButton(
      label: '刷新今天',
      busy: busy,
      onPressed: busy ? null : onRefresh,
      child: busy
          ? const GinkgoActivity()
          : const Icon(CupertinoIcons.refresh, size: 24),
    ),
  );
}
