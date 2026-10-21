import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'bykc_detail_page.dart';
import 'src/rust/api/live.dart' as live;

class BykcPage extends StatefulWidget {
  const BykcPage({super.key, this.demo = false});
  final bool demo;
  @override
  State<BykcPage> createState() => _BykcPageState();
}

class _BykcPageState extends State<BykcPage> {
  List<Map<String, dynamic>> courses = [], visible = [];
  List<String> categories = [];
  String category = '全部', query = '', termName = '';
  String? message;
  bool busy = false, loaded = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  void filter() {
    final text = query.trim().toLowerCase();
    visible = courses
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
      ? course['subcategory']
      : (course['category'] as String?)?.trim().isNotEmpty == true
      ? course['category']
      : '未分类';
  Future<void> load({bool force = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final result = widget.demo
          ? await live.loadDemoBykc()
          : await live.loadBykc(forceRefresh: force);
      if (!mounted) return;
      setState(() {
        busy = false;
        if (result.failure != null) {
          message =
              '${failureMessage(result.failure)}${loaded ? '，正在显示上次结果。' : ''}';
        }
        if (result.payload == null) return;
        final payload = jsonDecode(result.payload!) as Map<String, dynamic>;
        courses = (payload['courses'] as List).cast<Map<String, dynamic>>();
        final terms = (payload['terms'] as List).cast<Map<String, dynamic>>();
        final now = DateTime.now().toUtc().add(const Duration(hours: 8));
        terms.sort(
          (a, b) =>
              (b['end'] as String? ?? '').compareTo(a['end'] as String? ?? ''),
        );
        final active = terms.where((term) {
          final start = DateTime.tryParse(term['start'] as String? ?? '');
          final end = DateTime.tryParse(term['end'] as String? ?? '');
          return start != null &&
              end != null &&
              !now.isBefore(start) &&
              !now.isAfter(end);
        }).firstOrNull;
        termName =
            (active ?? terms.firstOrNull)?['name'] as String? ?? '学期课程目录';
        categories = [
          '全部',
          ...courses.map(categoryOf).toSet().toList()..sort(),
        ];
        if (!categories.contains(category)) category = '全部';
        loaded = true;
        filter();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          message = failureMessage(null);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('博雅'),
          previousPageTitle: '工作台',
          border: null,
          trailing: AppleGlassButton(
            label: '刷新博雅',
            onPressed: busy ? null : () => load(force: true),
            child: busy
                ? const CupertinoActivityIndicator()
                : const Icon(CupertinoIcons.refresh),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
        SliverList.list(
          children: [
            if (message != null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: message!,
                    description: loaded ? '保留上次课程目录。' : '请稍后重试。',
                    action: '重试',
                    onAction: () => load(force: true),
                    error: true,
                  ),
                ],
              ),
            if (!loaded && busy)
              const AppleSection(
                children: [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: CupertinoActivityIndicator(),
                  ),
                ],
              ),
            if (loaded) ...[
              AppleSection(
                header: Text(termName),
                footer: Text(
                  widget.demo ? '离线合成样例' : '学校当前学期课程目录；仅供查询，选课请前往学校系统。',
                ),
                children: [
                  ApplePickerTile<String>(
                    title: '类别',
                    value: category,
                    values: categories,
                    label: (v) => v,
                    onSelected: (v) => setState(() {
                      category = v;
                      filter();
                    }),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: CupertinoSearchTextField(
                  key: const Key('bykc-search'),
                  placeholder: '搜索课程、教师或地点',
                  onChanged: (value) => setState(() {
                    query = value;
                    filter();
                  }),
                ),
              ),
              AppleSection(
                header: Text('${visible.length} 门课程'),
                children: [
                  if (visible.isEmpty)
                    const AppleEmptyState(
                      title: '没有匹配的课程',
                      description: '可调整类别或搜索关键词。',
                    ),
                  for (final course in visible)
                    AppleListTile(
                      key: ValueKey('bykc-course-${course['id']}'),
                      title: Text(course['name'] as String),
                      subtitle: Text(
                        [
                          categoryOf(course),
                          course['teacher'],
                          course['position'],
                        ].whereType<String>().join(' · '),
                      ),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => BykcDetailPage(course: course),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ],
    ),
  );
}
