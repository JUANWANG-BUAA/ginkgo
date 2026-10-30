import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';

import 'package:ginkgo_mirror/application/bykc.dart';

/// A compact tag used for course categories, enrollment and results.
class BykcLabel extends StatelessWidget {
  const BykcLabel({
    super.key,
    required this.text,
    this.positive = false,
    this.tint,
  });
  final String text;
  final bool positive;
  final Color? tint;
  @override
  Widget build(BuildContext context) {
    final color =
        tint ??
        (positive
            ? CupertinoColors.systemGreen.resolveFrom(context)
            : CupertinoColors.secondaryLabel.resolveFrom(context));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: (positive || tint != null)
              ? FontWeight.w600
              : FontWeight.w500,
        ),
      ),
    );
  }
}

/// One metadata line of a course card, such as its time or its classroom.
class BykcMetadata extends StatelessWidget {
  const BykcMetadata({
    super.key,
    required this.icon,
    required this.text,
    this.prominent = false,
    this.auxiliary = false,
  });
  final IconData icon;
  final String text;
  final bool prominent, auxiliary;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(
          icon,
          size: 14,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: auxiliary ? 12 : 14,
            fontWeight: prominent ? FontWeight.w500 : FontWeight.w400,
            color: prominent
                ? CupertinoColors.label.resolveFrom(context)
                : CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ),
    ],
  );
}

/// The heading of one BYKC section, with an optional explanatory line.
class BykcSectionHeading extends StatelessWidget {
  const BykcSectionHeading({super.key, required this.title, this.detail});
  final String title;
  final String? detail;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        if (detail != null) ...[
          const SizedBox(height: 5),
          Text(
            detail!,
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ],
    ),
  );
}

/// One row of a rounded BYKC card group. The group keeps a continuous
/// surface and separates its rows with a hairline.
class BykcCardRow extends StatelessWidget {
  const BykcCardRow({
    super.key,
    required this.child,
    this.first = false,
    this.last = false,
  });

  /// The row content, drawn on the shared card surface.
  final Widget child;

  /// Whether this row opens the group, so its top corners are rounded.
  final bool first;

  /// Whether this row closes the group, so its bottom corners are rounded
  /// and no separator follows it.
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: ClipRSuperellipse(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(first ? 20 : 0),
        bottom: Radius.circular(last ? 20 : 0),
      ),
      child: ColoredBox(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        child: Column(
          children: [
            child,
            if (!last)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 0.5,
                  color: CupertinoColors.separator
                      .resolveFrom(context)
                      .withValues(alpha: 0.2),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Progress of one required category reported by the school.
class BykcStatisticsCard extends StatelessWidget {
  const BykcStatisticsCard({super.key, required this.entry});
  final BykcStatisticsEntry entry;
  @override
  Widget build(BuildContext context) {
    final required = entry.requiredCount;
    final completed = entry.completed;
    final complete = entry.complete;
    final status = required == 0
        ? '本项暂无要求'
        : complete
        ? '已完成'
        : '还差 ${required - completed} 项';
    final color = complete
        ? CupertinoColors.systemGreen.resolveFrom(context)
        : CupertinoColors.activeBlue.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Semantics(
        label:
            '${entry.category}，${entry.subcategory}，已完成 $completed 项，应完成 $required 项，$status',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Text(
                    entry.subcategory,
                    style: const TextStyle(
                      fontSize: AppleDesign.bodyCondensedSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$completed / $required',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: complete ? color : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              if (required > 0) ...[
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 3,
                    child: ColoredBox(
                      color: CupertinoColors.tertiarySystemFill.resolveFrom(
                        context,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: (completed / required).clamp(0.0, 1.0),
                          child: ColoredBox(color: color),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
