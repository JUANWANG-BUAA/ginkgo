import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'bykc_detail_page.dart';
import 'school_timestamp.dart';
import 'src/rust/api/live.dart' as live;

enum BykcPart { catalog, chosen, statistics }

typedef BykcLoader = Future<live.ReadOnlyResponse> Function({
  required BykcPart part,
  required bool forceRefresh,
});

class BykcPage extends StatefulWidget {
  const BykcPage({super.key, this.demo = false, this.loader});
  final bool demo;
  final BykcLoader? loader;
  @override
  State<BykcPage> createState() => _BykcPageState();
}

class _BykcSnapshot {
  Map<String, dynamic>? data;
  String? error;
  bool loading = false, attempted = false;
  Future<void>? task;
}

class _BykcPageState extends State<BykcPage> {
  final parts = {for (final part in BykcPart.values) part: _BykcSnapshot()};
  final scrollController = ScrollController();
  final searchController = TextEditingController();
  BykcPart selection = BykcPart.catalog;
  List<Map<String, dynamic>> visible = [];
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
    return switch ((part, widget.demo)) {
      (BykcPart.catalog, true) => live.loadDemoBykc(),
      (BykcPart.chosen, true) => live.loadDemoBykcChosen(),
      (BykcPart.statistics, true) => live.loadDemoBykcStatistics(),
      (BykcPart.catalog, false) => live.loadBykc(forceRefresh: force),
      (BykcPart.chosen, false) => live.loadBykcChosen(forceRefresh: force),
      (BykcPart.statistics, false) => live.loadBykcStatistics(
        forceRefresh: force,
      ),
    };
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
      final data = result.payload == null
          ? null
          : jsonDecode(result.payload!) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        snapshot.error = result.failure == null
            ? null
            : failureMessage(result.failure);
        if (data != null) {
          snapshot.data = data;
          if (part == BykcPart.catalog) {
            // School timestamps have no timezone. Compare them as Beijing wall
            // time even when the device is outside China.
            final terms = _rows(data['terms']);
            DateTime? termDate(dynamic value) {
              if (value is! String) return null;
              final normalized =
                  (value.length > 19 ? value.substring(0, 19) : value)
                      .replaceFirst(' ', 'T');
              return DateTime.tryParse(
                '$normalized${normalized.length == 10 ? 'T00:00:00' : ''}+08:00',
              );
            }

            final now = DateTime.now();
            terms.sort(
              (a, b) => (termDate(b['end'])?.millisecondsSinceEpoch ?? 0)
                  .compareTo(termDate(a['end'])?.millisecondsSinceEpoch ?? 0),
            );
            final active = terms.where((term) {
              final start = termDate(term['start']),
                  end = termDate(term['end']);
              return start != null &&
                  end != null &&
                  !now.isBefore(start) &&
                  !now.isAfter(end);
            }).firstOrNull;
            termName =
                (active ?? terms.firstOrNull)?['name'] as String? ?? '学期课程目录';
            categories = [
              '全部',
              ..._rows(data['courses']).map(categoryOf).toSet().toList()
                ..sort(),
            ];
            if (!categories.contains(category)) category = '全部';
            filter();
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => snapshot.error = failureMessage(null));
    } finally {
      if (mounted) setState(() => snapshot.loading = false);
    }
  }

  List<Map<String, dynamic>> _rows(dynamic value) =>
      (value as List? ?? []).cast<Map<String, dynamic>>();

  void filter() {
    final text = query.trim().toLowerCase();
    visible = _rows(parts[BykcPart.catalog]!.data?['courses'])
        .where(
          (course) =>
              (category == '全部' || category == categoryOf(course)) &&
              [
                course['name'],
                course['teacher'],
                course['position'],
              ].any((v) => (v as String? ?? '').toLowerCase().contains(text)),
        )
        .toList();
  }

  String categoryOf(Map<String, dynamic> course) =>
      (course['subcategory'] as String?)?.trim().isNotEmpty == true
      ? course['subcategory'] as String
      : (course['category'] as String?)?.trim().isNotEmpty == true
      ? course['category'] as String
      : '未分类';

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

  void _open(Map<String, dynamic> course, {Map<String, dynamic>? record}) =>
      Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => BykcDetailPage(course: course, chosenRecord: record),
        ),
      );

  Widget _status() => AppleSection(
    children: [
      AppleListTile(
        leading: current.loading
            ? const CupertinoActivityIndicator()
            : const Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: CupertinoColors.systemOrange,
              ),
        title: Text(
          current.loading
              ? (current.data == null ? '正在读取${_label(selection)}…' : '正在更新…')
              : current.error!,
        ),
        subtitle: current.data == null ? null : const Text('保留上次结果'),
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
    List<Map<String, dynamic>> rows, {
    bool chosen = false,
  }) => SliverList.builder(
    itemCount: rows.length,
    addAutomaticKeepAlives: false,
    itemBuilder: (context, index) {
      final record = chosen ? rows[index] : null;
      final course = chosen
          ? record!['course'] as Map<String, dynamic>
          : rows[index];
      final details = course['details'] as Map<String, dynamic>? ?? {};
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
                        ? 'bykc-chosen-${record!['id']}'
                        : 'bykc-course-${course['id']}',
                  ),
                  leading: chosen
                      ? Icon(
                          record!['passed'] == 1
                              ? CupertinoIcons.checkmark_seal_fill
                              : CupertinoIcons.book,
                          color: record['passed'] == 1
                              ? CupertinoColors.systemGreen
                              : CupertinoColors.activeBlue,
                        )
                      : null,
                  title: Text(
                    course['name'] as String,
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
                            _BykcLabel(text: categoryOf(course)),
                            if (record == null && details['selected'] == true)
                              const _BykcLabel(text: '已选', positive: true),
                            if (record == null &&
                                (details['enrolled'] != null ||
                                    details['capacity'] != null))
                              _BykcLabel(
                                text:
                                    '人数 ${details['enrolled'] ?? '—'} / ${details['capacity'] ?? '未提供'}',
                              ),
                          ],
                        ),
                        if (details['start'] != null) ...[
                          const SizedBox(height: 9),
                          _BykcMetadata(
                            icon: CupertinoIcons.clock,
                            text: schoolTimestampLabel(
                              details['start'] as String,
                            ),
                            prominent: true,
                          ),
                        ],
                        if ((course['position'] as String?)
                                ?.trim()
                                .isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 5),
                          _BykcMetadata(
                            icon: CupertinoIcons.location,
                            text: course['position'] as String,
                          ),
                        ],
                        if ((course['teacher'] as String?)?.trim().isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 5),
                          _BykcMetadata(
                            icon: CupertinoIcons.person,
                            text: course['teacher'] as String,
                            auxiliary: true,
                          ),
                        ],
                        if (record != null) ...[
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _BykcLabel(
                                text: bykcAttendanceLabel(record),
                                positive: record['checkin'] == 1,
                              ),
                              _BykcLabel(
                                text: bykcResultLabel(record),
                                positive: record['passed'] == 1,
                              ),
                              if (record['score'] != null)
                                _BykcLabel(text: '成绩 ${record['score']}'),
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
    final data = current.data!;
    final term = data['term'] as Map<String, dynamic>?;
    final rows = _rows(data['courses']);
    return [
      SliverToBoxAdapter(
        child: _heading(
          term?['name'] as String? ?? '当前学期',
          detail: data['courses'] == null
              ? '上游未提供有效学期范围，暂不能查询已选记录。'
              : '已选 ${rows.length} 门 · 考勤和成绩以学校记录为准',
        ),
      ),
      if (data['courses'] != null && rows.isEmpty)
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
    final data = current.data!;
    final entries = _rows(data['entries']);
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final entry in entries) {
      (groups[entry['category'] as String] ??= []).add(entry);
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
                data['validCourseCount'] == null
                    ? '上游未提供'
                    : '${data['validCourseCount']} 门',
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
    child: CustomScrollView(
      key: const Key('bykc-scroll'),
      controller: scrollController,
      slivers: [
        ApplePageHeader(
          largeTitle: const Text('博雅'),
          previousPageTitle: '工作台',
          border: null,
          trailing: AppleGlassButton(
            label: '刷新博雅',
            onPressed: current.loading
                ? null
                : () => load(selection, force: true),
            child: current.loading
                ? const CupertinoActivityIndicator()
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
        if (current.data != null)
          ...switch (selection) {
            BykcPart.catalog => _catalog(),
            BykcPart.chosen => _chosen(),
            BykcPart.statistics => _statistics(),
          },
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    ),
  );
}

class BykcStatisticsCard extends StatelessWidget {
  const BykcStatisticsCard({super.key, required this.entry});
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final required = entry['required'] as int;
    final completed = entry['completed'] as int;
    final complete = required > 0 && completed >= required;
    final status = required == 0
        ? '本项暂无要求'
        : complete
        ? '已完成'
        : '还差 ${required - completed} 项';
    final color = complete
        ? CupertinoColors.systemGreen.resolveFrom(context)
        : CupertinoColors.activeBlue.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Semantics(
        label:
            '${entry['category']}，${entry['subcategory']}，已完成 $completed 项，应完成 $required 项，$status',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Text(
                    entry['subcategory'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$completed / $required',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: complete ? color : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              if (required > 0) ...[
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 3,
                    child: ColoredBox(
                      color: CupertinoColors.tertiarySystemFill.resolveFrom(
                        context,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: (completed / required).clamp(0.0, 1.0),
                          child: ColoredBox(color: color),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BykcLabel extends StatelessWidget {
  const _BykcLabel({required this.text, this.positive = false});
  final String text;
  final bool positive;
  @override
  Widget build(BuildContext context) {
    final color = positive
        ? CupertinoColors.systemGreen.resolveFrom(context)
        : CupertinoColors.secondaryLabel.resolveFrom(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: positive ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _BykcMetadata extends StatelessWidget {
  const _BykcMetadata({
    required this.icon,
    required this.text,
    this.prominent = false,
    this.auxiliary = false,
  });
  final IconData icon;
  final String text;
  final bool prominent, auxiliary;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(
          icon,
          size: 14,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: auxiliary ? 12 : 14,
            fontWeight: prominent ? FontWeight.w500 : FontWeight.w400,
            color: prominent
                ? CupertinoColors.label.resolveFrom(context)
                : CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ),
    ],
  );
}
