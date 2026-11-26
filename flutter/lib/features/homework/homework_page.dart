import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:ginkgo_mirror/shared/reminders.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
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
  late int filter; // 0: 待提交, 1: 已提交, 2: 已截止, 3: 全部, 4: 待确认
  int activePending = 0, submitted = 0, overduePending = 0, unknown = 0;
  int overdue = 0;
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
    0 => data == null ? '待提交' : '待提交 $activePending',
    1 => data == null ? '已提交' : '已提交 $submitted',
    2 => data == null ? '已截止' : '已截止 $overduePending',
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
    activePending = personal
        .where(
          (item) =>
              item.status == HomeworkStatus.pending &&
              !isHomeworkOverdue(item.dueAt, clock),
        )
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
    final scoped = includeTeaching
        ? all.where(
            (item) => !(range?.hidden('spoc', item.courseId ?? item.id) ?? false),
          )
        : personal;
    visible = scoped
        .where((item) {
          final isOverdue = isHomeworkOverdue(item.dueAt, clock);
          return switch (filter) {
            0 => item.status == HomeworkStatus.pending && !isOverdue,
            1 => item.status == HomeworkStatus.submitted,
            2 => item.status == HomeworkStatus.pending && isOverdue,
            4 => item.status == HomeworkStatus.unknown,
            _ => true,
          };
        })
        .where(
          (item) =>
              query.isEmpty ||
              [
                item.title,
                item.courseName,
                item.teacherName ?? '',
              ].any((s) => s.toLowerCase().contains(query)),
        )
        .toList();
    if (filter == 0 && visible.length > 1) {
      final indexed = [for (var i = 0; i < visible.length; i++) (i, visible[i])]
        ..sort((a, b) {
          final cmp = todayCompareDue(a.$2.dueAt, b.$2.dueAt);
          return cmp != 0 ? cmp : a.$1.compareTo(b.$1);
        });
      visible = [for (final entry in indexed) entry.$2];
    }
  }

  @override
  void initState() {
    super.initState();
    filter = widget.initialFilter;
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
          return SectionResult(
            error: failureMessage(
              result.failure,
              detail: result.failureDetail,
            ),
          );
        }
        return SectionResult(
          value: result.failure != null && result.termCode.isEmpty
              ? null
              : result,
          error: result.failure == null
              ? null
              : failureMessage(result.failure, detail: result.failureDetail),
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
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
          pending: activePending + overduePending,
          submitted: submitted,
          overdue: overdue,
          unknown: unknown,
          overduePending: overduePending,
          termCode: data.termCode,
          demo: widget.service.isDemo,
          selectedFilter: filter,
          onSelectFilter: (value) => setState(() {
            filter = value;
            prepare();
          }),
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
        child: GinkgoCard(
          key: const Key('homework-course-range'),
          margin: const EdgeInsets.fromLTRB(
            GinkgoSpacing.pageInset,
            GinkgoSpacing.sm,
            GinkgoSpacing.pageInset,
            0,
          ),
          padding: GinkgoSpacing.edgeInsetsListTile,
          onTap: () => Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => CourseRangePage(
                preferences: range!,
                system: 'spoc',
                courses: {
                  for (final item in data.items)
                    item.courseId ?? item.id: item.courseName,
                },
                courseRoles: {
                  for (final item in data.items)
                    if (homeworkCourseRoleLabel(item.courseRole) != null)
                      item.courseId ?? item.id: homeworkCourseRoleLabel(
                        item.courseRole,
                      )!,
                },
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.slider_horizontal_3,
                size: GinkgoIconTokens.glyphMd,
                color: CupertinoTheme.of(context).primaryColor,
              ),
              const SizedBox(width: GinkgoSpacing.sm),
              Expanded(
                child: Text(
                  '管理课程范围',
                  style: GinkgoTypography.callout.copyWith(
                    fontWeight: FontWeight.w500,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
              const CupertinoListTileChevron(),
            ],
          ),
        ),
      ),
    SliverToBoxAdapter(
      key: const Key('homework-status-summary'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          GinkgoSpacing.pageInset,
          GinkgoSpacing.base,
          GinkgoSpacing.pageInset,
          0,
        ),
        child: MediaQuery.textScalerOf(context).scale(14) > 20
            ? ApplePickerTile<int>(
                title: '作业状态',
                value: filter,
                values: [0, 1, 2, 3, if (unknown > 0) 4],
                label: _filterLabel,
                onSelected: (value) => setState(() {
                  filter = value;
                  prepare();
                }),
              )
            : CupertinoSlidingSegmentedControl<int>(
                groupValue: filter <= 3 ? filter : null,
                onValueChanged: (value) => setState(() {
                  filter = value ?? 0;
                  prepare();
                }),
                children: {
                  0: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: GinkgoSpacing.small,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '待提交 $activePending',
                        key: const Key('homework-filter-pending'),
                      ),
                    ),
                  ),
                  1: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: GinkgoSpacing.small,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '已提交 $submitted',
                        key: const Key('homework-filter-submitted'),
                      ),
                    ),
                  ),
                  2: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: GinkgoSpacing.small,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '已截止 $overduePending',
                        key: const Key('homework-filter-overdue'),
                      ),
                    ),
                  ),
                  3: const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: GinkgoSpacing.small,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('全部', key: Key('homework-filter-all')),
                    ),
                  ),
                },
              ),
      ),
    ),
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          GinkgoSpacing.pageInset,
          GinkgoSpacing.md,
          GinkgoSpacing.pageInset,
          0,
        ),
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
    if (data.items.any((item) => isNonStudentCourseRole(item.courseRole)))
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
      unknown: unknown,
      filter: filter,
      includeTeaching: includeTeaching,
      allPersonalSubmitted: _allPersonalSubmitted,
      search: search,
      clock: _clock,
      service: widget.service,
      fileActions: widget.fileActions,
      onToggleFilter: _toggleFilter,
      onShowAll: () => setState(() {
        filter = 3;
        search = '';
        searchController.clear();
        prepare();
      }),
      onClearFilters: () => setState(() {
        filter = 0;
        search = '';
        searchController.clear();
        prepare();
      }),
    ),
  ];

  /// 快捷筛选再次点击同一项即回到默认「待提交」。
  void _toggleFilter(int value) => setState(() {
    filter = filter == value ? 0 : value;
    prepare();
  });
}
