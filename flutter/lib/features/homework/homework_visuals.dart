import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';

/// Compact Things-3 / Linear–inspired urgency & completion ribbon for HomeworkPage.
///
/// Surfaces actionable counts (`进行中`, `逾期未交`, `已完成`) and a razor-thin
/// proportional progress track without pushing the homework list below the fold.
class HomeworkTelemetryCard extends StatelessWidget {
  const HomeworkTelemetryCard({
    super.key,
    required this.pending,
    required this.submitted,
    required this.overdue,
    required this.unknown,
    required this.overduePending,
    required this.termCode,
    required this.demo,
  });

  final int pending;
  final int submitted;
  final int overdue;
  final int unknown;
  final int overduePending;
  final String termCode;
  final bool demo;

  static const double _hairline = 0.75;
  static const double _barHeight = 6.0;
  static const double _dotSize = 7.0;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final total = pending + submitted + unknown;
    final activePending = (pending - overduePending).clamp(0, pending);
    final completionRatio = total == 0
        ? 0.0
        : (submitted / total).clamp(0.0, 1.0);
    final pct = (completionRatio * 100).round();

    final surface = CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);
    final border = CupertinoColors.separator
        .resolveFrom(context)
        .withValues(alpha: dark ? 0.45 : 0.35);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final trackColor = dark ? const Color(0xFF232936) : const Color(0xFFE9EDF3);

    final doneColor = AppleDesign.statusSuccess.resolveFrom(context);
    final activeColor = CupertinoTheme.of(context).primaryColor;
    final urgentColor = AppleDesign.statusPending.resolveFrom(context);

    final denom = total == 0 ? 1 : total;

    return Padding(
      key: const Key('homework-telemetry-card'),
      padding: const EdgeInsets.fromLTRB(
        GinkgoSpacing.pageInset,
        GinkgoSpacing.sm,
        GinkgoSpacing.pageInset,
        GinkgoSpacing.xs,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(GinkgoRadii.group),
          border: Border.all(color: border, width: _hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: GinkgoSpacing.pageInset,
            vertical: GinkgoSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricChip(
                      dotColor: activeColor,
                      label: '进行中',
                      value: '$activePending',
                      valueColor: labelColor,
                      labelColor: secondary,
                    ),
                  ),
                  Expanded(
                    child: _MetricChip(
                      dotColor: overduePending > 0 ? urgentColor : secondary,
                      label: '逾期未交',
                      value: '$overduePending',
                      valueColor: overduePending > 0 ? urgentColor : secondary,
                      labelColor: secondary,
                    ),
                  ),
                  Expanded(
                    child: _MetricChip(
                      dotColor: doneColor,
                      label: '已完成',
                      value: '$submitted',
                      valueColor: labelColor,
                      labelColor: secondary,
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: (pending == 0 && total > 0
                              ? doneColor
                              : activeColor)
                          .withValues(alpha: dark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(GinkgoRadii.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: GinkgoSpacing.sm,
                        vertical: GinkgoSpacing.xs,
                      ),
                      child: Text(
                        total == 0 ? '无作业' : '$pct%',
                        style: GinkgoTypography.caption.copyWith(
                          color: pending == 0 && total > 0
                              ? doneColor
                              : activeColor,
                          fontWeight: FontWeight.w700,
                          fontFeatures: GinkgoTypography.tabularDigits,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GinkgoSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(GinkgoRadii.pill),
                child: SizedBox(
                  height: _barHeight,
                  child: ColoredBox(
                    color: trackColor,
                    child: total == 0
                        ? const SizedBox.shrink()
                        : Row(
                            children: [
                              if (submitted > 0)
                                Expanded(
                                  flex: submitted,
                                  child: ColoredBox(color: doneColor),
                                ),
                              if (activePending > 0)
                                Expanded(
                                  flex: activePending,
                                  child: ColoredBox(color: activeColor),
                                ),
                              if (overduePending > 0)
                                Expanded(
                                  flex: overduePending,
                                  child: ColoredBox(color: urgentColor),
                                ),
                              if (unknown > 0)
                                Expanded(
                                  flex: unknown,
                                  child: ColoredBox(
                                    color: secondary.withValues(alpha: 0.45),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: GinkgoSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      termCode.isEmpty
                          ? (demo ? '离线合成样例' : 'SPOC 个人作业')
                          : '学期 $termCode · 共 $total 项',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GinkgoTypography.caption2.copyWith(
                        color: secondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: GinkgoSpacing.sm),
                  Flexible(
                    child: Text(
                      '已截止 $overdue 项 · 完成 ${(submitted * 100 / denom).round()}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GinkgoTypography.caption2.copyWith(
                        color: secondary,
                        fontFeatures: GinkgoTypography.tabularDigits,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.dotColor,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.labelColor,
  });

  final Color dotColor;
  final String label;
  final String value;
  final Color valueColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            child: const SizedBox(
              width: HomeworkTelemetryCard._dotSize,
              height: HomeworkTelemetryCard._dotSize,
            ),
          ),
          const SizedBox(width: GinkgoSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GinkgoTypography.caption2.copyWith(color: labelColor),
            ),
          ),
        ],
      ),
      const SizedBox(height: GinkgoSpacing.xs),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GinkgoTypography.headline.copyWith(
          color: valueColor,
          fontWeight: FontWeight.w700,
          fontFeatures: GinkgoTypography.tabularDigits,
        ),
      ),
    ],
  );
}
