import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'mirror_service.dart';
import 'schedule_grid.dart';
import 'schedule_style.dart';
import 'src/rust/api/mirror.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, required this.service});
  final MirrorService service;
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  ScheduleResponse? data;
  String? error;
  String? notice;
  bool busy = false;
  int selectedWeek = 0;
  int viewMode = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool force = false}) async {
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final result = await widget.service.schedule(forceRefresh: force);
      if (!mounted) return;
      setState(() {
        busy = false;
        if (result.failure != null &&
            result.courses.isEmpty &&
            result.exams.isEmpty) {
          error = failureMessage(result.failure);
          return;
        }
        data = result;
        selectedWeek = result.weekNumber;
        notice = result.failure == null
            ? null
            : '${failureMessage(result.failure)}，正在显示上次结果。';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = failureMessage(null);
      });
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('schedule-scroll'),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('课表'),
          border: null,
          trailing: AppleGlassButton(
            label: '刷新课表',
            onPressed: busy ? null : () => load(force: true),
            child: busy
                ? const CupertinoActivityIndicator()
                : const Icon(CupertinoIcons.refresh, size: 24),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
        SliverList.list(
          children: [
            if (notice != null)
              AppleSection(
                children: [
                  AppleListTile(
                    leading: const Icon(
                      CupertinoIcons.exclamationmark_triangle,
                      color: CupertinoColors.systemOrange,
                      size: 20,
                    ),
                    title: Text(notice!),
                  ),
                ],
              ),
            if (error != null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: error!,
                    description: '请检查网络后重试。',
                    error: true,
                    action: '重试',
                    onAction: () => load(force: true),
                  ),
                ],
              )
            else if (busy || data == null)
              AppleSection(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: const [
                        CupertinoActivityIndicator(),
                        SizedBox(width: 10),
                        Text('正在读取课表…'),
                      ],
                    ),
                  ),
                ],
              )
            else
              ..._content(data!),
          ],
        ),
      ],
    ),
  );

  List<Widget> _content(ScheduleResponse data) {
    final selectedTerm = data.terms.where((term) => term.id == data.termId);
    final termName = selectedTerm.isEmpty ? '' : selectedTerm.first.name;
    final week = data.weeks.where((week) => week.number == selectedWeek);
    final weekLabel = week.isEmpty
        ? '第 $selectedWeek 周'
        : '第 ${week.first.number} 周 · ${shortDate(week.first.startDate)}–${shortDate(week.first.endDate)}';
    final courses = data.weekNumber == selectedWeek
        ? data.courses
        : const <ScheduleCourse>[];
    return [
      AppleSection(
        header: Text(termName.isEmpty ? '当前学期' : termName),
        footer: const Text('课表按学校当前学期与教学周读取；切换未缓存的周次需要联网刷新。'),
        children: [
          AppleListTile(title: Text(weekLabel)),
          _weekStrip(data),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: viewMode,
              onValueChanged: (value) => setState(() => viewMode = value ?? 0),
              children: const {
                0: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('周视图'),
                ),
                1: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('列表'),
                ),
              },
            ),
          ),
        ],
      ),
      if (data.weekNumber != selectedWeek)
        AppleSection(
          children: [
            AppleEmptyState(
              title: '该周课表尚未缓存',
              description: '已保留当前周课表。切换到本机已知周次不会清空结果。',
              action: '回到第 ${data.weekNumber} 周',
              onAction: () => setState(() => selectedWeek = data.weekNumber),
            ),
          ],
        )
      else if (courses.isEmpty)
        AppleSection(
          children: const [
            AppleEmptyState(title: '本周暂无课程', description: '当前学期课表为空，或该周尚未发布。'),
          ],
        )
      else if (viewMode == 0)
        AppleSection(
          header: const Text('本周'),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: ScheduleGrid(
                courses: courses,
                onCourseTap: (course) => _showCourse(context, course),
              ),
            ),
          ],
        )
      else
        for (var day = 1; day <= 7; day++)
          if (courses.where((course) => course.day == day).toList()
              case final dayCourses when dayCourses.isNotEmpty)
            AppleSection(
              header: Text(weekdayNames[day - 1]),
              children: [
                for (final course in dayCourses)
                  AppleListTile(
                    key: Key('schedule-course-${course.id}'),
                    minimumHeight: 62,
                    leading: Container(
                      width: 4,
                      height: 38,
                      decoration: BoxDecoration(
                        color: courseColor(context, course.color),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    title: Text(course.name),
                    subtitle: Text(
                      courseDetail(course),
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                    additionalInfo: course.place == null
                        ? null
                        : Text(
                            course.place!,
                            style: const TextStyle(fontSize: 14),
                          ),
                  ),
              ],
            ),
      if (data.exams.isNotEmpty)
        AppleSection(
          header: const Text('考试安排'),
          children: [
            for (final exam in data.exams)
              AppleListTile(
                title: Text(exam.courseName),
                subtitle: Text(_examDetail(exam)),
                additionalInfo: exam.examSeatNo == null
                    ? null
                    : Text('座位 ${exam.examSeatNo}'),
              ),
          ],
        ),
      AppleSection(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.service.isDemo
                  ? '离线合成样例，不连接学校账号；周次与课程用于演示迁移后的页面与状态。'
                  : '真实账号只读数据；刷新失败时保留上次课表。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _weekStrip(ScheduleResponse data) => SizedBox(
    height: 56,
    child: ListView.separated(
      key: const Key('schedule-weeks'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      itemCount: data.weeks.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final week = data.weeks[index];
        final selected = week.number == selectedWeek;
        return CupertinoButton(
          key: Key('schedule-week-${week.number}'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: selected
              ? CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.14)
              : CupertinoColors.tertiarySystemFill.resolveFrom(context),
          onPressed: () => setState(() => selectedWeek = week.number),
          child: Text(
            '第 ${week.number} 周',
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? CupertinoTheme.of(context).primaryColor
                  : CupertinoColors.label.resolveFrom(context),
            ),
          ),
        );
      },
    ),
  );

  void _showCourse(BuildContext context, ScheduleCourse course) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(course.name),
        message: Text(
          '${weekdayNames[course.day - 1]} · ${courseDetail(course)}'
          '${course.place == null ? '' : '\n${course.place}'}',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
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
