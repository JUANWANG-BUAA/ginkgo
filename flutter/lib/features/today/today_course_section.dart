import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/checkin_visibility.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'today_action_row.dart';
import 'today_course_focus.dart';
import 'today_course_list.dart';
import 'today_presentation.dart';

/// Shown until the first course payload lands. The section keeps the same
/// heading so the page never changes shape between loading and loaded.
class TodayCoursePlaceholder extends StatelessWidget {
  const TodayCoursePlaceholder({
    super.key,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => TodayVisualSection(
    header: const Text('今日课程'),
    children: [
      SectionFeedback(
        loading: loading,
        label: '正在读取今天课程…',
        hasData: false,
        error: error,
        onRetry: onRetry,
      ),
    ],
  );
}

/// The loaded "today's courses" section: timeline focus card, fused inline
/// check-in actions, expandable course list and entry to the full timetable.
class TodayCourseSection extends StatelessWidget {
  const TodayCourseSection({
    super.key,
    required this.data,
    required this.now,
    required this.loading,
    required this.error,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onRetry,
    this.onOpenSchedule,
    this.demo = false,
    this.checkinSection,
    this.checkinCourses = const [],
    this.onCheckInRetry,
    this.onOpenCheckIn,
  });

  final TodayResponse data;
  final DateTime now;
  final bool loading;
  final String? error;

  /// Whether the full course list is unfolded below the focus card.
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onRetry;
  final VoidCallback? onOpenSchedule;
  final bool demo;
  final RefreshSection<CheckInResponse>? checkinSection;
  final List<CheckInCourse> checkinCourses;
  final VoidCallback? onCheckInRetry;
  final VoidCallback? onOpenCheckIn;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(data.date);
    final dateLabel = date == null ? data.date : schoolDateWeekdayLabel(date);
    final courses = data.courses;
    final isToday =
        todayDate(data.date) == DateTime.utc(now.year, now.month, now.day);
    if (courses.isEmpty && isToday && error == null) {
      return const SizedBox.shrink();
    }
    final showFooter = (error != null || !isToday) && data.fetchedAt != null;
    final checkin = checkinSection;
    final checkinData = checkin?.value;
    final checkinError = checkin == null
        ? null
        : switch (checkin.failure) {
            FailureCode.moduleAuthRequired => '签到服务认证未完成',
            _ when checkinData == null && checkin.error != null =>
              '签到状态暂时无法读取',
            _ => checkin.error,
          };
    final showInlineCheckInStrip =
        courses.isNotEmpty &&
        checkin != null &&
        (checkinData == null || checkinError != null);

    return TodayVisualSection(
      key: const Key('today-courses'),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TodaySectionHeader(
            icon: CupertinoIcons.calendar_today,
            title: '今日课程',
            badge: courses.isEmpty
                ? null
                : isToday
                ? '今天 ${courses.length} 节课'
                : '${courses.length} 节课',
            actionLabel: onOpenSchedule == null ? null : '完整课表',
            onAction: onOpenSchedule,
          ),
          if (!isToday) ...[
            const SizedBox(height: GinkgoSpacing.xs),
            Text(
              dateLabel,
              style: GinkgoTypography.caption.copyWith(
                color: AppleDesign.statusInactive.resolveFrom(context),
              ),
            ),
          ],
        ],
      ),
      footer: showFooter
          ? Text('课表同步：${_syncedAtLabel(data.fetchedAt!)}')
          : null,
      children: [
        if (loading || error != null)
          SectionFeedback(
            loading: loading,
            label: '正在更新今天课程…',
            hasData: true,
            quietWhenRefreshing: true,
            error: error,
            onRetry: onRetry,
          ),
        if (courses.isEmpty && isToday)
          TodayCourseEmpty(error: error, onOpenSchedule: onOpenSchedule),
        if (courses.isEmpty && !isToday)
          TodayCourseFocus(data: data, now: now, onOpen: onOpenSchedule),
        if (courses.isNotEmpty) ...[
          TodayCourseFocus(
            data: data,
            now: now,
            stale: error != null,
            onOpen: onOpenSchedule,
            checkinCourses: checkinCourses,
            onOpenCheckIn: onOpenCheckIn,
          ),
          Semantics(
            expanded: expanded,
            child: CupertinoButton(
              key: const Key('today-toggle-courses'),
              minimumSize: GinkgoButtonTokens.minTarget,
              onPressed: onToggleExpanded,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      expanded ? '收起今日课程' : '展开今日课程',
                      style: GinkgoTypography.subheadline.copyWith(
                        color: CupertinoTheme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: GinkgoIconTokens.glyphSm,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            for (final (index, course) in courses.indexed) ...[
              const TodayVisualDivider(),
              TodayCourseRow(
                key: Key('today-course-$index-${course.name}'),
                course: course,
                status:
                    TodayCourseWindow.parse(
                      data.date,
                      course.time,
                    )?.status(now) ??
                    '时间待确认',
                checkin: matchCheckInForTodayCourse(course, checkinCourses),
                onOpenCheckIn: onOpenCheckIn,
              ),
            ],
          if (showInlineCheckInStrip) ...[
            const TodayVisualDivider(),
            KeyedSubtree(
              key: const Key('today-checkin'),
              child: checkinData == null &&
                      !checkin.loading &&
                      checkinError == null
                  ? TodayActionRow(
                      summary: true,
                      title: '查看课程签到',
                      onTap: onCheckInRetry,
                    )
                  : SectionFeedback(
                      loading: checkin.loading,
                      label: checkinData == null
                          ? '正在读取签到状态…'
                          : '正在更新签到状态…',
                      hasData: checkinData != null,
                      quietWhenRefreshing: true,
                      error: checkinError,
                      onRetry: onCheckInRetry ?? () {},
                    ),
            ),
          ],
        ],
      ],
    );
  }
}

/// The moment the school snapshot was taken, shown in Beijing wall time.
String _syncedAtLabel(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  final beijing = todaySchoolNow(date);
  final hour = beijing.hour.toString().padLeft(2, '0');
  final minute = beijing.minute.toString().padLeft(2, '0');
  return '${beijing.month}月${beijing.day}日 $hour:$minute';
}
