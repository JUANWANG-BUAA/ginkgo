import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/application/schedule_ics.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_modal_sheet.dart';
import 'package:ginkgo_mirror/widgets/long_page_scroll.dart';

import 'schedule_controls.dart';
import 'schedule_course_detail.dart';
import 'schedule_style.dart';
import 'schedule_views.dart';
import 'schedule_week_strip.dart';
import 'schedule_widgets.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({
    super.key,
    required this.service,
    this.fileActions = const PlatformActions(),
    this.onOpenCheckIn,
  });
  final AcademicGateway service;
  final PlatformActions fileActions;
  final VoidCallback? onOpenCheckIn;
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
  ScheduleViewMode viewMode = ScheduleViewMode.weekGrid;
  int selectedDay = 1;
  int requestId = 0;
  String search = '';
  bool searchVisible = false;
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

  @override
  void didUpdateWidget(SchedulePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      requestId++;
      data = null;
      error = null;
      notice = null;
      busy = false;
      selectedWeek = 0;
      selectedTerm = null;
      selectedDay = 1;
      search = '';
      searchVisible = false;
      sorted = [];
      filtered = [];
      days = {};
      weeks = {};
      terms = {};
      load();
    }
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
        if (result.failure != null && result.termId.isEmpty) {
          failed(failureMessage(result.failure));
          return;
        }
        if (requestedWeek != null &&
            result.weekNumber != requestedWeek &&
            result.termId == (data?.termId ?? result.termId)) {
          failed('第 $requestedWeek 周尚未缓存');
          return;
        }
        final replaceSnapshot =
            data == null ||
            data!.termId != result.termId ||
            data!.weekNumber != result.weekNumber;
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
        if (replaceSnapshot) {
          selectedDay =
              scheduleTodayColumn(weeks[result.weekNumber]?.startDate) ??
              (days.keys.isEmpty ? 1 : days.keys.first);
        }
        if (result.exams.isEmpty && viewMode == ScheduleViewMode.exam) {
          viewMode = ScheduleViewMode.weekGrid;
        }
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
    if (viewMode == ScheduleViewMode.semester ||
        viewMode == ScheduleViewMode.exam) {
      setState(() => viewMode = ScheduleViewMode.weekGrid);
    }
    load(week: week);
  }

  void _swipeWeek(int delta) {
    final snapshot = data;
    if (snapshot == null || snapshot.weeks.isEmpty) return;
    final currentIndex = snapshot.weeks.indexWhere(
      (w) => w.number == selectedWeek,
    );
    if (currentIndex < 0) return;
    final nextIndex = (currentIndex + delta).clamp(0, snapshot.weeks.length - 1);
    if (nextIndex == currentIndex) return;
    selectWeek(snapshot.weeks[nextIndex].number);
  }

  Future<void> _exportIcs() async {
    final snapshot = data;
    final saver = widget.fileActions.learningFileSaver;
    if (snapshot == null || saver == null || snapshot.courses.isEmpty) return;
    unawaited(HapticFeedback.lightImpact());
    try {
      final saved = await saver(
        LearningDownload(
          scheduleIcsFileName(snapshot),
          buildScheduleIcsBytes(snapshot),
        ),
        () => mounted,
      );
      if (saved != null && mounted) {
        setState(() => notice = '已导出第 ${snapshot.weekNumber} 周日历文件 (.ics)');
      }
    } catch (_) {
      if (mounted) setState(() => notice = '导出日历失败，请重试');
    }
  }

  Future<void> _showConflictCourses(List<ScheduleCourse> overlap) async {
    final chosen = await showGinkgoModalSheet<ScheduleCourse>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: GinkgoSpacing.edgeInsetsCard,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '该时段有 ${overlap.length} 门重叠课程',
                style: GinkgoTypography.headline.copyWith(
                  color: CupertinoColors.label.resolveFrom(sheetContext),
                ),
              ),
              const SizedBox(height: GinkgoSpacing.sm),
              for (final course in overlap)
                ScheduleCourseRow(
                  course: course,
                  onTap: () => Navigator.of(sheetContext).pop(course),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null && mounted) showCourse(chosen);
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: SafeArea(
      child: LongPageScroll(
        controller: scrollController,
        child: CustomScrollView(
          controller: scrollController,
          key: const Key('schedule-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
            SliverList.list(
              children: [
                if (data != null)
                  ..._content(data!)
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      GinkgoSpacing.pageInset,
                      GinkgoSpacing.sm,
                      GinkgoSpacing.pageInset,
                      GinkgoSpacing.xs,
                    ),
                    child: Text(
                      '课表',
                      style: GinkgoTypography.title.copyWith(
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                  ),
                  if (error != null)
                    AppleStatusSection(
                      title: error!,
                      description: '请检查网络连接后重试。',
                      error: true,
                      action: '重试',
                      onAction: () => load(force: true),
                    )
                  else
                    const ScheduleLoadingSection(),
                ],
                if (notice != null && data == null) _noticeBanner(),
                const SizedBox(height: GinkgoSpacing.bottomScrollClearance),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _noticeBanner() => ScheduleSection(
    children: [
      Padding(
        padding: GinkgoSpacing.edgeInsetsCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notice!,
              style: TextStyle(
                color: CupertinoColors.systemOrange.resolveFrom(context),
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
  );

  List<Widget> _content(ScheduleResponse snapshot) {
    final syncNote = snapshot.fetchedAt == null && widget.service.isDemo
        ? '离线合成样例'
        : '更新于 ${schoolTimestampLabel(snapshot.fetchedAt)}';
    final countSummary = snapshot.exams.isEmpty
        ? '${filtered.length} 节课 · $syncNote'
        : '${filtered.length} 节课 · ${snapshot.exams.length} 场考试 · $syncNote';

    return [
      ScheduleControls(
        snapshot: snapshot,
        terms: terms,
        weeks: weeks,
        selectedTerm: selectedTerm,
        selectedWeek: selectedWeek,
        busy: busy,
        searchActive: searchVisible || search.isNotEmpty,
        onSelectTerm: (termId) => load(termId: termId),
        onSelectWeek: selectWeek,
        onToggleSearch: () => setState(() {
          searchVisible = !searchVisible;
          if (!searchVisible && search.isNotEmpty) {
            search = '';
            filter();
          }
        }),
        onRefresh: () => load(force: true),
        onExportIcs: widget.fileActions.learningFileSaver == null
            ? null
            : _exportIcs,
      ),
      if (snapshot.weeks.isNotEmpty)
        ScheduleWeekStrip(
          weeks: snapshot.weeks,
          selectedWeek: selectedWeek,
          onSelected: selectWeek,
        ),
      if (notice != null) _noticeBanner(),
      _viewModeSwitch(snapshot),
      if (viewMode == ScheduleViewMode.weekGrid ||
          viewMode == ScheduleViewMode.dayList)
        ScheduleCourseBrowser(
          snapshot: snapshot,
          courses: filtered,
          days: days,
          weeks: weeks,
          mode: viewMode,
          search: search,
          searchVisible: searchVisible,
          selectedDay: selectedDay,
          onSelectedDay: (day) => setState(() => selectedDay = day),
          onSearchChanged: (value) => setState(() {
            search = value;
            filter();
          }),
          onCourseTap: showCourse,
          onConflictTap: _showConflictCourses,
          onSwipeWeek: _swipeWeek,
        )
      else if (viewMode == ScheduleViewMode.semester)
        ScheduleSemesterWeeks(weeks: snapshot.weeks, onSelected: selectWeek)
      else
        ScheduleExamList(exams: snapshot.exams),
      SummaryLine('本周课表', countSummary, icon: CupertinoIcons.calendar),
    ];
  }

  Widget _viewModeSwitch(ScheduleResponse snapshot) {
    final modes = <ScheduleViewMode>[
      ScheduleViewMode.weekGrid,
      ScheduleViewMode.dayList,
      ScheduleViewMode.semester,
      if (snapshot.exams.isNotEmpty) ScheduleViewMode.exam,
    ];
    if (MediaQuery.textScalerOf(context).scale(1) > 1.4) {
      return ScheduleSection(
        children: [
          ApplePickerTile<ScheduleViewMode>(
            title: '显示方式',
            value: viewMode,
            values: modes,
            label: scheduleViewModeDescription,
            onSelected: (value) => setState(() => viewMode = value),
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GinkgoSpacing.md,
        0,
        GinkgoSpacing.md,
        GinkgoSpacing.xs,
      ),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<ScheduleViewMode>(
          groupValue: viewMode,
          onValueChanged: (value) =>
              setState(() => viewMode = value ?? ScheduleViewMode.weekGrid),
          children: {
            for (final mode in modes)
              mode: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(scheduleViewModeLabel(mode)),
              ),
          },
        ),
      ),
    );
  }

  void showCourse(ScheduleCourse course) {
    final snapshot = data!;
    final week = weeks[snapshot.weekNumber];
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => ScheduleCourseDetailPage(
          course: course,
          termName: terms[snapshot.termId]?.name ?? snapshot.termId,
          weekNumber: snapshot.weekNumber,
          week: week,
          dayTitle: scheduleDayTitle(course.day, week?.startDate),
          onOpenCheckIn: widget.onOpenCheckIn,
        ),
      ),
    );
  }
}
