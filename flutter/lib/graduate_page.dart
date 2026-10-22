import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'academic_widgets.dart';
import 'graduate_models.dart';
import 'graduate_widgets.dart';
export 'graduate_widgets.dart' show GraduateCreditProgress;
import 'mirror_service.dart';
import 'application/contracts.dart' as live;

typedef GraduateLoader = Future<live.ReadOnlyResponse> Function({
  required bool report,
  required bool forceRefresh,
});

class GraduatePage extends StatefulWidget {
  const GraduatePage({super.key, this.demo = false, this.loader, this.service});
  final bool demo;
  final GraduateLoader? loader;
  final CampusGateway? service;
  @override
  State<GraduatePage> createState() => _GraduatePageState();
}

class _AcademicPart {
  List<GraduateSection>? sections;
  String? error, notice;
  Future<void>? task;
  bool loading = false;
}

enum _GraduateView { credits, courses, profile }

class _GraduatePageState extends State<GraduatePage> {
  final status = _AcademicPart(), report = _AcademicPart();
  final search = TextEditingController();
  final scrollController = ScrollController();
  final viewOffsets = <_GraduateView, double>{};
  final expandedReportSections = <String>{};
  bool reportDataExpanded = false;
  _GraduateView view = _GraduateView.credits;
  GraduateCourseFilter courseFilter = GraduateCourseFilter.all;
  String category = '全部类别';
  List<String> categories = ['全部类别'];
  List<GraduateCourseEntry> courses = [], visibleCourses = [];
  bool get busy => status.loading || report.loading;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void filterCourses() {
    final query = search.text.trim().toLowerCase();
    visibleCourses = courses
        .where(
          (entry) =>
              (category == '全部类别' || entry.section == category) &&
              courseFilter.accepts(entry.row) &&
              '${entry.row.title} ${entry.row.detail}'.toLowerCase().contains(
                query,
              ),
        )
        .toList(growable: false);
  }

  void selectView(_GraduateView value, {bool fromTop = false}) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (scrollController.hasClients) {
      viewOffsets[view] = scrollController.offset;
    }
    if (fromTop) viewOffsets[value] = 0;
    setState(() => view = value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || view != value || !scrollController.hasClients) return;
      final position = scrollController.position;
      scrollController.jumpTo(
        (viewOffsets[value] ?? 0).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  Future<void> load({bool force = false}) => Future.wait([
    _loadPart(status, force: force),
    _loadPart(report, force: force),
  ]);

  Future<void> _loadPart(_AcademicPart part, {bool force = false}) =>
      part.task ??= _fetchPart(
        part,
        force: force,
      ).whenComplete(() => part.task = null);

  Future<void> _fetchPart(_AcademicPart part, {required bool force}) async {
    setState(() {
      part.loading = true;
      part.error = null;
    });
    try {
      final isReport = identical(part, report);
      final service = widget.service ?? mirrorServiceFor(demo: widget.demo);
      final result = widget.loader != null
          ? await widget.loader!(report: isReport, forceRefresh: force)
          : await service.graduatePart(report: isReport, forceRefresh: force);
      // Decode once on data change, never sort or parse inside build.
      final payload = result.payload == null
          ? null
          : jsonDecode(result.payload!) as Map<String, dynamic>;
      final sections = (payload?['sections'] as List?)
          ?.map(
            (section) =>
                GraduateSection.fromJson(section as Map<String, dynamic>),
          )
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        part.error = result.failure == null
            ? null
            : failureMessage(result.failure);
        if (sections != null) {
          part.sections = sections;
          part.notice = payload?['notice'] as String?;
          if (isReport) {
            courses = [
              for (final section in sections)
                for (final row in section.rows.where((row) => row.isCourse))
                  GraduateCourseEntry(section.title, row),
            ];
            categories = [
              '全部类别',
              ...courses.map((entry) => entry.section).toSet(),
            ];
            if (!categories.contains(category)) category = '全部类别';
            filterCourses();
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => part.error = failureMessage(null));
    } finally {
      if (mounted) setState(() => part.loading = false);
    }
  }

  Widget _partStatus(_AcademicPart part, String title) => AppleSection(
    header: Text(title),
    children: [
      AppleListTile(
        leading: part.loading
            ? const CupertinoActivityIndicator()
            : const Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: CupertinoColors.systemOrange,
              ),
        title: Text(
          part.loading
              ? (part.sections == null ? '正在加载…' : '正在更新…')
              : part.error!,
        ),
        subtitle: part.sections == null ? null : const Text('保留上次结果'),
        trailing: part.loading
            ? null
            : CupertinoButton(
                onPressed: () => _loadPart(part, force: true),
                child: const Text('重试'),
              ),
      ),
    ],
  );

  List<Widget> _partNotices(_AcademicPart part, String title) => [
    if (part.loading || part.error != null) _partStatus(part, title),
    if (part.notice != null)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Text(
          part.notice!,
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
            fontSize: 14,
          ),
        ),
      ),
  ];

  Widget _profileSection(GraduateSection section) => AppleSection(
    header: Text(section.title),
    children: [
      for (final row in section.rows)
        AcademicFactRow(label: row.title, value: row.detail),
    ],
  );

  void _openCategory(GraduateSection section) {
    setState(() {
      category = section.title;
      courseFilter = GraduateCourseFilter.all;
      search.clear();
      filterCourses();
    });
    selectView(_GraduateView.courses, fromTop: true);
  }

  List<Widget> _overview() {
    final sections = report.sections ?? <GraduateSection>[];
    if (sections.isEmpty) return [];
    final summary = sections.first;
    return [
      AppleSection(
        header: const Text('学分进度'),
        footer: const Text('仅统计学校已认定的方案学分，待考核学分单独列出。'),
        children: [
          if (summary.progress != null)
            GraduateCreditProgress(progress: summary.progress!),
          GraduateDisclosure(
            title: '报告原始数据',
            subtitle: summary.title,
            initiallyExpanded: reportDataExpanded,
            onExpanded: (value) => reportDataExpanded = value,
            children: [
              for (final row in summary.rows)
                AcademicFactRow(label: row.title, value: row.detail),
            ],
          ),
        ],
      ),
      if (sections.length > 1)
        AppleSection(
          header: const Text('类别与课组'),
          footer: const Text('各类可能包含同一课程，学分不可直接相加。展开查看学校要求和课程。'),
          children: [
            for (final section in sections.skip(1))
              GraduateCategoryRow(
                section: section,
                expanded: expandedReportSections.contains(section.title),
                onExpanded: (value) {
                  if (value) {
                    expandedReportSections.add(section.title);
                  } else {
                    expandedReportSections.remove(section.title);
                  }
                },
                onCourses: () => _openCategory(section),
              ),
          ],
        ),
    ];
  }

  Widget _course(GraduateCourseEntry entry) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.all(16),
        onPressed: () => Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => GraduateCourseDetails(entry: entry),
          ),
        ),
        child: DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      entry.row.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: CupertinoListTileChevron(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GraduateCourseBadges(row: entry.row),
              const SizedBox(height: 10),
              Text(
                [
                  entry.section,
                  if (entry.row.semester != null) entry.row.semester!,
                ].join(' · '),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _controls() => [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: CupertinoSearchTextField(
        key: const Key('graduate-search'),
        controller: search,
        placeholder: '搜索培养方案课程',
        onChanged: (_) => setState(filterCourses),
      ),
    ),
    AppleSection(
      children: [
        ApplePickerTile<String>(
          title: '课程类别',
          value: category,
          values: categories,
          label: (value) => value,
          onSelected: (value) => setState(() {
            category = value;
            filterCourses();
          }),
        ),
        ApplePickerTile<GraduateCourseFilter>(
          title: '完成状态',
          value: courseFilter,
          values: GraduateCourseFilter.values,
          label: (value) => value.label,
          onSelected: (value) => setState(() {
            courseFilter = value;
            filterCourses();
          }),
        ),
      ],
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Text(
        '${visibleCourses.length} 条课程记录',
        style: TextStyle(
          fontSize: 14,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    ),
    if (visibleCourses.isEmpty)
      AppleSection(
        children: [
          AppleEmptyState(
            title: courses.isEmpty ? '暂无课程记录' : '没有匹配的课程',
            description: courses.isEmpty
                ? '学校报告未提供可展示的课程。'
                : '调整类别、完成状态或搜索关键词。',
            action: courses.isEmpty ? null : '清除筛选',
            onAction: () => setState(() {
              search.clear();
              category = '全部类别';
              courseFilter = GraduateCourseFilter.all;
              filterCourses();
            }),
          ),
        ],
      ),
  ];

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('graduate-scroll'),
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        ApplePageHeader(
          largeTitle: const Text('研究生教务'),
          previousPageTitle: '工作台',
          border: null,
          trailing: AppleGlassButton(
            label: '刷新研究生教务',
            onPressed: busy ? null : () => load(force: true),
            child: busy
                ? const CupertinoActivityIndicator()
                : const Icon(CupertinoIcons.refresh),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
        SliverLayoutBuilder(
          builder: (context, constraints) => SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: ((constraints.crossAxisExtent - 900) / 2).clamp(
                0,
                double.infinity,
              ),
            ),
            sliver: SliverList.list(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: CupertinoSlidingSegmentedControl<_GraduateView>(
                          groupValue: view,
                          children: const {
                            _GraduateView.credits: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('学分地图'),
                            ),
                            _GraduateView.courses: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('课程'),
                            ),
                            _GraduateView.profile: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('学籍'),
                            ),
                          },
                          onValueChanged: (value) {
                            if (value != null) selectView(value);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                if (view != _GraduateView.profile)
                  ..._partNotices(report, '培养方案执行报告'),
                if (view == _GraduateView.profile) ...[
                  ..._partNotices(status, '学籍信息'),
                  for (final section in status.sections ?? <GraduateSection>[])
                    _profileSection(section),
                  if (status.sections?.isEmpty == true)
                    const AppleSection(
                      children: [
                        AppleEmptyState(
                          title: '暂无学籍信息',
                          description: '学校未返回可展示的学籍字段。',
                        ),
                      ],
                    ),
                ],
                if (view == _GraduateView.credits) ...[
                  if (status.sections
                          ?.expand((section) => section.rows)
                          .firstOrNull
                      case final row?)
                    AppleSection(
                      children: [
                        AppleListTile(
                          title: const Text('学籍信息'),
                          subtitle: Text(row.detail),
                          trailing: const CupertinoListTileChevron(),
                          onTap: () => selectView(_GraduateView.profile),
                        ),
                      ],
                    ),
                  ..._overview(),
                ],
                if (view == _GraduateView.courses && report.sections != null)
                  ..._controls(),
              ],
            ),
          ),
        ),
        if (view == _GraduateView.courses && report.sections != null)
          SliverLayoutBuilder(
            builder: (context, constraints) => SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: ((constraints.crossAxisExtent - 900) / 2).clamp(
                  0,
                  double.infinity,
                ),
              ),
              sliver: SliverList.builder(
                itemCount: visibleCourses.length,
                itemBuilder: (context, index) => _course(visibleCourses[index]),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    ),
  );
}
