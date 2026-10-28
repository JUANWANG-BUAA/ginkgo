import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';

String academicNumber(num? value) => value == null
    ? '未提供'
    : value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

/// Quiet semantic labels that wrap with text size; color never carries status
/// alone and a course score is never inferred from its display string.
class AcademicBadge extends StatelessWidget {
  const AcademicBadge(this.label, {super.key, this.tint, this.icon});
  final String label;
  final CupertinoDynamicColor? tint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = (tint ?? CupertinoColors.secondaryLabel).resolveFrom(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(GinkgoRadii.badge),
      ),
      child: Padding(
        padding: GinkgoSpacing.edgeInsetsBadge,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: GinkgoSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: GinkgoTypography.footnote.fontSize,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Readable label/value alignment, stacking before large text gets squeezed.
class AcademicFactRow extends StatelessWidget {
  const AcademicFactRow({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: GinkgoSpacing.edgeInsetsFact,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final heading = Text(
          label,
          style: TextStyle(
            fontSize: GinkgoTypography.subheadline.fontSize,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        );
        final content = Text(
          value,
          style: const TextStyle(
            fontSize: AppleDesign.bodyCondensedSize,
            fontWeight: FontWeight.w500,
          ),
        );
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.4) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: GinkgoSpacing.compact),
              content,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: GinkgoSpacing.factLabelWidth, child: heading),
            const SizedBox(width: GinkgoSpacing.md),
            Expanded(child: content),
          ],
        );
      },
    ),
  );
}

class AcademicMetric extends StatelessWidget {
  const AcademicMetric({
    super.key,
    required this.label,
    required this.value,
    this.prominent = false,
  });
  final String label, value;
  final bool prominent;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: GinkgoTypography.footnote.fontSize,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
      const SizedBox(height: GinkgoSpacing.small),
      Text(
        value,
        style: TextStyle(
          fontSize: prominent
              ? GinkgoTypography.metricProminentSize
              : GinkgoTypography.metricSize,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

class AcademicMetricGrid extends StatelessWidget {
  const AcademicMetricGrid({
    super.key,
    required this.children,
    this.maxColumns,
  });
  final List<Widget> children;
  final int? maxColumns;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final columns =
          (constraints.maxWidth / (GinkgoSpacing.metricColumnWidth * scale))
              .floor()
              .clamp(
                1,
                maxColumns == null
                    ? children.length
                    : maxColumns!.clamp(1, children.length),
              );
      final gapCount = columns - 1;
      return Wrap(
        spacing: GinkgoSpacing.base,
        runSpacing: GinkgoSpacing.metricGridSpacing,
        children: [
          for (final child in children)
            SizedBox(
              width:
                  (constraints.maxWidth - GinkgoSpacing.base * gapCount) /
                  columns,
              child: child,
            ),
        ],
      );
    },
  );
}
