import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'mirror_service.dart';
import 'src/rust/api/mirror.dart';

class GradesPage extends StatefulWidget {
  const GradesPage({super.key, required this.service});
  final MirrorService service;
  @override
  State<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends State<GradesPage> {
  GradeResponse? data;
  String? error;
  String? notice;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool force = false}) async {
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final result = await widget.service.grades(forceRefresh: force);
      if (!mounted) return;
      setState(() {
        busy = false;
        if (result.failure != null && result.courses.isEmpty) {
          error = failureMessage(result.failure);
          return;
        }
        data = result;
        notice = result.failure == null
            ? null
            : '${failureMessage(result.failure)}，正在显示上次结果。';
      });
    } catch (_) {
      if (!mounted) return;
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
        CupertinoSliverNavigationBar(
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
        SliverList.list(
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
                    description: '请检查网络后重试。',
                    error: true,
                    action: '重试',
                    onAction: () => load(force: true),
                  ),
                ],
              )
            else if (busy || data == null)
              AppleSection(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CupertinoActivityIndicator(),
                        SizedBox(width: 10),
                        Text('正在读取成绩…'),
                      ],
                    ),
                  ),
                ],
              )
            else
              ..._content(data!),
          ],
        ),
      ],
    ),
  );

  List<Widget> _content(GradeResponse data) => [
    AppleSection(
      header: Text(data.termId),
      footer: const Text('加权平均与绩点只统计百分制、且有有效学分的课程；绩点按当前项目公式估算。'),
      children: [_summary(data.summary)],
    ),
    if (data.courses.isEmpty)
      AppleSection(
        children: const [
          AppleEmptyState(title: '本学期暂无成绩', description: '成绩尚未发布，或当前学期没有课程。'),
        ],
      )
    else
      AppleSection(
        header: Text('${data.summary.courseCount} 门课程'),
        children: [
          for (final course in data.courses)
            AppleListTile(
              key: Key('grade-course-${course.id}'),
              title: Text(course.name),
              subtitle: Text(
                [
                  if (course.code != null) course.code!,
                  if (course.credit != null) '${_credit(course.credit!)} 学分',
                  if (course.courseType != null) course.courseType!,
                ].join(' · '),
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              additionalInfo: _ScoreBadge(course: course),
            ),
        ],
      ),
    AppleSection(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            widget.service.isDemo
                ? '离线合成样例，不连接学校账号；成绩与学期用于演示迁移后的解析、汇总和页面状态。'
                : '真实账号只读数据；当前默认显示学校选中的学期。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ),
      ],
    ),
  ];

  Widget _summary(GradeSummary summary) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Row(
      children: [
        _metric(
          '加权平均',
          summary.weightedAverage == null
              ? '—'
              : summary.weightedAverage!.toStringAsFixed(1),
        ),
        _divider(context),
        _metric(
          '平均绩点',
          summary.gradePointAverage == null
              ? '—'
              : summary.gradePointAverage!.toStringAsFixed(2),
        ),
        _divider(context),
        _metric('总学分', _credit(summary.creditTotal)),
      ],
    ),
  );

  Widget _metric(String title, String value) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ],
    ),
  );

  Widget _divider(BuildContext context) => Container(
    width: 0.5,
    height: 36,
    color: CupertinoColors.separator.resolveFrom(context),
  );
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.course});
  final GradeCourse course;

  @override
  Widget build(BuildContext context) {
    final value = course.scoreValue;
    final color = value == null
        ? CupertinoColors.secondaryLabel.resolveFrom(context)
        : value >= 90
        ? const Color(0xFF189840)
        : value >= 80
        ? const Color(0xFF2F6FDB)
        : value >= 60
        ? const Color(0xFFB26A00)
        : const Color(0xFFC62828);
    return Container(
      constraints: const BoxConstraints(minWidth: 52),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        course.score,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

String _credit(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);
