import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

/// Stale-result notice shown when a previous snapshot is still displayed.
/// The snapshot itself stays untouched; only the warning is rendered.
class ClassroomNoticeTile extends StatelessWidget {
  const ClassroomNoticeTile({super.key, required this.notice});
  final String notice;

  @override
  Widget build(BuildContext context) => AppleSection(
    animateSize: false,
    children: [
      AppleListTile(
        key: const Key('classroom-stale-notice'),
        leading: const Icon(
          CupertinoIcons.exclamationmark_triangle,
          color: CupertinoColors.systemOrange,
          size: 20,
        ),
        title: Text(notice),
      ),
    ],
  );
}

/// Message panel used for failures and for the state before the first query.
/// It never claims that a room was booked or reserved.
class ClassroomMessageState extends StatelessWidget {
  const ClassroomMessageState({
    super.key,
    required this.title,
    required this.description,
    this.error = false,
    this.action,
    this.onAction,
  });
  final String title, description;
  final bool error;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => AppleSection(
    animateSize: false,
    children: [
      AppleEmptyState(
        title: title,
        description: description,
        error: error,
        action: action,
        onAction: onAction,
      ),
    ],
  );
}

/// First read of the page. The detail line names the step that is running.
class ClassroomLoadingState extends StatelessWidget {
  const ClassroomLoadingState({super.key, required this.initializing});
  final bool initializing;

  @override
  Widget build(BuildContext context) => AppleSection(
    animateSize: false,
    children: [
      GinkgoLoadingView(
        label: '正在读取空教室…',
        detail: initializing ? '正在读取学校日期' : null,
      ),
    ],
  );
}

/// Refresh on top of an existing result. The previous snapshot stays visible
/// until the new one arrives.
class ClassroomRefreshingState extends StatelessWidget {
  const ClassroomRefreshingState({super.key});

  @override
  Widget build(BuildContext context) => AppleSection(
    animateSize: false,
    children: [
      Padding(
        key: const Key('classroom-refreshing'),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const GinkgoActivity(size: 17),
            const SizedBox(width: 10),
            Text('正在刷新空教室…'),
          ],
        ),
      ),
    ],
  );
}
