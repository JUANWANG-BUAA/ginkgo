import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;

import 'academic_widgets.dart';
import 'apple_widgets.dart';
import 'graduate_models.dart';
import 'src/rust/api/live.dart' as live;

typedef GraduatePlanLoader = Future<live.ReadOnlyResponse> Function({
  required bool forceRefresh,
});

/// Full plan is fetched only after opening this route; report paint stays independent.
class GraduatePlanPage extends StatefulWidget {
  const GraduatePlanPage({super.key, this.demo = false, this.loader});
  final bool demo;
  final GraduatePlanLoader? loader;
  @override
  State<GraduatePlanPage> createState() => _GraduatePlanPageState();
}

class _GraduatePlanPageState extends State<GraduatePlanPage> {
  List<GraduateSection>? sections;
  List<int> courseCounts = [];
  String? error;
  Future<void>? task;
  bool busy = false;
  final expanded = <int>{};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool force = false}) =>
      task ??= fetch(force).whenComplete(() => task = null);

  Future<void> fetch(bool force) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await (widget.loader != null
          ? widget.loader!(forceRefresh: force)
          : widget.demo
          ? live.loadDemoGraduatePlan()
          : live.loadGraduatePlan(forceRefresh: force));
      final payload = result.payload == null
          ? null
          : jsonDecode(result.payload!) as Map<String, dynamic>;
      final parsed = (payload?['sections'] as List?)
          ?.map(
            (value) => GraduateSection.fromJson(value as Map<String, dynamic>),
          )
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        error = result.failure == null ? null : failureMessage(result.failure);
        if (parsed != null) {
          sections = parsed;
          courseCounts = [
            for (final section in parsed)
              section.rows.where((row) => row.isCourse).length,
          ];
          if (!result.stale) expanded.clear();
        }
      });
    } catch (_) {
      if (mounted) setState(() => error = failureMessage(null));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _course(GraduateRow row) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AcademicBadge('${academicNumber(row.credit)} 学分'),
            if (row.courseInfo.required case final value?) AcademicBadge(value),
            if (row.courseInfo.examMode case final value?) AcademicBadge(value),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          [
            row.courseInfo.code,
            row.courseInfo.category,
            row.semester,
          ].whereType<String>().join(' · '),
          style: TextStyle(
            fontSize: 14,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ],
    ),
  );

  Widget _section(int index) {
    final section = sections![index];
    final count = courseCounts[index];
    final isPool = index == sections!.length - 1 && index > 0;
    if (index == 0) {
      return AppleSection(
        header: Text(section.title),
        children: [
          for (final row in section.rows)
            Align(
              alignment: Alignment.centerLeft,
              child: AcademicFactRow(label: row.title, value: row.detail),
            ),
        ],
      );
    }
    return AppleSection(
      children: [
        AppleListTile(
          key: ValueKey('plan-section-$index'),
          leading: Icon(
            isPool ? CupertinoIcons.book : CupertinoIcons.doc_text,
            color: CupertinoColors.activeBlue.resolveFrom(context),
          ),
          title: Text(section.title),
          subtitle: isPool ? Text('$count 门课程') : null,
          trailing: Icon(
            expanded.contains(index)
                ? CupertinoIcons.chevron_up
                : CupertinoIcons.chevron_down,
            size: 15,
          ),
          onTap: () => setState(() {
            if (!expanded.add(index)) expanded.remove(index);
          }),
        ),
        if (expanded.contains(index))
          for (final row in section.rows)
            if (row.isCourse)
              _course(row)
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    row.detail,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                    contextMenuBuilder: (context, state) =>
                        CupertinoAdaptiveTextSelectionToolbar.editableText(
                          editableTextState: state,
                        ),
                  ),
                ),
              ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('graduate-plan-scroll'),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('培养方案'),
          previousPageTitle: '研究生教务',
          border: null,
          trailing: AppleGlassButton(
            label: '刷新培养方案',
            onPressed: busy ? null : () => load(force: true),
            child: busy
                ? const CupertinoActivityIndicator()
                : const Icon(CupertinoIcons.refresh),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
        if (busy || error != null)
          SliverToBoxAdapter(
            child: AppleSection(
              children: [
                AppleListTile(
                  leading: busy
                      ? const CupertinoActivityIndicator()
                      : const Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          color: CupertinoColors.systemOrange,
                        ),
                  title: Text(busy ? '正在读取培养方案…' : error!),
                  subtitle: sections == null ? null : const Text('保留上次结果'),
                  trailing: busy
                      ? null
                      : CupertinoButton(
                          onPressed: () => load(force: true),
                          child: const Text('重试'),
                        ),
                ),
              ],
            ),
          ),
        if (sections?.isEmpty == true)
          const SliverToBoxAdapter(
            child: AppleSection(
              children: [
                AppleEmptyState(title: '暂无培养方案', description: '学校未返回当前账号的方案。'),
              ],
            ),
          ),
        if (sections?.isNotEmpty == true)
          SliverLayoutBuilder(
            builder: (context, constraints) => SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: ((constraints.crossAxisExtent - 900) / 2).clamp(
                  0,
                  double.infinity,
                ),
              ),
              sliver: SliverList.builder(
                itemCount: sections!.length,
                itemBuilder: (context, index) => _section(index),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    ),
  );
}
