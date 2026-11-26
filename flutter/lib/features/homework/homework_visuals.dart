import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

/// Compact interactive progress card for HomeworkPage built on [GinkgoCard].
///
/// Surfaces actionable counts (`待提交`, `已截止`, `已完成`) with a proportional
/// progress track; tapping any metric switches directly to that segment.
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
    this.selectedFilter = 0,
    this.onSelectFilter,
  });

  final int pending;
  final int submitted;
  final int overdue;
  final int unknown;
  final int overduePending;
  final String termCode;
  final bool demo;
  final int selectedFilter;
  final ValueChanged<int>? onSelectFilter;

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

    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final trackColor = CupertinoColors.tertiarySystemFill.resolveFrom(context);

    final doneColor = AppleDesign.statusSuccess.resolveFrom(context);
    final activeColor = AppleDesign.statusPending.resolveFrom(context);
    final urgentColor = GinkgoColors.statusDanger.resolveFrom(context);

    return GinkgoCard(
      key: const Key('homework-telemetry-card'),
      margin: const EdgeInsets.fromLTRB(
        GinkgoSpacing.pageInset,
        GinkgoSpacing.sm,
        GinkgoSpacing.pageInset,
        GinkgoSpacing.xs,
      ),
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
                  label: '待提交',
                  value: '$activePending',
                  valueColor: labelColor,
                  labelColor: secondary,
                  selected: selectedFilter == 0,
                  onTap: onSelectFilter == null
                      ? null
                      : () => onSelectFilter!(0),
                ),
              ),
              Expanded(
                child: _MetricChip(
                  dotColor: overduePending > 0 ? urgentColor : secondary,
                  label: '已截止',
                  value: '$overduePending',
                  valueColor: overduePending > 0 ? urgentColor : secondary,
                  labelColor: secondary,
                  selected: selectedFilter == 2,
                  onTap: onSelectFilter == null
                      ? null
                      : () => onSelectFilter!(2),
                ),
              ),
              Expanded(
                child: _MetricChip(
                  dotColor: doneColor,
                  label: '已完成',
                  value: '$submitted',
                  valueColor: labelColor,
                  labelColor: secondary,
                  selected: selectedFilter == 1,
                  onTap: onSelectFilter == null
                      ? null
                      : () => onSelectFilter!(1),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color:
                      (activePending == 0 && total > 0
                              ? doneColor
                              : activeColor)
                          .withValues(alpha: GinkgoBadgeTokens.fillAlpha(dark)),
                  borderRadius: BorderRadius.circular(GinkgoBadgeTokens.radius),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GinkgoSpacing.sm,
                    vertical: GinkgoSpacing.xs,
                  ),
                  child: Text(
                    total == 0 ? '无作业' : '$pct%',
                    style: GinkgoTypography.caption.copyWith(
                      color: activePending == 0 && total > 0
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
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
        ],
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
    this.selected = false,
    this.onTap,
  });

  final Color dotColor;
  final String label;
  final String value;
  final Color valueColor;
  final Color labelColor;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
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
                style: GinkgoTypography.caption2.copyWith(
                  color: selected ? dotColor : labelColor,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
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
    if (onTap == null) return content;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: GinkgoButtonTokens.minTarget,
      alignment: Alignment.centerLeft,
      onPressed: onTap,
      child: content,
    );
  }
}
