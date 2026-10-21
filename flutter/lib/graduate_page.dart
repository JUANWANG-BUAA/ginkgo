import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'academic_widgets.dart';
import 'graduate_models.dart';
import 'src/rust/api/live.dart' as live;

typedef GraduateLoader = Future<live.ReadOnlyResponse> Function({
  required bool report,
  required bool forceRefresh,
});

class GraduatePage extends StatefulWidget {
  const GraduatePage({super.key, this.demo = false, this.loader});
  final bool demo;
  final GraduateLoader? loader;
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
              '${entry.row.title} ${entry.row.detail} ${entry.row.courseInfo.code ?? ''}'
                  .toLowerCase()
                  .contains(query),
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
      final result = widget.loader != null
          ? await widget.loader!(report: isReport, forceRefresh: force)
          : widget.demo
          ? (isReport
                ? await live.loadDemoGraduate()
                : await live.loadDemoGraduateStatus())
          : await live.loadGraduatePart(report: isReport, forceRefresh: force);
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
          _GraduateDisclosure(
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
              _GraduateCategoryRow(
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
            builder: (_) => _GraduateCourseDetails(entry: entry),
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
              _GraduateCourseBadges(row: entry.row),
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
        CupertinoSliverNavigationBar(
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

/// Numeric fields are projected by Rust; pending credits never reduce the gap.
class GraduateCreditProgress extends StatelessWidget {
  const GraduateCreditProgress({super.key, required this.progress});
  final Map<String, dynamic> progress;
  String _format(num? value) => value == null ? '未确认' : academicNumber(value);
  @override
  Widget build(BuildContext context) {
    final required = progress['required'] as num?;
    final earned = progress['earned'] as num?;
    final pending = progress['pending'] as num?;
    final ratio = required != null && required > 0 && earned != null
        ? (earned / required).clamp(0.0, 1.0)
        : null;
    final remaining = required == null || earned == null
        ? null
        : (required - earned).clamp(0, double.infinity);
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AcademicMetricGrid(
            children: [
              AcademicMetric(
                label: '方案已认定',
                value: _format(earned),
                prominent: true,
              ),
              AcademicMetric(label: '要求学分', value: _format(required)),
              AcademicMetric(label: '待考核', value: _format(pending)),
            ],
          ),
          const SizedBox(height: 18),
          if (ratio != null) _AcademicProgressBar(value: ratio),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              AcademicBadge('尚需 ${_format(remaining)}'),
              if (required == 0)
                const AcademicBadge('本项无最低学分要求')
              else if (required == null || earned == null)
                const AcademicBadge(
                  '学分信息不完整',
                  icon: CupertinoIcons.question_circle,
                ),
              if (pending != null && pending > 0)
                AcademicBadge(
                  '待考核 ${_format(pending)}',
                  tint: CupertinoColors.systemOrange,
                  icon: CupertinoIcons.clock,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AcademicProgressBar extends StatelessWidget {
  const _AcademicProgressBar({required this.value});
  final double value;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '已认定学分占要求的比例',
    value: '${(value * 100).round()}%',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        width: double.infinity,
        height: 5,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              ),
            ),
            FractionallySizedBox(
              widthFactor: value,
              child: ColoredBox(
                color: CupertinoColors.systemGreen.resolveFrom(context),
                child: const SizedBox(height: 5),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GraduateCourseBadges extends StatelessWidget {
  const _GraduateCourseBadges({required this.row});
  final GraduateRow row;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      AcademicBadge(
        row.credit == null ? '学分未提供' : '${academicNumber(row.credit)} 学分',
      ),
      AcademicBadge(
        row.completionLabel,
        tint: row.completed == true
            ? CupertinoColors.systemGreen
            : row.completed == false
            ? CupertinoColors.secondaryLabel
            : CupertinoColors.systemOrange,
        icon: row.completed == true
            ? CupertinoIcons.checkmark_circle_fill
            : row.completed == false
            ? CupertinoIcons.circle
            : CupertinoIcons.question_circle,
      ),
    ],
  );
}

class _GraduateDisclosure extends StatefulWidget {
  const _GraduateDisclosure({
    super.key,
    required this.title,
    this.subtitle,
    this.summary,
    this.initiallyExpanded = false,
    this.onExpanded,
    required this.children,
  });
  final String title;
  final String? subtitle;
  final Widget? summary;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpanded;
  final List<Widget> children;
  @override
  State<_GraduateDisclosure> createState() => _GraduateDisclosureState();
}

class _GraduateDisclosureState extends State<_GraduateDisclosure> {
  late bool expanded = widget.initiallyExpanded;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppleListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 5),
              Text(
                widget.subtitle!,
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
            if (widget.summary != null) ...[
              const SizedBox(height: 10),
              widget.summary!,
            ],
          ],
        ),
        trailing: Icon(
          expanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
          size: 14,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
        onTap: () {
          setState(() => expanded = !expanded);
          widget.onExpanded?.call(expanded);
        },
      ),
      if (expanded) ...widget.children,
    ],
  );
}

class _GraduateCategoryRow extends StatelessWidget {
  const _GraduateCategoryRow({
    required this.section,
    required this.onCourses,
    required this.expanded,
    required this.onExpanded,
  });
  final GraduateSection section;
  final VoidCallback onCourses;
  final bool expanded;
  final ValueChanged<bool> onExpanded;
  @override
  Widget build(BuildContext context) {
    final progress = section.progress;
    final required = progress?['required'] as num?;
    final earned = progress?['earned'] as num?;
    final remaining = required == null || earned == null
        ? null
        : (required - earned).clamp(0, double.infinity);
    final count = section.rows.where((row) => row.isCourse).length;
    return _GraduateDisclosure(
      key: ValueKey(section.title),
      initiallyExpanded: expanded,
      onExpanded: onExpanded,
      title: section.title,
      subtitle: progress == null
          ? '$count 条课程记录'
          : '已认定 ${academicNumber(earned)} / 要求 ${academicNumber(required)} 学分',
      summary: progress == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (required != null && required > 0 && earned != null) ...[
                  _AcademicProgressBar(
                    value: (earned / required).clamp(0.0, 1.0),
                  ),
                  const SizedBox(height: 8),
                ],
                Wrap(
                  spacing: 12,
                  runSpacing: 5,
                  children: [
                    Text(
                      '尚需 ${remaining == null ? '未确认' : academicNumber(remaining)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      '待考核 ${academicNumber(progress['pending'] as num?)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
      children: [
        for (final row in section.rows.where((row) => !row.isCourse))
          AcademicFactRow(label: row.title, value: row.detail),
        if (count > 0)
          AppleListTile(
            title: Text(
              '查看本类课程',
              style: TextStyle(color: CupertinoTheme.of(context).primaryColor),
            ),
            additionalInfo: Text('$count 条'),
            trailing: const CupertinoListTileChevron(),
            onTap: onCourses,
          ),
      ],
    );
  }
}

class _GraduateCourseDetails extends StatelessWidget {
  const _GraduateCourseDetails({required this.entry});
  final GraduateCourseEntry entry;
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    navigationBar: const CupertinoNavigationBar(middle: Text('培养方案课程')),
    child: SafeArea(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.row.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                _GraduateCourseBadges(row: entry.row),
              ],
            ),
          ),
          AppleSection(
            header: const Text('课程信息'),
            children: [
              AcademicFactRow(label: '培养类别', value: entry.section),
              if (entry.row.courseInfo.code case final code?)
                AcademicFactRow(label: '课程代码', value: code),
              if (entry.row.courseInfo.grade case final grade?)
                AcademicFactRow(label: '学校成绩', value: grade),
              if (entry.row.courseInfo.category case final category?)
                AcademicFactRow(label: '课程类别', value: category),
              if (entry.row.courseInfo.attribute case final attribute?)
                AcademicFactRow(label: '课程属性', value: attribute),
              if (entry.row.courseInfo.examMode case final examMode?)
                AcademicFactRow(label: '考核方式', value: examMode),
              if (entry.row.courseInfo.required case final required?)
                AcademicFactRow(label: '必修标记', value: required),
              AcademicFactRow(
                label: '学期',
                value: entry.row.semester ?? '学校未提供',
              ),
            ],
          ),
          AppleSection(
            header: const Text('学校执行报告'),
            footer: const Text('完成状态以学校执行报告为准，课程池中的课程不代表全部必修。'),
            children: [AcademicFactRow(label: '原始记录', value: entry.row.detail)],
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}
