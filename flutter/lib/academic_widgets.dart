import 'package:flutter/cupertino.dart';

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
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
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
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final heading = Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        );
        final content = Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        );
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.4) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 5), content],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 124, child: heading),
            const SizedBox(width: 12),
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
          fontSize: 13,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: TextStyle(
          fontSize: prominent ? 32 : 24,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

class AcademicMetricGrid extends StatelessWidget {
  const AcademicMetricGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final columns = (constraints.maxWidth / (108 * scale)).floor().clamp(
        1,
        children.length,
      );
      return Wrap(
        spacing: 16,
        runSpacing: 18,
        children: [
          for (final child in children)
            SizedBox(
              width: (constraints.maxWidth - 16 * (columns - 1)) / columns,
              child: child,
            ),
        ],
      );
    },
  );
}
