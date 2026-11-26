import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/features/homework/homework_projection.dart';
import 'package:ginkgo_mirror/shared/course_visibility.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'today_action_row.dart';
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
///
/// Surfaces only active upcoming student assignments in a layered progressive
/// card; already-overdue archive items stay on the Homework tab instead of
/// cluttering Today.
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
    final unknown = personal.where(
      (item) => item.status == HomeworkStatus.unknown,
    );
    if (data != null &&
        data.rolesComplete == true &&
        section.error == null &&
        pending.isEmpty &&
        unknown.isEmpty) {
      return const SizedBox.shrink();
    }
    final visible = todayVisibleHomework(
      data,
      CourseVisibilityScope.of(context),
      clock,
    );
    return TodayVisualSection(
      key: const Key('today-homework'),
      header: TodaySectionHeader(
        icon: CupertinoIcons.doc_text_fill,
        iconColor: GinkgoColors.resourcePurple,
        title: '待提交作业',
        badge: pending.isNotEmpty ? '${pending.length} 项' : null,
        actionLabel: '全部',
        onAction: onOpen,
      ),
      footer: section.error != null
          ? Text(
              '作业同步：${data?.fetchedAt == null ? '未确认' : schoolTimestampLabel(data!.fetchedAt)}',
            )
          : null,
      children: [
        if (section.loading || section.error != null)
          SectionFeedback(
            loading: section.loading,
            label: data == null ? '正在检查学校作业…' : '正在更新学校作业…',
            hasData: data != null,
            quietWhenRefreshing: true,
            error: section.error,
            onRetry: onRetry,
          ),
        if (data != null)
          SectionReveal(
            child: Column(
              children: [
                if (pending.isEmpty)
                  TodayActionRow(
                    summary: true,
                    title: data.rolesComplete == false
                        ? '作业结果不完整'
                        : section.error != null || unknown.isNotEmpty
                        ? '作业状态尚未确认'
                        : data.rolesComplete != true
                        ? '作业范围待确认'
                        : '没有待处理作业',
                    subtitle: data.rolesComplete == false
                        ? '课程身份未能全部核对，请进入作业复核'
                        : section.error != null
                        ? '学校作业未能更新，请重试核对。'
                        : unknown.isNotEmpty
                        ? '${unknown.length} 项状态待确认，请进入作业核对'
                        : data.rolesComplete != true
                        ? '尚未确认课程身份范围，请进入作业复核'
                        : '打开作业查看完整结果',
                    onTap: onOpen,
                  ),
                if (pending.isNotEmpty &&
                    (data.rolesComplete == false || unknown.isNotEmpty))
                  TodayActionRow(
                    summary: true,
                    title: data.rolesComplete == false
                        ? '作业结果不完整'
                        : '作业状态尚未确认',
                    subtitle: [
                      if (unknown.isNotEmpty) '${unknown.length} 项状态待确认',
                      if (data.rolesComplete == false) '课程身份范围未全部核对',
                      '进入作业复核',
                    ].join(' · '),
                    onTap: onOpen,
                  ),
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0 ||
                      (pending.isNotEmpty &&
                          (data.rolesComplete == false || unknown.isNotEmpty)))
                    const TodayVisualDivider(),
                  GinkgoProgressiveRow(
                    key: Key('today-homework-item-${visible[i].id}'),
                    emphasized: i == 0,
                    title: visible[i].title,
                    subtitle: visible[i].courseName,
                    badgeLabel: homeworkCountdownBadge(visible[i].dueAt, clock),
                    badgeIcon: CupertinoIcons.clock_fill,
                    meta: visible[i].dueAt?.trim().isNotEmpty == true
                        ? homeworkDueSummary(visible[i].dueAt, clock)
                        : null,
                    accent: homeworkDeadlineTint(visible[i].dueAt, clock),
                    onTap: onOpenItem == null
                        ? onOpen
                        : () => onOpenItem!(visible[i]),
                  ),
                ],
                if (pending.length > 3) ...[
                  const TodayVisualDivider(),
                  TodayActionRow(
                    summary: true,
                    title: '还有 ${pending.length - 3} 项待提交',
                    onTap: onOpen,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
