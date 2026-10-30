import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/status_chip.dart';

/// One label/value pair. The value answers the page's question; the label
/// says what the value is about.
class SummaryItem {
  const SummaryItem(
    this.label,
    this.value, {
    this.icon,
    this.tone,
    this.key,
  });

  /// A missing value is written as such. It is never rendered as zero.
  const SummaryItem.unknown(this.label)
    : value = null,
      icon = null,
      tone = StatusTone.uncertain,
      key = null;

  /// The source did not confirm the state. This is not the same as zero.
  const SummaryItem.unconfirmed(this.label)
    : value = '未确认',
      icon = null,
      tone = StatusTone.uncertain,
      key = null;

  final String label;
  final String? value;
  final IconData? icon;
  final StatusTone? tone;

  /// An optional identity for the row, used by tests and by pages that
  /// address one specific number.
  final Key? key;
}

/// A quiet summary surface: label on the left, value aligned right.
///
/// This is the page-level counterpart of a `LabeledContent` row. One page
/// carries exactly one strip; it answers "what is the state of this area"
/// before the list is read.
class SummaryStrip extends StatelessWidget {
  const SummaryStrip({super.key, required this.items, this.note});

  final List<SummaryItem> items;

  /// One line of scope or timing. It never becomes a paragraph.
  final String? note;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: AppleDesign.desktop(context) ? 20 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppleDesign.pageInset),
            child: ClipRSuperellipse(
              borderRadius: BorderRadius.circular(AppleDesign.panelRadius(context)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: CupertinoColors.secondarySystemGroupedBackground
                      .resolveFrom(context),
                  borderRadius: BorderRadius.circular(
                    AppleDesign.panelRadius(context),
                  ),
                  border: AppleDesign.desktop(context)
                      ? Border.all(
                          color: CupertinoColors.separator
                              .resolveFrom(context)
                              .withValues(alpha: 0.3),
                          width: 0.5,
                        )
                      : null,
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      _SummaryRow(
                        key: items[index].key,
                        item: items[index],
                      ),
                      if (index != items.length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: GinkgoSpacing.base,
                          ),
                          child: Container(
                            height: 0.5,
                            color: CupertinoColors.separator
                                .resolveFrom(context)
                                .withValues(alpha: 0.16),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                GinkgoSpacing.base,
                GinkgoSpacing.xs,
                GinkgoSpacing.base,
                0,
              ),
              child: Text(
                note!,
                style: TextStyle(
                  fontSize: GinkgoTypography.footnote.fontSize,
                  height: 1.4,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({super.key, required this.item});

  final SummaryItem item;

  @override
  Widget build(BuildContext context) {
    final tone = item.tone ?? StatusTone.neutral;
    final value = item.value ?? '未提供';
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GinkgoSpacing.base,
          vertical: GinkgoSpacing.md,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final label = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.icon != null) ...[
                  Icon(
                    item.icon,
                    size: GinkgoTypography.calloutSize + 1,
                    color: statusToneColor(context, tone),
                  ),
                  const SizedBox(width: GinkgoSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: GinkgoTypography.calloutSize,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ),
              ],
            );
            final valueText = Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: GinkgoTypography.headline.fontSize,
                fontWeight: FontWeight.w600,
                fontFeatures: GinkgoTypography.tabularDigits,
                color: item.value == null
                    ? CupertinoColors.secondaryLabel.resolveFrom(context)
                    : statusToneColor(context, tone),
              ),
            );
            // Wide rows keep the label and the value on one line; narrow rows
            // stack so a long value never truncates the label.
            if (constraints.maxWidth < 280) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label,
                  const SizedBox(height: GinkgoSpacing.xs),
                  valueText,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: label),
                const SizedBox(width: GinkgoSpacing.md),
                Flexible(child: valueText),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A single label/value line for the top of a section.
///
/// It is the compact form of [SummaryStrip]: one dataset, one line, no card.
/// A section that aggregates several sources states its own count instead of
/// repeating a page wide total.
class SummaryLine extends StatelessWidget {
  const SummaryLine(
    this.label,
    this.value, {
    super.key,
    this.icon,
    this.tone = StatusTone.neutral,
  });

  final String label;
  final String value;
  final IconData? icon;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = statusToneColor(context, tone);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: GinkgoSpacing.edgeInsetsListTile,
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: GinkgoTypography.calloutSize + 1, color: color),
              const SizedBox(width: GinkgoSpacing.xs),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: GinkgoTypography.calloutSize,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(width: GinkgoSpacing.md),
            Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: GinkgoTypography.headline.fontSize,
                fontWeight: FontWeight.w600,
                fontFeatures: GinkgoTypography.tabularDigits,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A right aligned number that acts as the visual anchor of one row.
class MetricValue extends StatelessWidget {
  const MetricValue(
    this.value, {
    super.key,
    this.prominent = false,
    this.tone = StatusTone.neutral,
    this.suffix,
  });

  final String value;
  final bool prominent;
  final StatusTone tone;
  final String? suffix;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: prominent
              ? GinkgoTypography.metricProminentSize
              : GinkgoTypography.metricSize,
          fontWeight: FontWeight.w600,
          fontFeatures: GinkgoTypography.tabularDigits,
          color: statusToneColor(context, tone),
        ),
      ),
      if (suffix != null) ...[
        const SizedBox(width: GinkgoSpacing.xs),
        Text(
          suffix!,
          style: TextStyle(
            fontSize: GinkgoTypography.footnote.fontSize,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ],
    ],
  );
}
