import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/widgets/long_page_scroll.dart';

import 'schedule_controls.dart';
import 'schedule_course_detail.dart';
import 'schedule_style.dart';
import 'schedule_views.dart';
import 'schedule_widgets.dart';

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
  ScheduleViewMode viewMode = ScheduleViewMode.weekGrid;
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
                ScheduleSection(
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
                ScheduleEmptySection(
                  title: error!,
                  description: '请检查网络后重试。',
                  error: true,
                  action: '重试',
                  onAction: () => load(force: true),
                )
              else if (data == null) const ScheduleLoadingSection(),
              const SizedBox(height: 96),
            ],
          ),
        ],
      ),
    ),
  );

  List<Widget> _content(ScheduleResponse snapshot) => [
    ScheduleSection(
      footer: snapshot.fetchedAt == null && widget.service.isDemo
          ? const Text('离线合成样例')
          : Text('更新于 ${schoolTimestampLabel(snapshot.fetchedAt)}'),
      children: [
        ScheduleControls(
          snapshot: snapshot,
          terms: terms,
          weeks: weeks,
          selectedTerm: selectedTerm,
          selectedWeek: selectedWeek,
          onSelectTerm: (termId) => load(termId: termId),
          onSelectWeek: selectWeek,
        ),
      ],
    ),
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
        onSearchChanged: (value) => setState(() {
          search = value;
          filter();
        }),
        onCourseTap: showCourse,
      )
    else if (viewMode == ScheduleViewMode.semester)
      ScheduleSemesterWeeks(weeks: snapshot.weeks, onSelected: selectWeek)
    else
      ScheduleExamList(exams: snapshot.exams),
  ];

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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<ScheduleViewMode>(
          groupValue: viewMode,
          onValueChanged: (value) =>
              setState(() => viewMode = value ?? ScheduleViewMode.weekGrid),
          children: {
            for (final mode in modes)
              mode: Text(scheduleViewModeLabel(mode)),
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
          dayTitle: scheduleDayTitle(
            course.day,
            week?.startDate,
          ),
        ),
      ),
    );
  }
}
