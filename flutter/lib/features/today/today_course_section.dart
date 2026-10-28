import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

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

/// The loaded "today's courses" section: heading, focus card, the expandable
/// course list and the way into the full timetable.
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

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(data.date);
    final dateLabel = date == null ? data.date : schoolDateWeekdayLabel(date);
    final courses = data.courses;
    final isToday =
        todayDate(data.date) == DateTime.utc(now.year, now.month, now.day);
    return TodayVisualSection(
      key: const Key('today-courses'),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TodaySectionHeader(
            icon: CupertinoIcons.calendar_today,
            title: '今日课程',
            badge: isToday && courses.isNotEmpty
                ? '今天 ${courses.length} 节课'
                : null,
            actionLabel: onOpenSchedule == null ? null : '完整课表',
            onAction: onOpenSchedule,
          ),
          const SizedBox(height: 2),
          Text(
            dateLabel,
            style: TextStyle(
              fontSize: 12,
              color: AppleDesign.statusInactive.resolveFrom(context),
            ),
          ),
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.fetchedAt != null)
            Text('课表同步：${_syncedAtLabel(data.fetchedAt!)}'),
          Text(demo ? '离线演示 · 课程与日期为合成样例' : '课程来自教务课表，签到状态请进入课程签到核对。'),
        ],
      ),
      children: [
        if (loading || error != null)
          SectionFeedback(
            loading: loading,
            label: '正在更新今天课程…',
            hasData: true,
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
          ),
          Semantics(
            expanded: expanded,
            child: CupertinoButton(
              key: const Key('today-toggle-courses'),
              minimumSize: const Size(48, 48),
              onPressed: onToggleExpanded,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      expanded ? '收起今日课程' : '展开今日课程（${courses.length}）',
                    ),
                  ),
                  Icon(
                    expanded
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            for (final (index, course) in courses.indexed)
              TodayCourseRow(
                key: Key('today-course-$index-${course.name}'),
                course: course,
                status:
                    TodayCourseWindow.parse(
                      data.date,
                      course.time,
                    )?.status(now) ??
                    '时间待确认',
              ),
          if (onOpenSchedule != null)
            AppleListTile(
              title: Text(
                '查看完整课表',
                style: TextStyle(
                  color: CupertinoTheme.of(context).primaryColor,
                ),
              ),
              additionalInfo: Text(
                '共 ${courses.length} 门课',
                style: TextStyle(
                  color: AppleDesign.statusInactive.resolveFrom(context),
                ),
              ),
              trailing: const CupertinoListTileChevron(),
              onTap: onOpenSchedule,
            ),
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
