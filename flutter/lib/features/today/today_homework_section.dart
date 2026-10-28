import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/features/schedule/course_visibility.dart';
import 'package:ginkgo_mirror/features/homework/homework_projection.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'today_action_row.dart';

import 'package:ginkgo_mirror/shared/today_time.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';

import 'today_presentation.dart';

/// The exact rows rendered on the dashboard, also used to avoid hiding an
/// associated local task when its assignment is not actually visible.
List<HomeworkItem> todayVisibleHomework(
  HomeworkResponse? data,
  CourseVisibility? visibility,
  DateTime now,
) {
  final pending =
      personalHomeworkItems(data?.items ?? [], visibility)
          .where(
            (item) =>
                item.status == HomeworkStatus.pending &&
                !isHomeworkOverdue(item.dueAt, now),
          )
          .toList()
        ..sort((a, b) => todayCompareDue(a.dueAt, b.dueAt));
  return pending.take(3).toList(growable: false);
}

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
    final clock = now ?? todaySchoolNow(DateTime.now());
    final pending =
        personal
            .where(
              (item) =>
                  item.status == HomeworkStatus.pending &&
                  !isHomeworkOverdue(item.dueAt, clock),
            )
            .toList()
          ..sort((a, b) => todayCompareDue(a.dueAt, b.dueAt));
    final overdue =
        personal
            .where(
              (item) =>
                  item.status == HomeworkStatus.pending &&
                  isHomeworkOverdue(item.dueAt, clock),
            )
            .toList()
          ..sort((a, b) => todayCompareDue(a.dueAt, b.dueAt));
    final unknown = personal.where(
      (item) => item.status == HomeworkStatus.unknown,
    );
    final unknownRole =
        data?.rolesComplete != true ||
        personal.any((item) => item.courseRole == null);
    return TodayVisualSection(
      key: const Key('today-homework'),
      header: TodaySectionHeader(
        icon: CupertinoIcons.book_fill,
        title: '学校作业',
        badge: pending.isNotEmpty ? '${pending.length} 项待处理' : null,
        actionLabel: '全部',
        onAction: onOpen,
      ),
      footer: Text(
        '学校作业 · ${data?.termName.trim().isNotEmpty == true ? data!.termName : '学期未确认'}'
        '\n${unknownRole ? '课程身份未能全部核对，可能包含助教课程' : '已识别助教课程不在此显示'}'
        '\n学校状态与个人待办独立；截止时间按北京时间显示'
        '\n作业同步：${data?.fetchedAt == null ? '未确认' : schoolTimestampLabel(data!.fetchedAt)}',
      ),
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
                  title: data.rolesComplete == false
                      ? '作业结果不完整'
                      : pending.isNotEmpty
                      ? '${pending.length} 项作业待处理'
                      : section.error != null || unknown.isNotEmpty
                      ? '作业状态尚未确认'
                      : overdue.isNotEmpty
                      ? '没有待处理作业（已截止 ${overdue.length} 项）'
                      : '当前没有待处理作业',
                  subtitle: data.rolesComplete == false
                      ? '课程身份未能全部核对，请进入作业复核'
                      : unknown.isNotEmpty
                      ? (overdue.isNotEmpty
                            ? '${unknown.length} 项状态待确认 · 已截止 ${overdue.length} 项'
                            : '${unknown.length} 项状态待确认，请进入作业核对')
                      : overdue.isNotEmpty
                      ? '已截止 ${overdue.length} 项 · 查看'
                      : null,
                  onTap: onOpen,
                ),
                for (final item in todayVisibleHomework(
                  data,
                  CourseVisibilityScope.of(context),
                  clock,
                )) ...[
                  const TodayVisualDivider(),
                  TodayActionRow(
                    key: Key('today-homework-item-${item.id}'),
                    title: item.title,
                    subtitle: item.courseName,
                    status: _statusLabel(item, clock),
                    statusColor: homeworkDeadlineTint(
                      item.dueAt,
                      clock,
                    ).resolveFrom(context),
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

  String _statusLabel(HomeworkItem item, DateTime clock) {
    return homeworkCompactDeadline(item.dueAt, clock);
  }
}
