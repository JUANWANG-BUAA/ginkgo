import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'reminders.dart';

import 'apple_widgets.dart';
import 'apple_design.dart';
import 'mirror_service.dart';
import 'homework_detail_page.dart';
import 'school_timestamp.dart';
import 'application/contracts.dart';
import 'course_visibility.dart';
import 'homework_projection.dart';

class HomeworkPage extends StatefulWidget {
  const HomeworkPage({super.key, required this.service});
  final AcademicGateway service;
  @override
  State<HomeworkPage> createState() => _HomeworkPageState();
}

class _HomeworkPageState extends State<HomeworkPage> {
  HomeworkResponse? data;
  String? error;
  String? notice;
  bool busy = false;
  int filter = 0;
  int pending = 0, submitted = 0, overdue = 0, unknown = 0;
  String search = '';
  final searchController = TextEditingController();
  List<HomeworkItem> visible = [];
  bool includeTeaching = false;
  CourseVisibility? range;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    range = CourseVisibilityScope.of(context);
    prepare();
  }

  void prepare() {
    final all = data?.items ?? <HomeworkItem>[];
    final personal = personalHomeworkItems(all, range);
    pending = personal
        .where((item) => item.status == HomeworkStatus.pending)
        .length;
    submitted = personal
        .where((item) => item.status == HomeworkStatus.submitted)
        .length;
    overdue = personal
        .where(
          (item) =>
              item.status == HomeworkStatus.pending && _isOverdue(item.dueAt),
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
                  (filter == 3 &&
                      item.status == HomeworkStatus.pending &&
                      _isOverdue(item.dueAt)) ||
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
    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> load({bool force = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final result = await widget.service.homework(forceRefresh: force);
      if (!mounted) return;
      final reminders = ReminderScope.of(context);
      reminders?.updateHomework(result);
      if (reminders != null) {
        reminders.markRead('homework');
        unawaited(reminders.reconcile());
      }
      setState(() {
        busy = false;
        if (result.failure != null) {
          if (data == null && result.termCode.isEmpty) {
            error = failureMessage(result.failure);
            return;
          }
          notice = '${failureMessage(result.failure)}，正在显示上次结果。';
          if (result.termCode.isEmpty) return;
        }
        data = result;
        prepare();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        busy = false;
        if (data == null) {
          error = failureMessage(null);
        } else {
          notice = '${failureMessage(null)}，正在显示上次结果。';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('homework-scroll'),
      slivers: [
        ApplePageHeader(
          largeTitle: const Text('作业'),
          border: null,
          trailing: AppleGlassButton(
            label: '刷新作业',
            onPressed: busy ? null : () => load(force: true),
            child: busy
                ? const CupertinoActivityIndicator()
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
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CupertinoActivityIndicator()),
            ),
          )
        else
          ..._content(data!),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    ),
  );

  String _filterLabel(int value) => switch (value) {
    1 => '待完成',
    2 => '已提交',
    3 => '已截止',
    4 => '待确认',
    _ => '全部',
  };

  List<Widget> _content(HomeworkResponse data) => [
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 20,
                runSpacing: 16,
                children: [
                  for (final metric in [
                    (label: '待完成', count: pending),
                    (label: '已提交', count: submitted),
                    (label: '已截止', count: overdue),
                  ])
                    SizedBox(
                      key: ValueKey('homework-summary-${metric.label}'),
                      width: MediaQuery.textScalerOf(context).scale(14) > 20
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 40) / 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${metric.count}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            metric.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.secondaryLabel.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
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
            _quickFilter(3, '已截止 $overdue', AppleDesign.statusDanger),
            _quickFilter(4, '待确认 $unknown', AppleDesign.statusUncertain),
          ],
        ),
      ),
    ),
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
        child: Text(
          '${visible.length} 项作业',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
          final late =
              item.status == HomeworkStatus.pending && _isOverdue(item.dueAt);
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
                    AppleListTile(
                      key: Key('homework-${item.id}'),
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => HomeworkDetailPage(
                            item: item,
                            service: widget.service,
                          ),
                        ),
                      ),
                      trailing: const CupertinoListTileChevron(),
                      title: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.courseRole == 'assistant')
                              const Text('助教课程 · 不代表个人待交作业'),
                            Wrap(
                              spacing: 10,
                              runSpacing: 7,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  item.dueAt == null
                                      ? '截止时间未确认'
                                      : '截止 ${schoolTimestampLabel(item.dueAt)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: late
                                        ? AppleDesign.statusDanger.resolveFrom(
                                            context,
                                          )
                                        : CupertinoColors.label.resolveFrom(
                                            context,
                                          ),
                                  ),
                                ),
                                _statusBadge(context, item),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.courseName,
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                            ),
                            if (item.teacherName?.trim().isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 3),
                              Text(
                                '教师 · ${item.teacherName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
                                ),
                              ),
                            ],
                          ],
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

  Widget _quickFilter(int value, String label, CupertinoDynamicColor tint) =>
      CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: tint
            .resolveFrom(context)
            .withValues(alpha: filter == value ? 0.2 : 0.08),
        minimumSize: const Size(44, 44),
        onPressed: () => setState(() {
          filter = filter == value ? 0 : value;
          prepare();
        }),
        child: Text(
          label,
          style: TextStyle(fontSize: 14, color: tint.resolveFrom(context)),
        ),
      );

  Widget _statusBadge(BuildContext context, HomeworkItem item) {
    final (label, color) = switch (item.status) {
      HomeworkStatus.submitted => (
        '已提交',
        AppleDesign.statusSuccess.resolveFrom(context),
      ),
      HomeworkStatus.pending =>
        _isOverdue(item.dueAt)
            ? ('已截止', AppleDesign.statusDanger.resolveFrom(context))
            : ('待完成', AppleDesign.statusPending.resolveFrom(context)),
      HomeworkStatus.unknown => (
        '待确认',
        AppleDesign.statusUncertain.resolveFrom(context),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  bool _isOverdue(String? due) {
    if (due == null) return false;
    final date = DateTime.tryParse(due);
    if (date == null) return false;
    // Offset-free school timestamps are Beijing civil time, not device time.
    final explicitZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(due);
    final instant = explicitZone
        ? date.toUtc()
        : DateTime.utc(
            date.year,
            date.month,
            date.day,
            date.hour,
            date.minute,
            date.second,
          ).subtract(const Duration(hours: 8));
    return instant.isBefore(DateTime.now().toUtc());
  }
}
