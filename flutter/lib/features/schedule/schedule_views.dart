import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';

import 'schedule_day_strip.dart';
import 'schedule_grid.dart';
import 'schedule_style.dart';
import 'schedule_widgets.dart';

/// Main schedule viewport: full 7-day iOS week timetable card by default,
/// Apple Calendar circle agenda in day-list mode, or full-week search results.
class ScheduleCourseBrowser extends StatelessWidget {
  const ScheduleCourseBrowser({
    super.key,
    required this.snapshot,
    required this.courses,
    required this.days,
    required this.weeks,
    required this.mode,
    required this.search,
    required this.searchVisible,
    required this.selectedDay,
    required this.onSelectedDay,
    required this.onSearchChanged,
    required this.onCourseTap,
  });
  final ScheduleResponse snapshot;
  final List<ScheduleCourse> courses;
  final Map<int, List<ScheduleCourse>> days;
  final Map<int, ScheduleWeek> weeks;
  final ScheduleViewMode mode;
  final String search;
  final bool searchVisible;
  final int selectedDay;
  final ValueChanged<int> onSelectedDay;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ScheduleCourse> onCourseTap;

  @override
  Widget build(BuildContext context) {
    final weekStart = weeks[snapshot.weekNumber]?.startDate;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final searching = search.trim().isNotEmpty;
    final grid = !searching && !largeText && mode == ScheduleViewMode.weekGrid;
    final visibleDays = !searching && mode == ScheduleViewMode.dayList
        ? <int, List<ScheduleCourse>>{
            selectedDay: days[selectedDay] ?? const [],
          }
        : days;
    final visibleCourses = visibleDays.values
        .expand((items) => items)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (searchVisible || searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              GinkgoSpacing.md,
              GinkgoSpacing.xs,
              GinkgoSpacing.md,
              GinkgoSpacing.xs,
            ),
            child: CupertinoSearchTextField(
              key: const Key('schedule-search'),
              placeholder: '搜索本周课程、教师或地点',
              onChanged: onSearchChanged,
            ),
          ),
        if (!searching && mode == ScheduleViewMode.dayList) ...[
          const SizedBox(height: GinkgoSpacing.xs),
          ScheduleDayStrip(
            weekStart: weekStart,
            selectedDay: selectedDay,
            dayCourses: days,
            onSelected: onSelectedDay,
          ),
        ],
        if (searching && visibleCourses.isEmpty)
          const AppleStatusSection(
            title: '没有匹配的课程',
            description: '请尝试其他关键词。',
          )
        else if (courses.isEmpty && snapshot.weeks.isEmpty)
          const AppleStatusSection(
            title: '该学期暂无课表',
            description: '可以切换其他日期、学期或周次查看。',
          )
        else if (grid && courses.isEmpty)
          const AppleStatusSection(
            title: '本周没有课程',
            description: '可以切换其他日期、学期或周次查看。',
          )
        else if (!grid && visibleCourses.isEmpty)
          AppleStatusSection(
            title: mode == ScheduleViewMode.dayList ? '当日没有课程' : '本周没有课程',
            description: '上方圆点标记了本周有课的星期，可点击切换查看。',
          )
        else
          AppleContentTransition(
            identity: (
              snapshot.termId,
              snapshot.weekNumber,
              mode,
              selectedDay,
              largeText,
              searching,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (grid)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      GinkgoSpacing.md,
                      GinkgoSpacing.xs,
                      GinkgoSpacing.md,
                      0,
                    ),
                    child: ScheduleGrid(
                      courses: courses,
                      weekStart: weekStart,
                      onCourseTap: onCourseTap,
                    ),
                  )
                else
                  for (final day in visibleDays.entries)
                    ScheduleSection(
                      title: scheduleDayTitle(day.key, weekStart),
                      children: [
                        for (final course in day.value)
                          ScheduleCourseRow(
                            course: course,
                            onTap: () => onCourseTap(course),
                          ),
                      ],
                    ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The teaching weeks of the term, presented as an iOS grouped list.
class ScheduleSemesterWeeks extends StatelessWidget {
  const ScheduleSemesterWeeks({
    super.key,
    required this.weeks,
    required this.onSelected,
  });
  final List<ScheduleWeek> weeks;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final primary = CupertinoTheme.of(context).primaryColor;
    return ScheduleSection(
      title: '学期周次',
      children: [
        if (weeks.isEmpty)
          const AppleEmptyState(
            title: '暂无学期周次',
            description: '学校尚未发布该学期的排课与周次数据。',
          ),
        for (final week in weeks)
          ScheduleChevronRow(
            key: Key('schedule-semester-week-${week.number}'),
            onTap: () => onSelected(week.number),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '第 ${week.number} 周',
                        style: GinkgoTypography.body.copyWith(
                          fontWeight: week.current
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontFeatures: GinkgoTypography.tabularDigits,
                          color: week.current
                              ? primary
                              : CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: GinkgoSpacing.xs),
                      Text(
                        '${shortDate(week.startDate)} – ${shortDate(week.endDate)}',
                        style: GinkgoTypography.footnote.copyWith(
                          fontFeatures: GinkgoTypography.tabularDigits,
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (week.current)
                  GinkgoBadge(
                    label: '本周',
                    icon: CupertinoIcons.calendar_today,
                    color: primary,
                    compact: true,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The exam schedule of the term, styled after iOS Academic cards.
class ScheduleExamList extends StatelessWidget {
  const ScheduleExamList({super.key, required this.exams});
  final List<ScheduleExam> exams;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return ScheduleSection(
      title: '考试安排',
      children: [
        if (exams.isEmpty)
          const AppleEmptyState(title: '本学期暂无考试安排', description: '请留意学校后续通知。'),
        for (final exam in exams)
          Padding(
            padding: GinkgoSpacing.edgeInsetsCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        exam.courseName,
                        style: GinkgoTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                    ),
                    if (exam.examSeatNo != null) ...[
                      const SizedBox(width: GinkgoSpacing.sm),
                      GinkgoBadge(
                        label: '座位 ${exam.examSeatNo}',
                        icon: CupertinoIcons.number,
                        color: AppleDesign.resourceBlue,
                        compact: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: GinkgoSpacing.small),
                Row(
                  children: [
                    Icon(CupertinoIcons.clock, size: 13, color: secondary),
                    const SizedBox(width: GinkgoSpacing.xs),
                    Expanded(
                      child: Text(
                        _examTimeLabel(exam),
                        style: GinkgoTypography.footnote.copyWith(
                          fontFeatures: GinkgoTypography.tabularDigits,
                          color: secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (exam.examPlace?.isNotEmpty == true) ...[
                  const SizedBox(height: GinkgoSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.placemark,
                        size: 13,
                        color: secondary,
                      ),
                      const SizedBox(width: GinkgoSpacing.xs),
                      Expanded(
                        child: Text(
                          [
                            exam.examPlace!,
                            if (exam.examStatus?.isNotEmpty == true)
                              exam.examStatus!,
                          ].join(' · '),
                          style: GinkgoTypography.footnote.copyWith(
                            color: secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

String _examTimeLabel(ScheduleExam exam) {
  final parts = [
    if (exam.examDate != null) exam.examDate!,
    if (exam.startTime != null && exam.endTime != null)
      '${exam.startTime}–${exam.endTime}',
  ];
  return parts.isEmpty
      ? (exam.examTimeDescription ?? '时间待定')
      : parts.join(' · ');
}
