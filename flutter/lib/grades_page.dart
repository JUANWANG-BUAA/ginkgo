import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'academic_widgets.dart';
import 'mirror_service.dart';
import 'application/contracts.dart';

class GradesPage extends StatefulWidget {
  const GradesPage({super.key, required this.service});
  final AcademicGateway service;
  @override
  State<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends State<GradesPage> {
  GradeResponse? data;
  String? error;
  String? notice;
  bool busy = false;
  int requestSerial = 0;
  List<ScheduleTerm> terms = const [];
  String? selectedTerm;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool force = false}) async {
    final serial = ++requestSerial;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      if (terms.isEmpty) {
        final termResult = await widget.service.gradeTerms();
        if (!mounted || serial != requestSerial) return;
        if (termResult.failure != null && termResult.terms.isEmpty) {
          setState(() {
            busy = false;
            error = failureMessage(termResult.failure);
          });
          return;
        }
        terms = termResult.terms;
        selectedTerm ??= terms
            .where((term) => term.selected)
            .map((term) => term.id)
            .firstOrNull;
        selectedTerm ??= terms.firstOrNull?.id;
      }
      final result = await widget.service.grades(
        termCode: selectedTerm,
        forceRefresh: force,
      );
      if (!mounted || serial != requestSerial) return;
      setState(() {
        busy = false;
        if (result.failure != null && result.fetchedAt == null) {
          error = failureMessage(result.failure);
          return;
        }
        data = result;
        selectedTerm = result.termId.isEmpty ? selectedTerm : result.termId;
        notice = result.failure == null
            ? null
            : '${failureMessage(result.failure)}，正在显示上次结果。';
      });
    } catch (_) {
      if (!mounted || serial != requestSerial) return;
      setState(() {
        busy = false;
        error = failureMessage(null);
      });
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('grades-scroll'),
      slivers: [
        ApplePageHeader(
          largeTitle: const Text('成绩'),
          border: null,
          trailing: AppleGlassButton(
            label: '刷新成绩',
            onPressed: busy ? null : () => load(force: true),
            child: busy
                ? const CupertinoActivityIndicator()
                : const Icon(CupertinoIcons.refresh, size: 24),
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
                if (notice != null)
                  AppleSection(
                    children: [
                      AppleListTile(
                        leading: const Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          color: CupertinoColors.systemOrange,
                          size: 20,
                        ),
                        title: Text(notice!),
                      ),
                    ],
                  ),
                if (error != null)
                  AppleSection(
                    children: [
                      AppleEmptyState(
                        title: error!,
                        description: data == null
                            ? '请检查网络后重试。'
                            : '正在保留${_termName(data!.termId)}的成绩。',
                        error: true,
                        action: '重试',
                        onAction: () => load(force: true),
                      ),
                    ],
                  )
                else if (data == null && busy)
                  AppleSection(
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CupertinoActivityIndicator(),
                            SizedBox(width: 10),
                            Expanded(child: Text('正在读取成绩…')),
                          ],
                        ),
                      ),
                    ],
                  ),
                if (data != null) ..._content(data!),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  List<Widget> _content(GradeResponse data) => [
    if (terms.length > 1)
      AppleSection(
        children: [
          ApplePickerTile<String>(
            title: '学期',
            value: selectedTerm ?? data.termId,
            values: terms.map((term) => term.id).toList(),
            label: (id) {
              final term = terms.where((term) => term.id == id).firstOrNull;
              return term?.name ?? id;
            },
            onSelected: (id) {
              if (id == selectedTerm) return;
              setState(() => selectedTerm = id);
              load(force: true);
            },
          ),
        ],
      ),
    AppleSection(
      header: Text(_termName(data.termId)),
      footer: const Text('加权平均与绩点只统计百分制、且有有效学分的课程；绩点按当前项目公式估算。'),
      children: [_summary(data.summary)],
    ),
    if (data.courses.isEmpty)
      AppleSection(
        children: const [
          AppleEmptyState(
            icon: CupertinoIcons.chart_bar,
            title: '本学期暂无成绩',
            description: '成绩尚未发布，或当前学期没有课程。',
          ),
        ],
      )
    else
      AppleSection(
        header: Text('${data.summary.courseCount} 门课程'),
        children: [
          for (final course in data.courses)
            _GradeCourseRow(
              key: Key('grade-course-${course.id}'),
              course: course,
              term: _termName(data.termId),
            ),
        ],
      ),
    Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Text(
        widget.service.isDemo
            ? '离线合成样例 · 成绩与学期均为演示数据'
            : '成绩保留学校原始记录，点击课程查看计分方式与详细信息。',
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    ),
  ];

  String _termName(String id) {
    final term = terms.where((term) => term.id == id).firstOrNull;
    return term?.name ?? id;
  }

  Widget _summary(GradeSummary summary) => Padding(
    padding: const EdgeInsets.all(18),
    child: AcademicMetricGrid(
      children: [
        AcademicMetric(
          label: '加权平均',
          value: summary.weightedAverage?.toStringAsFixed(1) ?? '—',
          prominent: true,
        ),
        AcademicMetric(
          label: '平均绩点',
          value: summary.gradePointAverage?.toStringAsFixed(2) ?? '—',
        ),
        AcademicMetric(label: '总学分', value: _credit(summary.creditTotal)),
      ],
    ),
  );
}

class _GradeCourseRow extends StatelessWidget {
  const _GradeCourseRow({super.key, required this.course, required this.term});
  final GradeCourse course;
  final String term;
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.all(16),
    onPressed: () => Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => _GradeCourseDetails(course: course, term: term),
      ),
    ),
    child: DefaultTextStyle(
      style: CupertinoTheme.of(context).textTheme.textStyle,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.4;
          final heading = Text(
            course.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          );
          final score = _ScoreBadge(course: course);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stacked) ...[
                heading,
                const SizedBox(height: 10),
                score,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.4,
                      ),
                      child: score,
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AcademicBadge(
                    course.credit == null
                        ? '学分未提供'
                        : '${_credit(course.credit!)} 学分',
                  ),
                  if (course.courseType?.isNotEmpty == true)
                    AcademicBadge(course.courseType!),
                ],
              ),
              if (course.code?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  course.code!,
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.course});
  final GradeCourse course;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        course.score,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.label.resolveFrom(context),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      const SizedBox(height: 3),
      Text(
        course.scoreType ?? '原始成绩',
        style: TextStyle(
          fontSize: 12,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    ],
  );
}

class _GradeCourseDetails extends StatelessWidget {
  const _GradeCourseDetails({required this.course, required this.term});
  final GradeCourse course;
  final String term;
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    navigationBar: const CupertinoNavigationBar(middle: Text('课程成绩')),
    child: SafeArea(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Text(
              course.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
          ),
          AppleSection(
            header: const Text('学校成绩记录'),
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _ScoreBadge(course: course),
                ),
              ),
              AcademicFactRow(
                label: '学分',
                value: course.credit == null
                    ? '学校未提供'
                    : _credit(course.credit!),
              ),
              AcademicFactRow(
                label: '课程类别',
                value: course.courseType ?? '学校未提供',
              ),
              AcademicFactRow(
                label: '计分方式',
                value: course.scoreType ?? '学校未提供',
              ),
              AcademicFactRow(label: '课程代码', value: course.code ?? '学校未提供'),
              AcademicFactRow(label: '学期', value: term),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

String _credit(double value) => academicNumber(value);
