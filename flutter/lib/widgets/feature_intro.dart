import 'package:flutter/cupertino.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';

/// A compact feature identity with a clear task, separate from live status.
class FeatureIntro extends StatelessWidget {
  const FeatureIntro({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.color,
    this.prominent = false,
  });
  final IconData icon;
  final String title, description;
  final bool prominent;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: GinkgoSpacing.edgeInsetsCard,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GinkgoIconTile(icon: icon, size: 48, color: color),
        const SizedBox(width: GinkgoSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GinkgoTypography.headline.copyWith(
                  fontSize: prominent ? GinkgoTypography.focusTitleSize : null,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
              const SizedBox(height: GinkgoSpacing.xs),
              Text(
                description,
                style: GinkgoTypography.footnote.copyWith(
                  height: 1.4,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Section heading with an explicit semantic icon; no inferred business state.
class FeatureSectionTitle extends StatelessWidget {
  const FeatureSectionTitle(
    this.title, {
    super.key,
    required this.icon,
    this.color,
  });
  final String title;
  final IconData icon;
  final Color? color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: 18,
        color: CupertinoDynamicColor.resolve(
          color ?? CupertinoTheme.of(context).primaryColor,
          context,
        ),
      ),
      const SizedBox(width: GinkgoSpacing.sm),
      Expanded(child: Text(title)),
    ],
  );
}
