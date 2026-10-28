import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'schedule_day_strip.dart';
import 'schedule_grid.dart';
import 'schedule_style.dart';
import 'schedule_widgets.dart';

/// The courses of the confirmed week: a search field plus either the weekly
/// grid or one section per weekday.
class ScheduleCourseBrowser extends StatelessWidget {
  const ScheduleCourseBrowser({
    super.key,
    required this.snapshot,
    required this.courses,
    required this.days,
    required this.weeks,
    required this.mode,
    required this.search,
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
  final int selectedDay;
  final ValueChanged<int> onSelectedDay;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ScheduleCourse> onCourseTap;

  @override
  Widget build(BuildContext context) {
    final weekStart = weeks[snapshot.weekNumber]?.startDate;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final grid = !largeText && mode == ScheduleViewMode.weekGrid;
    final searching = search.trim().isNotEmpty;
    final visibleDays = !searching && mode == ScheduleViewMode.dayList
        ? <int, List<ScheduleCourse>>{
            selectedDay: days[selectedDay] ?? const [],
          }
        : days;
    final visibleCourses = visibleDays.values
        .expand((courses) => courses)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mode == ScheduleViewMode.dayList)
          ScheduleDayStrip(
            weekStart: weekStart,
            selectedDay: selectedDay,
            onSelected: onSelectedDay,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: CupertinoSearchTextField(
            key: const Key('schedule-search'),
            placeholder: '搜索本周课程、教师或地点',
            onChanged: onSearchChanged,
          ),
        ),
        if (visibleCourses.isEmpty)
          AppleStatusSection(
            title: searching
                ? '没有匹配的课程'
                : snapshot.weeks.isEmpty
                ? '该学期暂无课表'
                : mode == ScheduleViewMode.dayList
                ? '当日没有课程'
                : '本周没有课程',
            description: searching ? '请尝试其他关键词。' : '可以切换其他日期、学期或周次查看。',
          )
        else
          AppleContentTransition(
            identity: (
              snapshot.termId,
              snapshot.weekNumber,
              mode,
              selectedDay,
              largeText,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    '${visibleCourses.length} 项课程${largeText && mode == ScheduleViewMode.weekGrid ? ' · 大字号使用每日清单' : ''}',
                    style: scheduleSecondary(context),
                  ),
                ),
                if (grid)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
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

/// The teaching weeks of the term.
class ScheduleSemesterWeeks extends StatelessWidget {
  const ScheduleSemesterWeeks({
    super.key,
    required this.weeks,
    required this.onSelected,
  });
  final List<ScheduleWeek> weeks;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => ScheduleSection(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '第 ${week.number} 周${week.current ? ' · 本周' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 5),
              Text(
                '${shortDate(week.startDate)}–${shortDate(week.endDate)}',
                style: scheduleSecondary(context),
              ),
            ],
          ),
        ),
    ],
  );
}

/// The exam schedule of the term.
class ScheduleExamList extends StatelessWidget {
  const ScheduleExamList({super.key, required this.exams});
  final List<ScheduleExam> exams;

  @override
  Widget build(BuildContext context) => ScheduleSection(
    title: '考试安排',
    children: [
      if (exams.isEmpty)
        const AppleEmptyState(title: '本学期暂无考试安排', description: '请留意学校后续通知。'),
      for (final exam in exams)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.courseName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(_examDetail(exam), style: scheduleSecondary(context)),
                if (exam.examSeatNo != null)
                  Text(
                    '座位 ${exam.examSeatNo}',
                    style: scheduleSecondary(context),
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}

String _examDetail(ScheduleExam exam) {
  final parts = [
    if (exam.examDate != null) exam.examDate!,
    if (exam.startTime != null && exam.endTime != null)
      '${exam.startTime}–${exam.endTime}',
    if (exam.examPlace != null) exam.examPlace!,
    if (exam.examStatus != null) exam.examStatus!,
  ];
  return parts.isEmpty
      ? (exam.examTimeDescription ?? '时间待定')
      : parts.join(' · ');
}
