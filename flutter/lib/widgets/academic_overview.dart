import 'package:flutter/cupertino.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/academic_widgets.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';

/// A single focal value plus supporting facts. Unknown values stay explicit.
class AcademicOverview extends StatelessWidget {
  const AcademicOverview({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.facts,
    this.note,
    this.color,
  });
  final String title, value;
  final IconData icon;
  final List<({String label, String value})> facts;
  final String? note;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = CupertinoDynamicColor.resolve(
      color ?? GinkgoColors.resourceBlue,
      context,
    );
    return Padding(
      padding: GinkgoSpacing.edgeInsetsCard,
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(GinkgoRadii.group),
        child: ColoredBox(
          color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
            context,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: tint.withValues(alpha: 0.08),
                padding: GinkgoSpacing.edgeInsetsCard,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GinkgoTypography.footnote.copyWith(
                              color: CupertinoColors.secondaryLabel.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                          const SizedBox(height: GinkgoSpacing.sm),
                          Text(
                            value,
                            style: GinkgoTypography.largeTitle.copyWith(
                              color: tint,
                              fontFeatures: GinkgoTypography.tabularDigits,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: GinkgoSpacing.md),
                    GinkgoIconTile(icon: icon, color: tint),
                  ],
                ),
              ),
              Padding(
                padding: GinkgoSpacing.edgeInsetsCard,
                child: AcademicMetricGrid(
                  maxColumns: 3,
                  children: [
                    for (final fact in facts)
                      AcademicMetric(label: fact.label, value: fact.value),
                  ],
                ),
              ),
              if (note != null)
                Padding(
                  padding: GinkgoSpacing.edgeInsetsCard,
                  child: Text(
                    note!,
                    style: GinkgoTypography.footnote.copyWith(
                      height: 1.4,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
