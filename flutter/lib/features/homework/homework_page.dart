import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:ginkgo_mirror/shared/reminders.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/application/school_rules.dart'
    show HomeworkDeadlineStatus;
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/shared/course_visibility.dart';
import 'package:ginkgo_mirror/features/schedule/course_range_page.dart';
import 'package:ginkgo_mirror/features/homework/homework_list_slivers.dart';
import 'package:ginkgo_mirror/features/homework/homework_projection.dart';
import 'package:ginkgo_mirror/features/homework/homework_visuals.dart';

import 'package:ginkgo_mirror/shared/today_time.dart';

class HomeworkPage extends StatefulWidget {
  const HomeworkPage({
    super.key,
    required this.service,
    required this.fileActions,
    this.initialFilter = 0,
    this.now,
  });
  final AcademicGateway service;

  /// The platform actions bound by the composition root.
  final PlatformActions fileActions;
  final int initialFilter;
  final DateTime? now;
  @override
  State<HomeworkPage> createState() => _HomeworkPageState();
}

class _HomeworkPageState extends State<HomeworkPage> {
  late final RefreshSection<HomeworkResponse> section;
  HomeworkResponse? get data => section.value;
  String? get error => data == null ? section.error : null;
  String? get notice => data != null && section.error != null
      ? '${section.error}，正在显示上次结果。'
      : null;
  bool get busy => section.loading;
  late int filter;
  int deadlineFilter = 0; // 0: all, 1: active, 2: overdue, 3: unknown
  int pending = 0, submitted = 0, overdue = 0, unknown = 0;
  int overduePending = 0;
  String search = '';
  final searchController = TextEditingController();
  List<HomeworkItem> visible = [];
  bool includeTeaching = false;
  CourseVisibility? range;

  DateTime get _clock => widget.now ?? todaySchoolNow(DateTime.now());

  bool get _allPersonalSubmitted {
    final items = personalHomeworkItems(data?.items ?? [], range);
    return items.isNotEmpty &&
        items.every((item) => item.status == HomeworkStatus.submitted);
  }

  String _filterLabel(int value) => switch (value) {
    1 => data == null ? '待完成' : '待完成 $pending',
    2 => data == null ? '已提交' : '已提交 $submitted',
    3 => '已截止 $overdue',
    4 => '待确认 $unknown',
    _ => '全部',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    range = CourseVisibilityScope.of(context);
    prepare();
  }

  void prepare() {
    final all = data?.items ?? <HomeworkItem>[];
    final personal = personalHomeworkItems(all, range);
    final clock = _clock;
    pending = personal
        .where((item) => item.status == HomeworkStatus.pending)
        .length;
    submitted = personal
        .where((item) => item.status == HomeworkStatus.submitted)
        .length;
    overdue = personal
        .where((item) => isHomeworkOverdue(item.dueAt, clock))
        .length;
    overduePending = personal
        .where(
          (item) =>
              item.status == HomeworkStatus.pending &&
              isHomeworkOverdue(item.dueAt, clock),
        )
        .length;
    unknown = personal
        .where((item) => item.status == HomeworkStatus.unknown)
        .length;
    final query = search.trim().toLowerCase();
    visible =
        (includeTeaching
                ? all.where(
                    (item) =>
                        !(range?.hidden('spoc', item.courseId ?? item.id) ??
                            false),
                  )
                : personal)
            .where(
              (item) =>
                  filter == 0 ||
                  (filter == 1 && item.status == HomeworkStatus.pending) ||
                  (filter == 2 && item.status == HomeworkStatus.submitted) ||
                  (filter == 4 && item.status == HomeworkStatus.unknown),
            )
            .where((item) {
              if (deadlineFilter == 0) return true;
              final status = classifyHomeworkDeadline(item.dueAt, clock);
              return switch (deadlineFilter) {
                1 => status == HomeworkDeadlineStatus.active,
                2 => status == HomeworkDeadlineStatus.overdue,
                _ =>
                  status == HomeworkDeadlineStatus.undated ||
                      status == HomeworkDeadlineStatus.invalid,
              };
            })
            .where(
              (item) =>
                  query.isEmpty ||
                  [
                    item.title,
                    item.courseName,
                    item.teacherName ?? "",
                  ].any((s) => s.toLowerCase().contains(query)),
            )
            .toList();
  }

  @override
  void initState() {
    super.initState();
    filter = widget.initialFilter == 3 ? 1 : widget.initialFilter;
    deadlineFilter = widget.initialFilter == 3 ? 2 : 0;
    section = RefreshSection<HomeworkResponse>()
      ..addListener(() {
        if (mounted) setState(prepare);
      });
    load();
  }

  @override
  void didUpdateWidget(HomeworkPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      section
        ..invalidate()
        ..value = null
        ..error = null
        ..loading = false;
      load();
    } else if (oldWidget.now != widget.now) {
      prepare();
    }
  }

  @override
  void dispose() {
    section.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> load({bool force = false}) {
    final service = widget.service;
    return section.refresh(
      () async {
        final result = await service.homework(forceRefresh: force);
        if (!mounted || service != widget.service) {
          return const SectionResult<HomeworkResponse>();
        }
        final reminders = ReminderScope.of(context);
        reminders?.updateHomework(result);
        if (reminders != null) {
          reminders.markRead('homework');
          unawaited(reminders.reconcile());
        }
        if (result.failure != null && data == null && result.termCode.isEmpty) {
          return SectionResult(error: failureMessage(result.failure));
        }
        return SectionResult(
          value: result.failure != null && result.termCode.isEmpty
              ? null
              : result,
          error: result.failure == null ? null : failureMessage(result.failure),
        );
      },
      fallbackError: failureMessage(null),
      force: force,
    );
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: SafeArea(
      child: CustomScrollView(
        key: const Key('homework-scroll'),
        slivers: [
          ApplePageHeader(
            largeTitle: const Text('作业'),
            section: '学业',
            subtitle: '区分个人作业状态与助教课程',
            icon: CupertinoIcons.doc_text,
            border: null,
            trailing: AppleToolbarButton(
              label: '刷新作业',
              busy: busy,
              onPressed: busy ? null : () => load(force: true),
              child: busy
                  ? const GinkgoActivity(size: 17)
                  : const Icon(CupertinoIcons.refresh, size: 24),
            ),
          ),
          CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
          if (notice != null)
            SliverToBoxAdapter(
              child: AppleSection(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      notice!,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppleDesign.statusPending.resolveFrom(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (error != null)
            SliverToBoxAdapter(
              child: AppleEmptyState(
                title: error!,
                description: '请根据上方提示处理后重试。',
                error: true,
                action: '重试',
                onAction: () => load(force: true),
              ),
            )
          else if (data == null)
            const SliverToBoxAdapter(child: GinkgoLoadingView(label: '正在读取作业…'))
          else
            ..._content(data!),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    ),
  );

  List<Widget> _content(HomeworkResponse data) => [
    if (data.items.isNotEmpty)
      SliverToBoxAdapter(
        child: HomeworkTelemetryCard(
          pending: pending,
          submitted: submitted,
          overdue: overdue,
          unknown: unknown,
          overduePending: overduePending,
          termCode: data.termCode,
          demo: widget.service.isDemo,
        ),
      ),
    if (data.rolesComplete == false)
      const SliverToBoxAdapter(
        child: AppleSection(
          children: [
            AppleListTile(
              title: Text('作业结果不完整'),
              subtitle: Text('课程身份未能全部核对；已显示的作业仍可查看。'),
            ),
          ],
        ),
      ),
    if (range != null && data.items.isNotEmpty)
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: GinkgoSpacing.pageInset,
            top: GinkgoSpacing.xs,
            end: GinkgoSpacing.pageInset,
          ),
          child: CupertinoButton(
            key: const Key('homework-course-range'),
            padding: const EdgeInsets.symmetric(
              horizontal: GinkgoSpacing.sm,
              vertical: GinkgoSpacing.xs,
            ),
            minimumSize: const Size(48, 48),
            alignment: Alignment.centerLeft,
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (_) => CourseRangePage(
                  preferences: range!,
                  system: 'spoc',
                  courses: {
                    for (final item in data.items)
                      item.courseId ?? item.id: item.courseName,
                  },
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.slider_horizontal_3,
                  size: 18,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '管理课程范围',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ),
                const CupertinoListTileChevron(),
              ],
            ),
          ),
        ),
      ),
    SliverToBoxAdapter(
      key: const Key('homework-status-summary'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: MediaQuery.textScalerOf(context).scale(14) > 20
            ? ApplePickerTile<int>(
                title: '作业状态',
                value: filter,
                values: const [0, 1, 2, 4],
                label: _filterLabel,
                onSelected: (value) => setState(() {
                  filter = value;
                  prepare();
                }),
              )
            : CupertinoSlidingSegmentedControl<int>(
                groupValue: filter <= 2 ? filter : null,
                onValueChanged: (value) => setState(() {
                  filter = value ?? 0;
                  prepare();
                }),
                children: {
                  0: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('全部'),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '待完成 $pending',
                      key: const Key('homework-filter-pending'),
                    ),
                  ),
                  2: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '已提交 $submitted',
                      key: const Key('homework-filter-submitted'),
                    ),
                  ),
                },
              ),
      ),
    ),
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: CupertinoSearchTextField(
          key: const Key('homework-search'),
          controller: searchController,
          placeholder: '搜索作业、课程或教师',
          onChanged: (value) => setState(() {
            search = value;
            prepare();
          }),
        ),
      ),
    ),
    if (data.items.any((item) => item.courseRole == 'assistant'))
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: GinkgoSpacing.xl,
            top: GinkgoSpacing.sm,
            end: GinkgoSpacing.xl,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '包含助教课程\n筛选计数仅包含个人课程',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
              Semantics(
                label: '包含助教课程',
                child: CupertinoSwitch(
                  value: includeTeaching,
                  onChanged: (value) => setState(() {
                    includeTeaching = value;
                    prepare();
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    ...buildHomeworkListSlivers(
      context: context,
      data: data,
      visible: visible,
      overdue: overdue,
      overduePending: overduePending,
      unknown: unknown,
      filter: filter,
      deadlineFilter: deadlineFilter,
      includeTeaching: includeTeaching,
      allPersonalSubmitted: _allPersonalSubmitted,
      search: search,
      clock: _clock,
      service: widget.service,
      fileActions: widget.fileActions,
      onToggleFilter: _toggleFilter,
      onToggleDeadline: _toggleDeadline,
      onClearFilters: () => setState(() {
        filter = 0;
        deadlineFilter = 0;
        search = '';
        searchController.clear();
        prepare();
      }),
    ),
  ];

  /// 快捷筛选再次点击同一项即回到「全部」。
  void _toggleFilter(int value) => setState(() {
    filter = filter == value ? 0 : value;
    prepare();
  });

  void _toggleDeadline(int value) => setState(() {
    deadlineFilter = deadlineFilter == value ? 0 : value;
    prepare();
  });
}
