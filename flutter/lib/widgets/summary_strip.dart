import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/status_chip.dart';

/// One label/value pair. The value answers the page's question; the label
/// says what the value is about.
class SummaryItem {
  const SummaryItem(this.label, this.value, {this.icon, this.tone, this.key});

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
    final compactSingle = items.length == 1;
    final scale =
        MediaQuery.textScalerOf(context).scale(GinkgoTypography.calloutSize) /
        GinkgoTypography.calloutSize;
    final compactGrid =
        items.length >= 2 &&
        items.length <= 4 &&
        !AppleDesign.desktop(context) &&
        MediaQuery.sizeOf(context).width >= 360 &&
        scale <= 1.15;
    return Padding(
      padding: GinkgoSpacing.summaryStart(
        single: compactSingle,
        desktop: AppleDesign.desktop(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compactSingle)
            SummaryLine(
              items.single.label,
              items.single.value ?? '未提供',
              key: items.single.key,
              icon: items.single.icon,
              tone: items.single.tone ?? StatusTone.neutral,
            )
          else
            _SummarySurface(items: items, grid: compactGrid),
          if (note != null)
            Semantics(
              container: true,
              label: note,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  GinkgoSpacing.base,
                  GinkgoSpacing.xs,
                  GinkgoSpacing.base,
                  0,
                ),
                child: ExcludeSemantics(
                  child: Builder(
                    builder: (context) {
                      final fontSize = GinkgoTypography.footnote.fontSize!;
                      final wrapsForDynamicType =
                          MediaQuery.textScalerOf(context).scale(fontSize) >
                          fontSize * 1.3;
                      return Text(
                        note!,
                        maxLines: wrapsForDynamicType ? null : 1,
                        overflow: wrapsForDynamicType
                            ? null
                            : TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fontSize,
                          height: 1.3,
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummarySurface extends StatelessWidget {
  const _SummarySurface({required this.items, required this.grid});

  final List<SummaryItem> items;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final child = grid
        ? _SummaryGrid(items: items)
        : Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _SummaryRow(key: items[index].key, item: items[index]),
                if (index != items.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: GinkgoSpacing.base,
                    ),
                    child: SizedBox(
                      height: GinkgoSpacing.hairline,
                      child: ColoredBox(
                        color: CupertinoColors.separator
                            .resolveFrom(context)
                            .withValues(alpha: 0.16),
                      ),
                    ),
                  ),
              ],
            ],
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppleDesign.pageInset),
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(AppleDesign.panelRadius(context)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
              context,
            ),
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
          child: child,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({super.key, required this.item});

  final SummaryItem item;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: GinkgoSpacing.base,
        vertical: GinkgoSpacing.md,
      ),
      child: _SummaryPair(
        label: item.label,
        value: item.value ?? '未提供',
        icon: item.icon,
        tone: item.tone ?? StatusTone.neutral,
      ),
    ),
  );
}

/// Two-column summary for regular phone layouts. Four values fit in a 2×2
/// group; three values use a final full-width row. Larger type and narrow
/// screens fall back to the readable, full-width list above.
class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.items});

  final List<SummaryItem> items;

  @override
  Widget build(BuildContext context) {
    final separator = CupertinoColors.separator
        .resolveFrom(context)
        .withValues(alpha: 0.16);
    final rows = <Widget>[];
    for (var index = 0; index < items.length; index += 2) {
      if (rows.isNotEmpty) {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GinkgoSpacing.base),
            child: SizedBox(
              height: GinkgoSpacing.hairline,
              child: ColoredBox(color: separator),
            ),
          ),
        );
      }
      final remaining = items.length - index;
      if (remaining == 1) {
        rows.add(_SummaryRow(key: items[index].key, item: items[index]));
      } else {
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _SummaryGridCell(item: items[index])),
                SizedBox(
                  width: GinkgoSpacing.hairline,
                  child: ColoredBox(color: separator),
                ),
                Expanded(child: _SummaryGridCell(item: items[index + 1])),
              ],
            ),
          ),
        );
      }
    }
    return Column(children: rows);
  }
}

class _SummaryGridCell extends StatelessWidget {
  const _SummaryGridCell({required this.item});

  final SummaryItem item;

  @override
  Widget build(BuildContext context) {
    final tone = item.tone ?? StatusTone.neutral;
    final iconColor = statusToneColor(context, tone);
    final labelStyle = TextStyle(
      fontSize: GinkgoTypography.footnote.fontSize,
      height: 1.25,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    final valueStyle = TextStyle(
      fontSize: GinkgoTypography.title2.fontSize,
      height: 1.2,
      fontWeight: FontWeight.w600,
      fontFeatures: GinkgoTypography.tabularDigits,
      color: summaryValueColor(context, tone),
    );
    return Semantics(
      key: item.key,
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GinkgoSpacing.base,
          vertical: GinkgoSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.icon != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      top: GinkgoSpacing.opticalIconInset,
                    ),
                    child: Icon(
                      item.icon,
                      size: GinkgoTypography.footnote.fontSize,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: GinkgoSpacing.xs),
                ],
                Expanded(
                  child: Text(
                    item.label,
                    style: labelStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: GinkgoSpacing.xs),
            Text(
              item.value ?? '未提供',
              style: valueStyle,
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// The colour of a summary value.
///
/// A plain value uses the primary label colour so it reads as the answer;
/// a toned value keeps its status colour. The label of the pair always stays
/// in the secondary colour.
Color summaryValueColor(BuildContext context, StatusTone tone) {
  if (tone == StatusTone.neutral) {
    return CupertinoColors.label.resolveFrom(context);
  }
  return statusToneColor(context, tone);
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
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    child: Padding(
      padding: GinkgoSpacing.edgeInsetsListTile,
      child: _SummaryPair(label: label, value: value, icon: icon, tone: tone),
    ),
  );
}

/// The shared label/value layout.
///
/// Wide rows keep the label and the value on one line and the value is right
/// aligned; narrow rows stack them so a long value never truncates the label.
/// The label always uses the secondary colour, the value the primary one, so
/// the pair reads as a question and its answer.
class _SummaryPair extends StatelessWidget {
  const _SummaryPair({
    required this.label,
    required this.value,
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
    final scaler = MediaQuery.textScalerOf(context);
    final inheritedStyle = DefaultTextStyle.of(context).style;
    final labelStyle = inheritedStyle.copyWith(
      fontSize: GinkgoTypography.calloutSize,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    final valueStyle = inheritedStyle.copyWith(
      fontSize: GinkgoTypography.headline.fontSize,
      fontWeight: FontWeight.w600,
      fontFeatures: GinkgoTypography.tabularDigits,
      color: summaryValueColor(context, tone),
    );
    final labelPainter = TextPainter(
      text: TextSpan(text: label, style: labelStyle),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final valuePainter = TextPainter(
      text: TextSpan(text: value, style: valueStyle),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final iconWidth = icon == null
        ? 0.0
        : GinkgoTypography.calloutSize + 1 + GinkgoSpacing.xs;
    final valueWidget = Text(
      value,
      textAlign: TextAlign.end,
      softWrap: true,
      style: valueStyle,
    );
    final labelWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: GinkgoTypography.calloutSize + 1, color: color),
          const SizedBox(width: GinkgoSpacing.xs),
        ],
        Text(
          label,
          style: labelStyle,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final inlineWidth =
            labelPainter.width +
            valuePainter.width +
            iconWidth +
            GinkgoSpacing.md;
        if (inlineWidth > constraints.maxWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: GinkgoTypography.calloutSize + 1,
                      color: color,
                    ),
                    const SizedBox(width: GinkgoSpacing.xs),
                  ],
                  Flexible(child: Text(label, style: labelStyle)),
                ],
              ),
              const SizedBox(height: GinkgoSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  textAlign: TextAlign.start,
                  softWrap: true,
                  style: valueStyle,
                ),
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            labelWidget,
            const Spacer(),
            const SizedBox(width: GinkgoSpacing.md),
            valueWidget,
          ],
        );
      },
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
          color: summaryValueColor(context, tone),
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
