import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'mirror_service.dart';
import 'schedule_grid.dart';
import 'schedule_style.dart';
import 'school_timestamp.dart';
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
  String? selectedTerm;
  int viewMode = 0;
  int requestId = 0;
  String search = '';
  final weekScroll = ScrollController();
  (double, double, int, int)? weekStripLayout;
  int weekStripGeneration = 0;

  @override
  void dispose() {
    weekScroll.dispose();
    super.dispose();
  }

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
    setState(() {
      busy = true;
      error = null;
      notice = null;
      selectedTerm = requestedTerm;
      if (requestedWeek != null) selectedWeek = requestedWeek;
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
        weekStripLayout = null;
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
    child: CustomScrollView(
      key: const Key('schedule-scroll'),
      slivers: [
        ApplePageHeader(
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
                children: [
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CupertinoActivityIndicator(),
                        SizedBox(width: 10),
                        Text('正在读取课表…'),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 96),
          ],
        ),
      ],
    ),
  );

  List<Widget> _content(ScheduleResponse snapshot) => [
    AppleSection(
      footer: snapshot.fetchedAt == null && widget.service.isDemo
          ? const Text('离线合成样例')
          : Text('更新于 ${schoolTimestampLabel(snapshot.fetchedAt)}'),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Builder(
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
                    load(termId: id);
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      terms[selectedTerm]?.name ?? snapshot.termId,
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (snapshot.weeks.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '第 $selectedWeek 周',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (snapshot.weeks.any((item) => item.current))
                      CupertinoButton(
                        key: const Key('schedule-current-week'),
                        onPressed: () => selectWeek(
                          snapshot.weeks
                              .firstWhere((item) => item.current)
                              .number,
                        ),
                        child: const Text('本周'),
                      ),
                  ],
                ),
              ),
              if (weeks[selectedWeek] case final ScheduleWeek range)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${shortDate(range.startDate)} – ${shortDate(range.endDate)}',
                      style: secondary(context),
                    ),
                  ),
                ),
              _weekStrip(snapshot),
            ],
          ],
        ),
      ],
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

  Widget _weekStrip(ScheduleResponse snapshot) {
    const gap = 8.0;
    const padding = 16.0;
    const labelStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    var labelWidth = 0.0, labelHeight = 0.0;
    for (final week in snapshot.weeks) {
      painter.text = TextSpan(
        text: '第 ${week.number} 周',
        style: DefaultTextStyle.of(context).style.merge(labelStyle),
      );
      painter.layout();
      if (painter.width > labelWidth) labelWidth = painter.width;
      if (painter.height > labelHeight) labelHeight = painter.height;
    }
    painter.dispose();
    final chipWidth = (labelWidth + 24).clamp(76.0, double.infinity);
    final extent = chipWidth + gap;
    return SizedBox(
      height: labelHeight + 24,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final index = snapshot.weeks.indexWhere(
            (week) => week.number == selectedWeek,
          );
          final layout = (
            constraints.maxWidth,
            extent,
            index,
            snapshot.weeks.length,
          );
          if (weekStripLayout != layout) {
            weekStripLayout = layout;
            final generation = ++weekStripGeneration;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted ||
                  generation != weekStripGeneration ||
                  index < 0 ||
                  !weekScroll.hasClients) {
                return;
              }
              final position = weekScroll.position;
              if (!position.hasContentDimensions) return;
              final center = padding + index * extent + chipWidth / 2;
              weekScroll.jumpTo(
                (center - position.viewportDimension / 2).clamp(
                  position.minScrollExtent,
                  position.maxScrollExtent,
                ),
              );
            });
          }
          return ListView.builder(
            key: const Key('schedule-weeks'),
            controller: weekScroll,
            itemExtent: extent,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(padding, 4, padding, 8),
            itemCount: snapshot.weeks.length,
            itemBuilder: (context, index) {
              final week = snapshot.weeks[index];
              final active = week.number == selectedWeek;
              final color = CupertinoTheme.of(context).primaryColor;
              return Padding(
                padding: const EdgeInsets.only(right: gap),
                child: CupertinoButton(
                  key: Key('schedule-week-${week.number}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: const Size(76, 0),
                  color: active
                      ? color.withValues(alpha: 0.14)
                      : CupertinoColors.tertiarySystemFill.resolveFrom(context),
                  onPressed: () => selectWeek(week.number),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '第 ${week.number} 周',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: active
                              ? color
                              : CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

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

  Widget _courseRow(ScheduleCourse course) {
    final large = MediaQuery.textScalerOf(context).scale(16) > 22;
    final time = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          course.startTime ?? '时间待定',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        if (course.endTime != null)
          Text(
            course.endTime!,
            style: secondary(context).copyWith(fontSize: 13),
          ),
        const SizedBox(height: 5),
        Text(
          '第${course.startSection}–${course.endSection}节',
          style: secondary(context).copyWith(fontSize: 12),
        ),
      ],
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(course.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (course.place?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(course.place!, style: secondary(context)),
          ),
        if (course.teacher?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(course.teacher!, style: secondary(context)),
          ),
      ],
    );
    return _row(
      key: Key('schedule-course-${course.id}'),
      onTap: () => showCourse(course),
      child: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [time, const SizedBox(height: 12), content],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 78, child: time),
                Container(
                  width: 4,
                  height: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: courseColor(context, course.color, course.name),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(child: content),
              ],
            ),
    );
  }

  Widget _row({required Widget child, required VoidCallback onTap, Key? key}) =>
      CupertinoButton(
        key: key,
        padding: const EdgeInsets.all(16),
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

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.all(16),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: secondary(context)),
          const SizedBox(height: 5),
          Text(value),
        ],
      ),
    ),
  );
}

TextStyle secondary(BuildContext context) => TextStyle(
  fontSize: 14,
  color: CupertinoColors.secondaryLabel.resolveFrom(context),
);

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
