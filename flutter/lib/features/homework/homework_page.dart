import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/shared/reminders.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/features/homework/homework_detail_page.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/shared/course_visibility.dart';
import 'package:ginkgo_mirror/features/schedule/course_range_page.dart';
import 'package:ginkgo_mirror/features/homework/homework_projection.dart';
import 'package:ginkgo_mirror/features/homework/homework_widgets.dart';

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
  int pending = 0, submitted = 0, overdue = 0, unknown = 0;
  String search = '';
  final searchController = TextEditingController();
  List<HomeworkItem> visible = [];
  bool includeTeaching = false;
  CourseVisibility? range;

  DateTime get _clock => widget.now ?? todaySchoolNow(DateTime.now());

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
                  (filter == 1 &&
                      item.status == HomeworkStatus.pending &&
                      !isHomeworkOverdue(item.dueAt, clock)) ||
                  (filter == 2 && item.status == HomeworkStatus.submitted) ||
                  (filter == 3 &&
                      item.status == HomeworkStatus.pending &&
                      isHomeworkOverdue(item.dueAt, clock)) ||
                  (filter == 4 && item.status == HomeworkStatus.unknown),
            )
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
          trailing: AppleGlassButton(
            label: '刷新作业',
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
              description: '请检查网络后重试。',
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
    )
    ),
  );

  List<Widget> _content(HomeworkResponse data) => [
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
        child: AppleSection(
          children: [
            AppleListTile(
              title: const Text('我的课程范围'),
              subtitle: const Text('管理学生课程与助教 / 教师课程'),
              trailing: const CupertinoListTileChevron(),
              onTap: () => Navigator.of(context).push(
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
            ),
          ],
        ),
      ),
    if (data.items.any((item) => item.courseRole == 'assistant'))
      SliverToBoxAdapter(
        child: AppleSection(
          footer: const Text('学校课程归属已确认的助教课程默认收起，不计入个人待完成统计；归属未知的课程会保留。'),
          children: [
            AppleListTile(
              title: const Text('包含助教课程'),
              trailing: CupertinoSwitch(
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
    SliverToBoxAdapter(
      child: AppleSection(
        header: Text(data.termName.isEmpty ? '本学期作业' : data.termName),
        children: [
          HomeworkSummaryMetrics(
            pending: pending,
            submitted: submitted,
            overdue: overdue,
          ),
        ],
      ),
    ),
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: MediaQuery.textScalerOf(context).scale(14) > 20
            ? ApplePickerTile<int>(
                title: '作业状态',
                value: filter,
                values: const [0, 1, 2, 3, 4],
                label: homeworkFilterLabel,
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
                children: const {
                  0: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('全部'),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('待完成', key: Key('homework-filter-pending')),
                  ),
                  2: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('已提交', key: Key('homework-filter-submitted')),
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
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            HomeworkQuickFilter(
              value: 1,
              label: '待完成 $pending',
              tint: AppleDesign.statusPending,
              selected: filter == 1,
              onPressed: () => _toggleFilter(1),
            ),
            HomeworkQuickFilter(
              value: 3,
              label: '已截止 $overdue',
              tint: AppleDesign.statusDanger,
              selected: filter == 3,
              onPressed: () => _toggleFilter(3),
            ),
            HomeworkQuickFilter(
              value: 4,
              label: '待确认 $unknown',
              tint: AppleDesign.statusUncertain,
              selected: filter == 4,
              onPressed: () => _toggleFilter(4),
            ),
          ],
        ),
      ),
    ),
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
        child: Text(
          '${visible.length} 项作业',
          style: const TextStyle(
            fontSize: AppleDesign.calloutSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
    if (visible.isEmpty)
      SliverToBoxAdapter(
        child: AppleEmptyState(
          title: search.trim().isEmpty ? '没有符合条件的作业' : '没有匹配的作业',
          description: '切换筛选或修改关键词。',
        ),
      )
    else
      SliverList.builder(
        itemCount: visible.length,
        addAutomaticKeepAlives: false,
        itemBuilder: (context, index) {
          final item = visible[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRSuperellipse(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(index == 0 ? 20 : 0),
                bottom: Radius.circular(index == visible.length - 1 ? 20 : 0),
              ),
              child: ColoredBox(
                color: CupertinoColors.secondarySystemGroupedBackground
                    .resolveFrom(context),
                child: Column(
                  children: [
                    HomeworkItemTile(
                      item: item,
                      clock: _clock,
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => HomeworkDetailPage(
                            fileActions: widget.fileActions,
                            item: item,
                            service: widget.service,
                          ),
                        ),
                      ),
                    ),
                    if (index != visible.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          height: 0.5,
                          color: CupertinoColors.separator
                              .resolveFrom(context)
                              .withValues(alpha: 0.2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Text(
          widget.service.isDemo ? '演示数据 · 截止时间为北京时间' : '来源：SPOC · 截止时间为北京时间',
          style: TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ),
    ),
  ];

  /// 快捷筛选再次点击同一项即回到「全部」。
  void _toggleFilter(int value) => setState(() {
    filter = filter == value ? 0 : value;
    prepare();
  });
}
