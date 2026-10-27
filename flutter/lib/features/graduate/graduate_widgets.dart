import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/academic_widgets.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'graduate_models.dart';

/// Credit values the school did not provide stay "未确认"; they never read as
/// a confirmed zero.
String graduateCreditLabel(num? value) =>
    value == null ? '未确认' : academicNumber(value);

/// One labeled statistic in a quiet row. A value may keep its own weight and
/// color so a pending amount never reads like a confirmed one.
class GraduateStat {
  const GraduateStat(this.label, this.value, {this.weight, this.color});

  final String label, value;
  final FontWeight? weight;
  final Color? color;
}

/// A wrapping row of labeled statistics.
class GraduateStatRow extends StatelessWidget {
  const GraduateStatRow(
    this.stats, {
    super.key,
    this.spacing = 12,
    this.runSpacing = 5,
  });

  final List<GraduateStat> stats;
  final double spacing, runSpacing;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: spacing,
    runSpacing: runSpacing,
    children: [
      for (final stat in stats)
        Text(
          '${stat.label} ${stat.value}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: stat.weight,
            color: stat.color,
          ),
        ),
    ],
  );
}

/// Credit ratio bar: the recognized portion over an optional pending portion,
/// on a quiet track. Shared by the execution report and the credit map.
class GraduateCreditBar extends StatelessWidget {
  const GraduateCreditBar({
    super.key,
    required this.value,
    this.pendingValue = 0,
    this.valueColor,
    this.pendingColor,
    this.height = 5,
    this.borderRadius = 3,
    this.semanticLabel,
  });

  /// Recognized share of the requirement, 0 to 1.
  final double value;

  /// Pending share of the requirement, drawn behind the recognized portion.
  final double pendingValue;
  final Color? valueColor, pendingColor;
  final double height, borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              ),
            ),
            FractionallySizedBox(
              widthFactor: (value + pendingValue).clamp(0.0, 1.0),
              child: ColoredBox(
                color:
                    pendingColor ??
                    AppleDesign.statusPending
                        .resolveFrom(context)
                        .withValues(alpha: 0.65),
                child: SizedBox(height: height),
              ),
            ),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: ColoredBox(
                color:
                    valueColor ??
                    CupertinoColors.systemGreen.resolveFrom(context),
                child: SizedBox(height: height),
              ),
            ),
          ],
        ),
      ),
    );
    if (semanticLabel == null) return bar;
    return Semantics(
      label: semanticLabel,
      value: '${(value * 100).round()}%',
      child: bar,
    );
  }
}

/// Numeric fields are projected by Rust; pending credits never reduce the gap.
class GraduateCreditProgress extends StatelessWidget {
  const GraduateCreditProgress({super.key, required this.progress});
  final GraduateProgress progress;
  @override
  Widget build(BuildContext context) {
    final required = progress.requiredCredits;
    final earned = progress.earned;
    final pending = progress.pending;
    final ratio = progress.earnedRatio;
    final remaining = progress.remaining;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AcademicMetricGrid(
            children: [
              AcademicMetric(
                label: '方案已认定',
                value: graduateCreditLabel(earned),
                prominent: true,
              ),
              AcademicMetric(
                label: '要求学分',
                value: graduateCreditLabel(required),
              ),
              AcademicMetric(
                label: '待考核',
                value: graduateCreditLabel(pending),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (ratio != null)
            GraduateCreditBar(
              value: ratio,
              pendingValue: progress.pendingRatio,
              semanticLabel: '已认定学分占要求的比例',
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              AcademicBadge('尚需 ${graduateCreditLabel(remaining)}'),
              if (required == 0)
                const AcademicBadge('本项无最低学分要求')
              else if (required == null || earned == null)
                const AcademicBadge(
                  '学分信息不完整',
                  icon: CupertinoIcons.question_circle,
                ),
              if (pending != null && pending > 0)
                AcademicBadge(
                  '待考核 ${graduateCreditLabel(pending)}',
                  tint: AppleDesign.statusPending,
                  icon: CupertinoIcons.clock,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A collapsible block. The page owns the expanded state so a reload can
/// restore it.
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
  State<GraduateDisclosure> createState() => _GraduateDisclosureState();
}

class _GraduateDisclosureState extends State<GraduateDisclosure> {
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

/// One category of the execution report: its credit position and the way into
/// the courses it contains.
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
    final required = progress?.requiredCredits;
    final earned = progress?.earned;
    final remaining = progress?.remaining;
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
                if (progress.earnedRatio case final ratio?) ...[
                  GraduateCreditBar(
                    value: ratio,
                    pendingValue: progress.pendingRatio,
                  ),
                  const SizedBox(height: 8),
                ],
                GraduateStatRow([
                  GraduateStat('尚需', graduateCreditLabel(remaining)),
                  GraduateStat(
                    '待考核',
                    academicNumber(progress.pending),
                    weight: FontWeight.w500,
                    color: (progress.pending ?? 0) > 0
                        ? AppleDesign.statusPending.resolveFrom(context)
                        : AppleDesign.statusInactive.resolveFrom(context),
                  ),
                ]),
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
