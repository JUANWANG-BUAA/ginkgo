import 'package:flutter/cupertino.dart';

import 'academic_widgets.dart';
import 'apple_widgets.dart';
import 'graduate_models.dart';

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
          if (ratio != null) AcademicProgressBar(value: ratio),
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

class AcademicProgressBar extends StatelessWidget {
  const AcademicProgressBar({super.key, required this.value});
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

class GraduateCourseBadges extends StatelessWidget {
  const GraduateCourseBadges({super.key, required this.row});
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

class GraduateDisclosure extends StatefulWidget {
  const GraduateDisclosure({
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
  State<GraduateDisclosure> createState() => GraduateDisclosureState();
}

class GraduateDisclosureState extends State<GraduateDisclosure> {
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

class GraduateCategoryRow extends StatelessWidget {
  const GraduateCategoryRow({
    super.key,
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
    return GraduateDisclosure(
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
                  AcademicProgressBar(
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

class GraduateCourseDetails extends StatelessWidget {
  const GraduateCourseDetails({super.key, required this.entry});
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
                GraduateCourseBadges(row: entry.row),
              ],
            ),
          ),
          AppleSection(
            header: const Text('课程信息'),
            children: [
              AcademicFactRow(label: '培养类别', value: entry.section),
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
