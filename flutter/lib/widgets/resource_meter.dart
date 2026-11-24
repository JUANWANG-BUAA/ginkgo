import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/status_chip.dart';
import 'package:ginkgo_mirror/widgets/telemetry_instrument_card.dart';

/// A resource snapshot. A free fraction is not a booking guarantee; unknown
/// totals and empty resources are kept distinct from a fully occupied one.
class ResourceMeter extends StatelessWidget {
  const ResourceMeter({
    super.key,
    required this.label,
    required this.available,
    required this.total,
    required this.unit,
    this.detail,
    this.onTap,
  });
  final String label, unit;
  final String? detail;
  final int? available, total;
  final VoidCallback? onTap;

  static const double _barHeight = 8.0;
  static const EdgeInsets _chevronPadding = EdgeInsets.only(
    left: GinkgoSpacing.sm,
    top: GinkgoSpacing.opticalIconInset * 2,
  );
  static const EdgeInsets _subBaselinePadding = EdgeInsets.only(
    bottom: GinkgoSpacing.opticalIconInset * 2,
  );

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final free = available;
    final capacity = total;
    final known = free != null && capacity != null;
    final countsLabel = free == null
        ? (capacity == null ? '官网未提供数量' : '可用数量未提供 · 共 $capacity $unit')
        : capacity == null
        ? '$unit可用 · 总量未提供'
        : '$unit可用 · 共 $capacity $unit';
    final ratio = known && capacity > 0
        ? (free / capacity).clamp(0.0, 1.0)
        : null;
    final tight = ratio != null && ratio < 0.22;
    final color =
        (free == 0 || tight
                ? AppleDesign.statusPending
                : AppleDesign.resourceTeal)
            .resolveFrom(context);
    final pct = ratio == null ? null : (ratio * 100).round();
    final trackColor = dark ? const Color(0xFF222834) : const Color(0xFFE6E9EF);
    final gradStart = free == 0 || tight
        ? const Color(0xFFD97706)
        : const Color(0xFF0D9488);
    final gradEnd = free == 0 || tight
        ? const Color(0xFFFBBF24)
        : const Color(0xFF38BDF8);

    final content = Padding(
      padding: GinkgoSpacing.edgeInsetsCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GinkgoTypography.headline.copyWith(
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
              if (pct != null) ...[
                const SizedBox(width: GinkgoSpacing.sm),
                TelemetryPill(
                  label: free == 0 ? '已满' : '$pct% 空闲',
                  tone: free == 0
                      ? StatusTone.danger
                      : tight
                      ? StatusTone.pending
                      : StatusTone.success,
                ),
              ],
              if (onTap != null)
                const Padding(
                  padding: _chevronPadding,
                  child: CupertinoListTileChevron(),
                ),
            ],
          ),
          const SizedBox(height: GinkgoSpacing.sm),
          Wrap(
            spacing: GinkgoSpacing.small,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                free == null ? '—' : '$free',
                style: GinkgoTypography.title.copyWith(
                  height: 1.1,
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontFeatures: GinkgoTypography.tabularDigits,
                ),
              ),
              Padding(
                padding: _subBaselinePadding,
                child: Text(
                  countsLabel,
                  style: GinkgoTypography.footnote.copyWith(
                    fontFeatures: GinkgoTypography.tabularDigits,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
          if (ratio != null) ...[
            const SizedBox(height: GinkgoSpacing.sm + GinkgoSpacing.opticalIconInset * 2),
            Semantics(
              label: '$label 空闲比例',
              value: '$pct%',
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(GinkgoRadii.pill),
                  child: SizedBox(
                    height: _barHeight,
                    width: double.infinity,
                    child: ColoredBox(
                      color: trackColor,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: ratio,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                GinkgoRadii.pill,
                              ),
                              gradient: LinearGradient(
                                colors: [gradStart, gradEnd],
                              ),
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (detail != null) ...[
            const SizedBox(height: GinkgoSpacing.small),
            Text(
              detail!,
              style: GinkgoTypography.footnote.copyWith(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
          if (known && capacity == 0) ...[
            const SizedBox(height: GinkgoSpacing.small),
            Text(
              '暂未提供此类资源',
              style: GinkgoTypography.footnote.copyWith(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ],
      ),
    );
    return onTap == null
        ? content
        : CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onTap,
            child: DefaultTextStyle(
              style: CupertinoTheme.of(context).textTheme.textStyle,
              child: content,
            ),
          );
  }
}
