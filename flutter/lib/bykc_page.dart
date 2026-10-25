import 'package:flutter/cupertino.dart';

import 'apple_design.dart';
import 'apple_widgets.dart';
import 'loading_widgets.dart';
import 'long_page_scroll.dart';
import 'bykc_detail_page.dart';
import 'bykc_models.dart';
import 'bykc_widgets.dart';
export 'bykc_widgets.dart' show BykcStatisticsCard;
import 'mirror_service.dart';
import 'school_timestamp.dart';
import 'application/contracts.dart' as live;

typedef BykcLoader = Future<live.ReadOnlyResponse> Function({
  required BykcPart part,
  required bool forceRefresh,
});

class BykcPage extends StatefulWidget {
  const BykcPage({super.key, this.demo = false, this.loader, this.service});
  final bool demo;
  final BykcLoader? loader;
  final CampusGateway? service;
  @override
  State<BykcPage> createState() => _BykcPageState();
}

class _BykcSnapshot {
  BykcCatalog? catalog;
  BykcChosenCourses? chosen;
  BykcStatistics? statistics;
  String? error;
  bool loading = false, attempted = false;
  Future<void>? task;

  bool get hasData => catalog != null || chosen != null || statistics != null;
}

class _BykcPageState extends State<BykcPage> {
  final parts = {for (final part in BykcPart.values) part: _BykcSnapshot()};
  final scrollController = ScrollController();
  final searchController = TextEditingController();
  BykcPart selection = BykcPart.catalog;
  List<BykcCourse> visible = [];
  List<String> categories = ['全部'];
  String category = '全部', query = '', termName = '学期课程目录';
  _BykcSnapshot get current => parts[selection]!;

  @override
  void initState() {
    super.initState();
    load(BykcPart.catalog);
  }

  @override
  void dispose() {
    scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> load(BykcPart part, {bool force = false}) {
    final snapshot = parts[part]!;
    return snapshot.task ??= _fetch(
      part,
      force: force,
    ).whenComplete(() => snapshot.task = null);
  }

  Future<live.ReadOnlyResponse> _request(BykcPart part, bool force) {
    if (widget.loader != null) {
      return widget.loader!(part: part, forceRefresh: force);
    }
    final service = widget.service ?? mirrorServiceFor(demo: widget.demo);
    return service.bykcPart(part, forceRefresh: force);
  }

  Future<void> _fetch(BykcPart part, {required bool force}) async {
    final snapshot = parts[part]!;
    setState(() {
      snapshot.loading = true;
      snapshot.attempted = true;
      snapshot.error = null;
    });
    try {
      final result = await _request(part, force);
      String? payload = result.payload;
      if (!mounted) return;
      setState(() {
        snapshot.error = result.failure == null
            ? null
            : failureMessage(result.failure);
        if (payload != null) {
          switch (part) {
            case BykcPart.catalog:
              snapshot.catalog = bykcCatalog(payload);
              termName = snapshot.catalog!.currentTerm?.name ?? '学期课程目录';
              categories = [
                '全部',
                ...snapshot.catalog!.courses
                    .map((course) => course.categoryLabel)
                    .toSet()
                    .toList()
                  ..sort(),
              ];
              if (!categories.contains(category)) category = '全部';
              filter();
            case BykcPart.chosen:
              snapshot.chosen = bykcChosenCourses(payload);
            case BykcPart.statistics:
              snapshot.statistics = bykcStatistics(payload);
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => snapshot.error = failureMessage(null));
    } finally {
      if (mounted) setState(() => snapshot.loading = false);
    }
  }

  void filter() {
    final text = query.trim().toLowerCase();
    visible =
        parts[BykcPart.catalog]!.catalog?.courses
            .where(
              (course) =>
                  (category == '全部' || category == course.categoryLabel) &&
                  [course.name, course.teacher, course.position]
                      .whereType<String>()
                      .any((v) => v.toLowerCase().contains(text)),
            )
            .toList() ??
        const [];
  }

  String _label(BykcPart part) => switch (part) {
    BykcPart.catalog => '课程库',
    BykcPart.chosen => '已选课程',
    BykcPart.statistics => '完成统计',
  };

  void _select(BykcPart part) {
    FocusScope.of(context).unfocus();
    if (scrollController.hasClients) scrollController.jumpTo(0);
    setState(() => selection = part);
    if (!parts[part]!.attempted) load(part);
  }

  void _open(BykcCourse course, {BykcChosenRecord? record}) =>
      Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => BykcDetailPage(course: course, chosenRecord: record),
        ),
      );

  Widget _status() {
    if (current.loading && !current.hasData) {
      return const GinkgoLoadingView(label: '正在读取博雅课程…');
    }
    return AppleSection(
      children: [
        AppleListTile(
          leading: current.loading
              ? const GinkgoActivity(size: 17)
              : const Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  color: CupertinoColors.systemOrange,
                ),
          title: Text(current.loading ? '正在更新…' : current.error!),
          subtitle: !current.hasData ? null : const Text('保留上次结果'),
          trailing: current.loading
              ? null
              : CupertinoButton(
                  key: ValueKey('bykc-retry-${selection.name}'),
                  onPressed: () => load(selection, force: true),
                  child: const Text('重试'),
                ),
        ),
      ],
    );
  }

  Widget _heading(String title, {String? detail}) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        if (detail != null) ...[
          const SizedBox(height: 5),
          Text(
            detail,
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ],
    ),
  );

  /// Only visible rows are built, including large catalogs. Filters and parsed
  /// snapshots stay in state while moving among the three independent views.
  Widget _courseList(
    List<Object> rows, {
    bool chosen = false,
  }) => SliverList.builder(
    itemCount: rows.length,
    addAutomaticKeepAlives: false,
    itemBuilder: (context, index) {
      final record = chosen ? rows[index] as BykcChosenRecord : null;
      final course = chosen ? record!.course : rows[index] as BykcCourse;
      final details = course.details ?? BykcCourseDetails.empty();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRSuperellipse(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(index == 0 ? 20 : 0),
            bottom: Radius.circular(index == rows.length - 1 ? 20 : 0),
          ),
          child: ColoredBox(
            color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
              context,
            ),
            child: Column(
              children: [
                AppleListTile(
                  key: ValueKey(
                    chosen
                        ? 'bykc-chosen-${record!.id}'
                        : 'bykc-course-${course.id}',
                  ),
                  leading: chosen
                      ? Icon(
                          record!.passed == 1
                              ? CupertinoIcons.checkmark_seal_fill
                              : CupertinoIcons.book,
                          color: record.passed == 1
                              ? CupertinoColors.systemGreen
                              : CupertinoColors.activeBlue,
                        )
                      : null,
                  title: Text(
                    course.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            BykcLabel(
                              text: course.categoryLabel,
                              tint: switch (course.categoryLabel) {
                                '美育' => AppleDesign.resourcePurple.resolveFrom(
                                  context,
                                ),
                                '劳动教育' => AppleDesign.resourceTeal.resolveFrom(
                                  context,
                                ),
                                '安全健康' => AppleDesign.resourceBlue.resolveFrom(
                                  context,
                                ),
                                _ => CupertinoTheme.of(context).primaryColor,
                              },
                            ),
                            if (record == null && details.selected == true)
                              const BykcLabel(text: '已选', positive: true),
                            if (record == null &&
                                (details.enrolled != null ||
                                    details.capacity != null))
                              BykcLabel(
                                text:
                                    '人数 ${details.enrolled ?? '—'} / ${details.capacity ?? '未提供'}',
                                tint:
                                    (details.enrolled != null &&
                                        details.capacity != null &&
                                        details.enrolled! >= details.capacity!)
                                    ? AppleDesign.statusDanger.resolveFrom(
                                        context,
                                      )
                                    : (details.enrolled != null &&
                                          details.enrolled! > 0)
                                    ? AppleDesign.statusPending.resolveFrom(
                                        context,
                                      )
                                    : null,
                              ),
                          ],
                        ),
                        if (details.start != null) ...[
                          const SizedBox(height: 9),
                          BykcMetadata(
                            icon: CupertinoIcons.clock,
                            text: schoolTimestampLabel(details.start),
                            prominent: true,
                          ),
                        ],
                        if ((course.position ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 5),
                          BykcMetadata(
                            icon: CupertinoIcons.location,
                            text: course.position!,
                          ),
                        ],
                        if ((course.teacher ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 5),
                          BykcMetadata(
                            icon: CupertinoIcons.person,
                            text: course.teacher!,
                            auxiliary: true,
                          ),
                        ],
                        if (record != null) ...[
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              BykcLabel(
                                text: record.attendanceLabel,
                                positive: record.checkin == 1,
                              ),
                              BykcLabel(
                                text: record.resultLabel,
                                positive: record.passed == 1,
                              ),
                              if (record.score != null)
                                BykcLabel(text: '成绩 ${record.score}'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _open(course, record: record),
                ),
                if (index != rows.length - 1)
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
  );

  List<Widget> _catalog() => [
    SliverToBoxAdapter(
      child: AppleSection(
        children: [
          ApplePickerTile<String>(
            title: '类别',
            value: category,
            values: categories,
            label: (value) => value,
            onSelected: (value) => setState(() {
              category = value;
              filter();
            }),
          ),
        ],
      ),
    ),
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: CupertinoSearchTextField(
          key: const Key('bykc-search'),
          controller: searchController,
          placeholder: '搜索课程、教师或地点',
          onChanged: (value) => setState(() {
            query = value;
            filter();
          }),
        ),
      ),
    ),
    SliverToBoxAdapter(
      child: _heading(termName, detail: '${visible.length} 门课程'),
    ),
    if (visible.isEmpty)
      const SliverToBoxAdapter(
        child: AppleEmptyState(title: '没有匹配的课程', description: '可调整类别或搜索关键词。'),
      )
    else
      _courseList(visible),
  ];

  List<Widget> _chosen() {
    final data = current.chosen!;
    final rows = data.courses ?? const <BykcChosenRecord>[];
    return [
      SliverToBoxAdapter(
        child: _heading(
          data.term?.name ?? '当前学期',
          detail: data.courses == null
              ? '上游未提供有效学期范围，暂不能查询已选记录。'
              : '已选 ${rows.length} 门 · 考勤和成绩以学校记录为准',
        ),
      ),
      if (data.courses != null && rows.isEmpty)
        const SliverToBoxAdapter(
          child: AppleEmptyState(
            title: '本学期暂无已选课程',
            description: '学校返回了 0 条记录。',
          ),
        ),
      _courseList(rows, chosen: true),
    ];
  }

  List<Widget> _statistics() {
    final data = current.statistics!;
    final entries = data.entries;
    final groups = <String, List<BykcStatisticsEntry>>{};
    for (final entry in entries) {
      (groups[entry.category] ??= []).add(entry);
    }
    final rows = [
      for (final group in groups.entries)
        for (var index = 0; index < group.value.length; index++)
          (
            category: group.key,
            entry: group.value[index],
            first: index == 0,
            last: index == group.value.length - 1,
          ),
    ];
    return [
      SliverToBoxAdapter(
        child: AppleSection(
          header: const Text('学习进度'),
          footer: const Text('学校提供的累计统计，可能与本学期已选数量不同。'),
          children: [
            AppleListTile(
              leading: const Icon(
                CupertinoIcons.checkmark_seal,
                color: CupertinoColors.systemGreen,
              ),
              title: const Text('有效课程'),
              additionalInfo: Text(
                data.validCourseCount == null
                    ? '上游未提供'
                    : '${data.validCourseCount} 门',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      if (entries.isEmpty)
        const SliverToBoxAdapter(
          child: AppleEmptyState(
            title: '暂未返回完成统计',
            description: '学校尚未提供分类要求与完成数量。',
          ),
        ),
      SliverList.builder(
        itemCount: rows.length,
        addAutomaticKeepAlives: false,
        itemBuilder: (context, index) {
          final row = rows[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (row.first) _heading(row.category, detail: '已完成 / 应完成'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRSuperellipse(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(row.first ? 20 : 0),
                    bottom: Radius.circular(row.last ? 20 : 0),
                  ),
                  child: ColoredBox(
                    color: CupertinoColors.secondarySystemGroupedBackground
                        .resolveFrom(context),
                    child: Column(
                      children: [
                        BykcStatisticsCard(entry: row.entry),
                        if (!row.last)
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
              ),
            ],
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: LongPageScroll(
      controller: scrollController,
      child: CustomScrollView(
        key: const Key('bykc-scroll'),
        controller: scrollController,
        slivers: [
          ApplePageHeader(
            largeTitle: const Text('博雅'),
            section: '学业',
            subtitle: '查看活动、课程与个人记录',
            icon: CupertinoIcons.book_solid,
            previousPageTitle: '工作台',
            border: null,
            trailing: AppleGlassButton(
              label: '刷新博雅',
              onPressed: current.loading
                  ? null
                  : () => load(selection, force: true),
              child: current.loading
                  ? const GinkgoActivity(size: 17)
                  : const Icon(CupertinoIcons.refresh),
            ),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: () => load(selection, force: true),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: MediaQuery.textScalerOf(context).scale(14) > 20
                  ? ApplePickerTile<BykcPart>(
                      title: '查看',
                      value: selection,
                      values: BykcPart.values,
                      label: _label,
                      onSelected: _select,
                    )
                  : CupertinoSlidingSegmentedControl<BykcPart>(
                      groupValue: selection,
                      children: {
                        for (final part in BykcPart.values)
                          part: Text(_label(part)),
                      },
                      onValueChanged: (value) {
                        if (value != null) _select(value);
                      },
                    ),
            ),
          ),
          if (widget.demo)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Text(
                  '离线合成样例',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ),
          if (current.loading || current.error != null)
            SliverToBoxAdapter(child: _status()),
          if (current.hasData)
            ...switch (selection) {
              BykcPart.catalog => _catalog(),
              BykcPart.chosen => _chosen(),
              BykcPart.statistics => _statistics(),
            },
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    ),
  );
}
