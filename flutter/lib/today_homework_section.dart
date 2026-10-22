import 'package:flutter/cupertino.dart';

import 'application/contracts.dart';
import 'application/refresh_section.dart';
import 'course_visibility.dart';
import 'homework_projection.dart';
import 'loading_widgets.dart';
import 'today_action_row.dart';
import 'today_time.dart';
import 'today_presentation.dart';

/// A separate read can finish before or after today's timetable.
class TodayHomeworkSection extends StatelessWidget {
  const TodayHomeworkSection({
    super.key,
    required this.section,
    required this.onRetry,
    this.onOpen,
    this.onOpenItem,
    this.now,
  });
  final RefreshSection<HomeworkResponse> section;
  final VoidCallback onRetry;
  final VoidCallback? onOpen;
  final ValueChanged<HomeworkItem>? onOpenItem;

  /// Beijing wall time, injected for deterministic rendering.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final data = section.value;
    final personal = personalHomeworkItems(
      data?.items ?? [],
      CourseVisibilityScope.of(context),
    );
    final pending =
        personal.where((item) => item.status == HomeworkStatus.pending).toList()
          ..sort((a, b) => todayCompareDue(a.dueAt, b.dueAt));
    final unknown = personal.where(
      (item) => item.status == HomeworkStatus.unknown,
    );
    final clock = now ?? todaySchoolNow(DateTime.now());
    return TodayVisualSection(
      key: const Key('today-homework'),
      header: const Text('学校作业'),
      footer: const Text('个人课程作业 · 不含助教课程\n学校状态与个人待办独立；截止时间按北京时间显示'),
      children: [
        if (section.loading || section.error != null)
          SectionFeedback(
            loading: section.loading,
            label: data == null ? '正在检查学校作业…' : '正在更新学校作业…',
            hasData: data != null,
            error: section.error,
            onRetry: onRetry,
          ),
        if (data != null)
          SectionReveal(
            child: Column(
              children: [
                TodayActionRow(
                  summary: true,
                  title: pending.isNotEmpty
                      ? '${pending.length} 项作业待处理'
                      : section.error != null || unknown.isNotEmpty
                      ? '作业状态尚未确认'
                      : '当前没有待处理作业',
                  subtitle: unknown.isEmpty
                      ? null
                      : '${unknown.length} 项状态待确认，请进入作业核对',
                  onTap: onOpen,
                ),
                for (final item in pending.take(3)) ...[
                  const TodayVisualDivider(),
                  TodayActionRow(
                    key: Key('today-homework-item-${item.id}'),
                    title: item.title,
                    subtitle: item.courseName,
                    status: todayDueLabel(item.dueAt, clock),
                    onTap: onOpenItem == null
                        ? onOpen
                        : () => onOpenItem!(item),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
