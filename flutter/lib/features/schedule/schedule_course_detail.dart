import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';

import 'schedule_style.dart';
import 'schedule_widgets.dart';

/// The pushed course detail page.
///
/// It shows the confirmed snapshot the course was picked from, so the dates
/// never describe a different week than the visible list.
class ScheduleCourseDetailPage extends StatelessWidget {
  const ScheduleCourseDetailPage({
    super.key,
    required this.course,
    required this.termName,
    required this.weekNumber,
    required this.week,
    required this.dayTitle,
  });
  final ScheduleCourse course;
  final String termName;
  final int weekNumber;
  final ScheduleWeek? week;
  final String dayTitle;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    navigationBar: const CupertinoNavigationBar(
      middle: Text('课程详情'),
      previousPageTitle: '课表',
    ),
    child: SafeArea(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            child: Text(
              course.name,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
          ),
          ScheduleSection(
            children: [
              ScheduleDetailLine(label: '星期', value: weekdayNames[course.day - 1]),
              ScheduleDetailLine(
                label: '节次',
                value: '第 ${course.startSection}–${course.endSection} 节',
              ),
              ScheduleDetailLine(label: '开始时间', value: course.startTime ?? '待定'),
              ScheduleDetailLine(label: '结束时间', value: course.endTime ?? '待定'),
              ScheduleDetailLine(label: '地点', value: course.place ?? '待定'),
              ScheduleDetailLine(label: '教师', value: course.teacher ?? '待定'),
            ],
          ),
          ScheduleSection(
            children: [
              ScheduleDetailLine(label: '学期', value: termName),
              ScheduleDetailLine(label: '周次', value: '第 $weekNumber 周'),
              if (week != null)
                ScheduleDetailLine(
                  label: '日期范围',
                  value:
                      '${shortDate(week!.startDate)}–${shortDate(week!.endDate)}',
                ),
              ScheduleDetailLine(label: '上课日期', value: dayTitle),
            ],
          ),
          const SizedBox(height: 96),
        ],
      ),
    ),
  );
}
