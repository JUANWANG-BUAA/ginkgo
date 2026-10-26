import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/widgets/long_page_scroll.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_grid.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_week_strip.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_style.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_widgets.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/application/contracts.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, required this.service});
  final AcademicGateway service;
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  ScheduleResponse? data;
  String? error;
  String? notice;
  bool busy = false;
  int selectedWeek = 0;
  String? selectedTerm;
  int viewMode = 0;
  int requestId = 0;
  String search = '';
  List<ScheduleCourse> sorted = [];
  List<ScheduleCourse> filtered = [];
  Map<int, List<ScheduleCourse>> days = {};
  Map<int, ScheduleWeek> weeks = {};
  Map<String, ScheduleTerm> terms = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  void filter() {
    final query = search.trim().toLowerCase();
    filtered = sorted
        .where(
          (course) =>
              query.isEmpty ||
              [
                course.name,
                course.teacher ?? '',
                course.place ?? '',
              ].any((value) => value.toLowerCase().contains(query)),
        )
        .toList();
    days = {};
    for (final course in filtered) {
      days.putIfAbsent(course.day, () => []).add(course);
    }
  }

  Future<void> load({bool force = false, String? termId, int? week}) async {
    final id = ++requestId;
    final requestedTerm = termId ?? selectedTerm;
    final requestedWeek = termId != null
        ? week
        : (week ?? (selectedWeek == 0 ? null : selectedWeek));
    // The header and course list must always describe one confirmed snapshot.
    // selectedTerm/selectedWeek are only advanced by a successful response, so
    // a slow or failed load never labels old courses with the new selection.
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final result = await widget.service.schedule(
        termId: requestedTerm,
        week: requestedWeek,
        forceRefresh: force,
      );
      if (!mounted || id != requestId) return;
      setState(() {
        busy = false;
        // A cached empty week is still valid. A failure without metadata is
        // an unsuccessful request and must never replace the visible snapshot.
        if (result.failure != null && result.termId.isEmpty) {
          failed(failureMessage(result.failure));
          return;
        }
        // The demo intentionally exposes one known week through real FFI.
        if (requestedWeek != null &&
            result.weekNumber != requestedWeek &&
            result.termId == (data?.termId ?? result.termId)) {
          failed('第 $requestedWeek 周尚未缓存');
          return;
        }
        data = result;
        selectedTerm = result.termId;
        selectedWeek = result.weekNumber;
        terms = {for (final term in result.terms) term.id: term};
        weeks = {for (final item in result.weeks) item.number: item};
        sorted = [...result.courses]
          ..sort((a, b) {
            final day = a.day.compareTo(b.day);
            if (day != 0) return day;
            final section = a.startSection.compareTo(b.startSection);
            return section == 0 ? a.name.compareTo(b.name) : section;
          });
        filter();
        if (result.exams.isEmpty && viewMode == 2) viewMode = 0;
        notice = result.failure == null
            ? null
            : '${failureMessage(result.failure)}，正在显示上次结果。';
      });
    } catch (_) {
      if (!mounted || id != requestId) return;
      setState(() {
        busy = false;
        failed(failureMessage(null));
      });
    }
  }

  void failed(String message) {
    if (data == null) {
      error = message;
    } else {
      notice =
          '$message，正在显示${terms[data!.termId]?.name ?? '上次学期'}第 ${data!.weekNumber} 周课表。';
    }
  }

  void selectWeek(int week) {
    if (viewMode == 1 || viewMode == 2) setState(() => viewMode = 0);
    load(week: week);
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: LongPageScroll(
      controller: scrollController,
      child: CustomScrollView(
        controller: scrollController,
        key: const Key('schedule-scroll'),
        slivers: [
          ApplePageHeader(
            largeTitle: const Text('课表'),
            section: '学业',
            subtitle: '按学期与教学周查看课程和考试',
            icon: CupertinoIcons.calendar,
            border: null,
            trailing: AppleGlassButton(
              label: '刷新课表',
              onPressed: busy ? null : () => load(force: true),
              child: busy
                  ? const GinkgoActivity(size: 17)
                  : const Icon(CupertinoIcons.refresh, size: 24),
            ),
          ),
          CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
          SliverList.list(
            children: [
              if (data != null) ..._content(data!),
              if (notice != null)
                AppleSection(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notice!,
                            style: TextStyle(
                              color: CupertinoColors.systemOrange.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: busy ? null : () => load(force: true),
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              if (data == null && error != null)
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
              else if (data == null)
                const AppleSection(
                  children: [GinkgoLoadingView(label: '正在读取课表…')],
                ),
              const SizedBox(height: 96),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _scheduleControls(ScheduleResponse snapshot) {
    final termPicker = Builder(
      builder: (anchor) => _row(
        key: const Key('schedule-term-picker'),
        onTap: () async {
          final id = await choose<String>(
            anchor,
            '学期',
            terms.keys.toList(),
            (id) => terms[id]?.name ?? id,
            selected: selectedTerm,
          );
          if (mounted && id != null && id != selectedTerm) {
            await load(termId: id);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              terms[selectedTerm]?.name ?? snapshot.termId,
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
    if (snapshot.weeks.isEmpty) return termPicker;
    final weekPicker = Builder(
      builder: (anchor) => CupertinoButton(
        key: const Key('schedule-week-picker'),
        padding: const EdgeInsets.symmetric(vertical: 4),
        minimumSize: const Size(48, 64),
        alignment: Alignment.centerLeft,
        onPressed: () async {
          final value = await choose<int>(
            anchor,
            '选择周次',
            snapshot.weeks.map((week) => week.number).toList(),
            (week) => '第 $week 周',
            selected: selectedWeek,
          );
          if (mounted && value != null && value != selectedWeek) {
            selectWeek(value);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    '第 $selectedWeek 周',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(CupertinoIcons.chevron_down, size: 14),
              ],
            ),
            if (weeks[selectedWeek] case final ScheduleWeek range)
              Text(
                '${shortDate(range.startDate)} – ${shortDate(range.endDate)}',
                style: secondary(context),
              ),
          ],
        ),
      ),
    );
    final currentWeek = snapshot.weeks.any((item) => item.current)
        ? CupertinoButton(
            key: const Key('schedule-current-week'),
            minimumSize: const Size(48, 48),
            onPressed: () => selectWeek(
              snapshot.weeks.firstWhere((item) => item.current).number,
            ),
            child: const Text('本周'),
          )
        : const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth >= 360 &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.3;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (compact)
              Row(
                children: [
                  Expanded(flex: 6, child: termPicker),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: weekPicker,
                    ),
                  ),
                ],
              )
            else ...[
              termPicker,
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                child: Row(
                  children: [
                    Expanded(child: weekPicker),
                    currentWeek,
                  ],
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: ScheduleWeekStrip(
                    weeks: snapshot.weeks,
                    selectedWeek: selectedWeek,
                    onSelected: selectWeek,
                  ),
                ),
                if (compact) currentWeek,
              ],
            ),
          ],
        );
      },
    );
  }

  List<Widget> _content(ScheduleResponse snapshot) => [
    AppleSection(
      footer: snapshot.fetchedAt == null && widget.service.isDemo
          ? const Text('离线合成样例')
          : Text('更新于 ${schoolTimestampLabel(snapshot.fetchedAt)}'),
      children: [_scheduleControls(snapshot)],
    ),
    if (MediaQuery.textScalerOf(context).scale(1) > 1.4)
      AppleSection(
        children: [
          ApplePickerTile<int>(
            title: '显示方式',
            value: viewMode,
            values: [0, 3, 1, if (snapshot.exams.isNotEmpty) 2],
            label: (value) => switch (value) {
              0 => '周课表 · 大字号使用每日清单',
              3 => '每日清单',
              1 => '学期',
              _ => '考试',
            },
            onSelected: (value) => setState(() => viewMode = value),
          ),
        ],
      )
    else
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SizedBox(
          width: double.infinity,
          child: CupertinoSlidingSegmentedControl<int>(
            groupValue: viewMode,
            onValueChanged: (value) => setState(() => viewMode = value ?? 0),
            children: {
              0: const Text('周课表'),
              3: const Text('每日清单'),
              1: const Text('学期'),
              if (snapshot.exams.isNotEmpty) 2: const Text('考试'),
            },
          ),
        ),
      ),
    if (viewMode == 0 || viewMode == 3) ...[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: CupertinoSearchTextField(
          key: const Key('schedule-search'),
          placeholder: '搜索课程、教师或地点',
          onChanged: (value) => setState(() {
            search = value;
            filter();
          }),
        ),
      ),
      if (filtered.isEmpty)
        AppleSection(
          children: [
            AppleEmptyState(
              title: search.trim().isNotEmpty
                  ? '没有匹配的课程'
                  : snapshot.weeks.isEmpty
                  ? '该学期暂无课表'
                  : '本周没有课程',
              description: search.trim().isNotEmpty
                  ? '请尝试其他关键词。'
                  : '可以切换其他学期或周次查看。',
            ),
          ],
        )
      else
        LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
            final grid = !largeText && viewMode == 0;
            return AppleContentTransition(
              identity: (
                snapshot.termId,
                snapshot.weekNumber,
                viewMode,
                largeText,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${filtered.length} 项课程${largeText && viewMode == 0 ? ' · 大字号使用每日清单' : ''}',
                            style: secondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (grid) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: ScheduleGrid(
                        courses: filtered,
                        weekStart: weeks[snapshot.weekNumber]?.startDate,
                        onCourseTap: showCourse,
                      ),
                    ),
                  ] else
                    for (final day in days.entries)
                      AppleSection(
                        header: Text(dayTitle(day.key, snapshot.weekNumber)),
                        children: [
                          for (final course in day.value) _courseRow(course),
                        ],
                      ),
                ],
              ),
            );
          },
        ),
    ] else if (viewMode == 1)
      AppleSection(
        header: const Text('学期周次'),
        children: [
          if (snapshot.weeks.isEmpty)
            const AppleEmptyState(
              title: '暂无学期周次',
              description: '学校尚未发布该学期的排课与周次数据。',
            ),
          for (final week in snapshot.weeks)
            _row(
              key: Key('schedule-semester-week-${week.number}'),
              onTap: () => selectWeek(week.number),
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
                    style: secondary(context),
                  ),
                ],
              ),
            ),
        ],
      )
    else
      AppleSection(
        header: const Text('考试安排'),
        children: [
          if (snapshot.exams.isEmpty)
            const AppleEmptyState(
              title: '本学期暂无考试安排',
              description: '请留意学校后续通知。',
            ),
          for (final exam in snapshot.exams)
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
                    Text(_examDetail(exam), style: secondary(context)),
                    if (exam.examSeatNo != null)
                      Text('座位 ${exam.examSeatNo}', style: secondary(context)),
                  ],
                ),
              ),
            ),
        ],
      ),
  ];

  String dayTitle(int day, int week) {
    final start = DateTime.tryParse(weeks[week]?.startDate ?? '');
    final date = start?.add(Duration(days: day - 1));
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final today =
        date != null &&
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    return '${weekdayNames[day - 1]}${date == null ? '' : ' · ${shortDate(date.toIso8601String())}'}${today ? ' · 今天' : ''}';
  }

  Widget _courseRow(ScheduleCourse course) =>
      ScheduleCourseRow(course: course, onTap: () => showCourse(course));

  Widget _row({required Widget child, required VoidCallback onTap, Key? key}) =>
      CupertinoButton(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(48, 48),
        onPressed: onTap,
        child: Row(
          children: [
            Expanded(
              child: DefaultTextStyle(
                style: DefaultTextStyle.of(context).style.copyWith(
                  color: CupertinoColors.label.resolveFrom(context),
                ),
                child: child,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_forward,
              size: 14,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ],
        ),
      );

  void showCourse(ScheduleCourse course) {
    final snapshot = data!;
    final week = weeks[snapshot.weekNumber];
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => CupertinoPageScaffold(
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
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                AppleSection(
                  children: [
                    _detail('星期', weekdayNames[course.day - 1]),
                    _detail(
                      '节次',
                      '第 ${course.startSection}–${course.endSection} 节',
                    ),
                    _detail('开始时间', course.startTime ?? '待定'),
                    _detail('结束时间', course.endTime ?? '待定'),
                    _detail('地点', course.place ?? '待定'),
                    _detail('教师', course.teacher ?? '待定'),
                  ],
                ),
                AppleSection(
                  children: [
                    _detail(
                      '学期',
                      terms[snapshot.termId]?.name ?? snapshot.termId,
                    ),
                    _detail('周次', '第 ${snapshot.weekNumber} 周'),
                    if (week != null)
                      _detail(
                        '日期范围',
                        '${shortDate(week.startDate)}–${shortDate(week.endDate)}',
                      ),
                    _detail('上课日期', dayTitle(course.day, snapshot.weekNumber)),
                  ],
                ),
                const SizedBox(height: 96),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, String value) =>
      ScheduleDetailLine(label: label, value: value);
}

TextStyle secondary(BuildContext context) => scheduleSecondary(context);

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
