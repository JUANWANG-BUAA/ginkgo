import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/notices.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'today_action_row.dart';
import 'today_presentation.dart';

/// The latest school notices. A publication date is never a personal
/// deadline, so this section never creates a reminder.
class TodayNoticeSection extends StatelessWidget {
  const TodayNoticeSection({
    super.key,
    required this.section,
    required this.onRetry,
    required this.onOpen,
  });

  final RefreshSection<NoticesRead> section;
  final VoidCallback onRetry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final data = section.value;
    final notices = data?.data ?? const <Notice>[];
    if (data == null) {
      return TodayVisualSection(
        key: const Key('today-notices'),
        header: const TodaySectionHeader(
          icon: CupertinoIcons.news_solid,
          title: '校园通知',
        ),
        children: [
          SectionFeedback(
            loading: section.loading,
            label: '正在读取校园通知…',
            hasData: false,
            error: section.error,
            onRetry: onRetry,
          ),
        ],
      );
    }
    return TodayVisualSection(
      key: const Key('today-notices'),
      header: TodaySectionHeader(
        icon: CupertinoIcons.news_solid,
        title: '校园通知',
        actionLabel: '全部',
        onAction: onOpen,
      ),
      footer: const Text('通知来自学校公告，发布时间不是个人截止时间。'),
      children: [
        SummaryLine('最新通知', '${notices.length} 条'),
        if (section.error != null)
          SectionFeedback(
            loading: section.loading,
            label: '正在更新校园通知…',
            hasData: true,
            error: section.error,
            onRetry: onRetry,
          ),
        if (notices.isEmpty)
          const TodayActionRow(title: '暂时没有校园通知')
        else
          for (final notice in notices.take(3))
            TodayActionRow(
              key: Key('today-notice-${notice.publishedAt}-${notice.title}'),
              title: notice.title,
              subtitle: notice.publishedAt,
              onTap: onOpen,
            ),
      ],
    );
  }
}
