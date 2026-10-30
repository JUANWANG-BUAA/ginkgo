import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/widgets/long_page_scroll.dart';
import 'package:ginkgo_mirror/features/bykc/bykc_detail_page.dart';
import 'package:ginkgo_mirror/features/bykc/bykc_course_tile.dart';
import 'package:ginkgo_mirror/application/bykc.dart';
import 'package:ginkgo_mirror/features/bykc/bykc_statistics_view.dart';
import 'package:ginkgo_mirror/features/bykc/bykc_widgets.dart';
export 'package:ginkgo_mirror/features/bykc/bykc_widgets.dart'
    show BykcStatisticsCard;
import 'package:ginkgo_mirror/application/mirror_service.dart';

typedef BykcLoader = Future<BykcPartRead> Function({
  required BykcPart part,
  required bool forceRefresh,
});

class BykcPage extends StatefulWidget {
  const BykcPage({super.key, this.demo = false, this.loader, this.service});
  final bool demo;
  final BykcLoader? loader;
  final BykcGateway? service;
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

  Future<BykcPartRead> _request(BykcPart part, bool force) {
    if (widget.loader != null) {
      return widget.loader!(part: part, forceRefresh: force);
    }
    final service = widget.service;
    // The shell already resolved one. A fallback locator here would give the
    // page its own adapter instance, and therefore its own account binding.
    if (service == null) throw StateError('当前页面没有可用的博雅服务');
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
      if (!mounted) return;
      setState(() {
        snapshot.error = result.failure == null
            ? null
            : failureMessage(result.failure);
        switch (result) {
          case BykcCatalogRead(:final data):
            if (data == null) return;
            snapshot.catalog = data;
            termName = data.currentTerm?.name ?? '学期课程目录';
            categories = [
              '全部',
              ...data.courses
                  .map((course) => course.categoryLabel)
                  .toSet()
                  .toList()
                ..sort(),
            ];
            if (!categories.contains(category)) category = '全部';
            filter();
          case BykcChosenRead(:final data):
            if (data != null) snapshot.chosen = data;
          case BykcStatisticsRead(:final data):
            if (data != null) snapshot.statistics = data;
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

  Widget _heading(String title, {String? detail}) =>
      BykcSectionHeading(title: title, detail: detail);

  /// Only visible rows are built, including large catalogs. Filters and parsed
  /// snapshots stay in state while moving among the three independent views.
  Widget _courseList(List<Object> rows, {bool chosen = false}) =>
      SliverList.builder(
        itemCount: rows.length,
        addAutomaticKeepAlives: false,
        itemBuilder: (context, index) {
          final record = chosen ? rows[index] as BykcChosenRecord : null;
          final course = chosen ? record!.course : rows[index] as BykcCourse;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SafeArea(
              child: ClipRSuperellipse(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(index == 0 ? 20 : 0),
                bottom: Radius.circular(index == rows.length - 1 ? 20 : 0),
              ),
              child: ColoredBox(
                color: CupertinoColors.secondarySystemGroupedBackground
                    .resolveFrom(context),
                child: Column(
                  children: [
                    BykcCourseTile(
                      course: course,
                      record: record,
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
            )
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

  Widget _statistics() => BykcStatisticsView(data: current.statistics!);

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
              BykcPart.statistics => [_statistics()],
            },
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    ),
  );
}
