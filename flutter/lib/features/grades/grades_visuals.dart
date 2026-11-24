import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/academic_widgets.dart';

/// Apple Health–inspired Hero Score + 4-band vertical distribution column chart.
class GradesInstrumentCard extends StatelessWidget {
  const GradesInstrumentCard({
    super.key,
    required this.data,
    required this.demo,
  });

  final GradeResponse data;
  final bool demo;

  static const double _hairline = 0.75;
  static const double _chartHeight = 86.0;
  static const double _minBarHeight = 6.0;
  static const double _barWidth = 22.0;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final summary = data.summary;
    final avg = summary.weightedAverage;
    final gpa = summary.gradePointAverage;
    final avgText = avg?.toStringAsFixed(1) ?? '未提供';
    final gpaText = gpa?.toStringAsFixed(2) ?? '未提供';
    final creditText = academicNumber(summary.creditTotal);

    var tier90 = 0;
    var tier80 = 0;
    var tier70 = 0;
    var tierBelow = 0;
    for (final course in data.courses) {
      final score = double.tryParse(course.score.trim());
      if (score == null) continue;
      if (score >= 90) {
        tier90++;
      } else if (score >= 80) {
        tier80++;
      } else if (score >= 70) {
        tier70++;
      } else {
        tierBelow++;
      }
    }
    final scoredCount = tier90 + tier80 + tier70 + tierBelow;
    final maxBucket = math.max(
      1,
      math.max(math.max(tier90, tier80), math.max(tier70, tierBelow)),
    );

    final surface = CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);
    final border = CupertinoColors.separator
        .resolveFrom(context)
        .withValues(alpha: dark ? 0.45 : 0.35);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    final note = demo
        ? '离线合成样例 · 统计百分制或计分方式未标明的有效数字成绩'
        : '统计百分制或计分方式未标明的有效数字成绩 · 更新于 ${schoolTimestampLabel(data.fetchedAt)}';

    final heroMetrics = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              CupertinoIcons.chart_bar_alt_fill,
              size: GinkgoSpacing.pageInset,
              color: GinkgoColors.resourcePurple,
            ),
            const SizedBox(width: GinkgoSpacing.xs),
            Expanded(
              child: Text(
                '加权平均',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GinkgoTypography.caption.copyWith(
                  color: secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: GinkgoSpacing.xs),
            DecoratedBox(
              decoration: BoxDecoration(
                color: GinkgoColors.resourcePurple.withValues(
                  alpha: dark ? 0.22 : 0.12,
                ),
                borderRadius: BorderRadius.circular(GinkgoRadii.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: GinkgoSpacing.sm,
                  vertical: GinkgoSpacing.xs,
                ),
                child: Text(
                  '已发布 ${summary.courseCount} 门',
                  style: GinkgoTypography.caption2.copyWith(
                    color: GinkgoColors.resourcePurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: GinkgoSpacing.xs),
        Text(
          avgText,
          style: GinkgoTypography.largeTitle.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w700,
            fontFeatures: GinkgoTypography.tabularDigits,
          ),
        ),
        const SizedBox(height: GinkgoSpacing.sm),
        AcademicMetricGrid(
          children: [
            AcademicMetric(label: '平均绩点', value: gpaText, prominent: true),
            AcademicMetric(label: '总学分', value: creditText),
          ],
        ),
      ],
    );

    final chart = _ScoreDistributionChart(
      buckets: [
        _ScoreBucket('90+', tier90, const Color(0xFF059669), const Color(0xFF34D399)),
        _ScoreBucket('80-89', tier80, const Color(0xFF0B68F5), const Color(0xFF38BDF8)),
        _ScoreBucket('70-79', tier70, const Color(0xFF7C3AED), const Color(0xFFA78BFA)),
        _ScoreBucket('<70', tierBelow, const Color(0xFFD97706), const Color(0xFFF59E0B)),
      ],
      maxCount: maxBucket,
      dark: dark,
    );

    return Padding(
      key: const Key('grades-instrument-card'),
      padding: const EdgeInsets.fromLTRB(
        GinkgoSpacing.pageInset,
        GinkgoSpacing.md,
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
          padding: const EdgeInsets.all(GinkgoSpacing.pageInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heroMetrics,
              if (scoredCount > 0) ...[
                const SizedBox(height: GinkgoSpacing.md),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xFF1A1F29)
                        : const Color(0xFFF6F7FA),
                    borderRadius: BorderRadius.circular(GinkgoRadii.panel),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: GinkgoSpacing.md,
                      vertical: GinkgoSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '分数段分布',
                              style: GinkgoTypography.caption2.copyWith(
                                color: secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '90+ 占比 ${(tier90 * 100 / scoredCount).round()}%',
                              style: GinkgoTypography.caption2.copyWith(
                                color: AppleDesign.statusSuccess.resolveFrom(
                                  context,
                                ),
                                fontWeight: FontWeight.w600,
                                fontFeatures: GinkgoTypography.tabularDigits,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: GinkgoSpacing.sm),
                        SizedBox(height: _chartHeight, child: chart),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: GinkgoSpacing.sm),
              Text(
                note,
                style: GinkgoTypography.caption2.copyWith(color: secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreBucket {
  const _ScoreBucket(this.label, this.count, this.startColor, this.endColor);

  final String label;
  final int count;
  final Color startColor;
  final Color endColor;
}

class _ScoreDistributionChart extends StatelessWidget {
  const _ScoreDistributionChart({
    required this.buckets,
    required this.maxCount,
    required this.dark,
  });

  final List<_ScoreBucket> buckets;
  final int maxCount;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final emptyTrack = dark
        ? const Color(0xFF283040)
        : const Color(0xFFE2E6EE);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final bucket in buckets)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${bucket.count}',
                  style: GinkgoTypography.caption2.copyWith(
                    color: bucket.count > 0 ? labelColor : secondary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: GinkgoTypography.tabularDigits,
                  ),
                ),
                const SizedBox(height: GinkgoSpacing.xs),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final h = bucket.count == 0
                            ? GradesInstrumentCard._minBarHeight
                            : math.max(
                                GradesInstrumentCard._minBarHeight,
                                constraints.maxHeight *
                                    (bucket.count / maxCount),
                              );
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              GinkgoRadii.badge,
                            ),
                            color: bucket.count == 0 ? emptyTrack : null,
                            gradient: bucket.count == 0
                                ? null
                                : LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      bucket.startColor,
                                      bucket.endColor,
                                    ],
                                  ),
                          ),
                          child: SizedBox(
                            width: GradesInstrumentCard._barWidth,
                            height: h,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: GinkgoSpacing.xs),
                Text(
                  bucket.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GinkgoTypography.caption2.copyWith(color: secondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
