import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/liquid_vial_gauge.dart';
import 'package:ginkgo_mirror/widgets/status_chip.dart';
import 'package:ginkgo_mirror/widgets/telemetry_primitives.dart';

export 'package:ginkgo_mirror/widgets/telemetry_primitives.dart';

/// Composite tactile telemetry instrument card:
/// Left 3D glass liquid vial (`LiquidVialWell`) + right multi-layer telemetry
/// readout, segmented progress bar, optional mode switcher, and meter rows.
class TelemetryInstrumentCard extends StatelessWidget {
  const TelemetryInstrumentCard({
    super.key,
    required this.vial,
    required this.title,
    required this.statusLabel,
    this.statusTone = StatusTone.neutral,
    required this.headline,
    this.subheadline,
    this.segments = const [],
    this.barLeadingCaption,
    this.barTrailingCaption,
    this.sectionTitle,
    this.sectionBadge,
    this.sectionBadgeTone = StatusTone.success,
    this.switcher,
    this.meters = const [],
  });

  final LiquidVialWell vial;
  final String title;
  final String statusLabel;
  final StatusTone statusTone;
  final String headline;
  final String? subheadline;
  final List<BarSegment> segments;
  final String? barLeadingCaption;
  final String? barTrailingCaption;
  final String? sectionTitle;
  final String? sectionBadge;
  final StatusTone sectionBadgeTone;
  final Widget? switcher;
  final List<TelemetryMeterData> meters;

  static const EdgeInsets _outerMargin = EdgeInsets.fromLTRB(
    GinkgoSpacing.pageInset,
    GinkgoSpacing.md,
    GinkgoSpacing.pageInset,
    GinkgoSpacing.xs,
  );
  static const double _cardInset = GinkgoSpacing.md + GinkgoSpacing.xs;
  static const EdgeInsets _innerPadding = EdgeInsets.all(_cardInset);
  static const double _labelColWidth = 68.0;
  static const double _tightGap = GinkgoSpacing.xs;
  static const double _barGap = GinkgoSpacing.sm + GinkgoSpacing.xs;
  static const double _columnGap = GinkgoSpacing.md + GinkgoSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final cardBg = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
      context,
    );
    final borderColor = dark
        ? const Color(0xFF2B3242)
        : const Color(0xFFE2E5EC);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final dividerColor = CupertinoColors.separator
        .resolveFrom(context)
        .withValues(alpha: 0.22);

    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final stackVertically = screenWidth < 350 || textScale > 1.35;

    final rightPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                style: GinkgoTypography.subheadline.copyWith(
                  fontWeight: FontWeight.w600,
                  color: secondaryColor,
                ),
              ),
            ),
            const SizedBox(width: GinkgoSpacing.sm),
            TelemetryPill(label: statusLabel, tone: statusTone),
          ],
        ),
        const SizedBox(height: GinkgoSpacing.small),
        Text(
          headline,
          style: GinkgoTypography.headline.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: GinkgoTypography.tabularDigits,
            color: labelColor,
          ),
        ),
        if (subheadline != null && subheadline!.isNotEmpty) ...[
          const SizedBox(height: _tightGap),
          Text(
            subheadline!,
            style: GinkgoTypography.caption.copyWith(
              fontFeatures: GinkgoTypography.tabularDigits,
              color: secondaryColor,
            ),
          ),
        ],
        if (segments.isNotEmpty) ...[
          const SizedBox(height: _barGap),
          SegmentedCapsuleBar(segments: segments),
          if (barLeadingCaption != null || barTrailingCaption != null) ...[
            const SizedBox(height: GinkgoSpacing.small),
            Row(
              children: [
                if (barLeadingCaption != null)
                  Expanded(
                    child: Text(
                      barLeadingCaption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GinkgoTypography.caption2.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: GinkgoTypography.tabularDigits,
                        color: secondaryColor,
                      ),
                    ),
                  ),
                if (barTrailingCaption != null) ...[
                  const SizedBox(width: GinkgoSpacing.sm),
                  Text(
                    barTrailingCaption!,
                    style: GinkgoTypography.caption2.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: GinkgoTypography.tabularDigits,
                      color: secondaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
        if (sectionTitle != null || switcher != null || meters.isNotEmpty) ...[
          const SizedBox(height: _barGap),
          ColoredBox(
            color: dividerColor,
            child: const SizedBox(height: GinkgoSpacing.hairline),
          ),
          const SizedBox(height: _barGap),
        ],
        if (sectionTitle != null || switcher != null) ...[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: GinkgoSpacing.sm,
            runSpacing: GinkgoSpacing.xs,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sectionTitle != null)
                    Text(
                      sectionTitle!,
                      style: GinkgoTypography.subheadline.copyWith(
                        fontWeight: FontWeight.w700,
                        color: labelColor,
                      ),
                    ),
                  if (sectionBadge != null) ...[
                    const SizedBox(width: GinkgoSpacing.small),
                    TelemetryPill(
                      label: sectionBadge!,
                      tone: sectionBadgeTone,
                    ),
                  ],
                ],
              ),
              ?switcher,
            ],
          ),
          if (meters.isNotEmpty) const SizedBox(height: GinkgoSpacing.sm),
        ],
        for (var i = 0; i < meters.length; i++) ...[
          if (i > 0) const SizedBox(height: GinkgoSpacing.sm),
          _MeterRowWidget(
            data: meters[i],
            labelWidth: _labelColWidth,
            secondaryColor: secondaryColor,
            labelColor: labelColor,
          ),
        ],
      ],
    );

    return Padding(
      padding: _outerMargin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(GinkgoRadii.dialog),
          border: Border.all(
            color: borderColor,
            width: GinkgoSpacing.hairline * 2,
          ),
          boxShadow: [
            BoxShadow(
              color: dark ? const Color(0x38000000) : const Color(0x0F0F172A),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: _innerPadding,
          child: stackVertically
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: vial),
                    const SizedBox(height: GinkgoSpacing.md),
                    rightPanel,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    vial,
                    const SizedBox(width: _columnGap),
                    Expanded(child: rightPanel),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MeterRowWidget extends StatelessWidget {
  const _MeterRowWidget({
    required this.data,
    required this.labelWidth,
    required this.secondaryColor,
    required this.labelColor,
  });

  final TelemetryMeterData data;
  final double labelWidth;
  final Color secondaryColor;
  final Color labelColor;

  static const double _barHeight = 6.5;

  @override
  Widget build(BuildContext context) {
    final ratio = data.ratio;
    if (ratio == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              data.label,
              style: GinkgoTypography.caption.copyWith(color: secondaryColor),
            ),
          ),
          const SizedBox(width: GinkgoSpacing.sm),
          Text(
            data.trailing,
            style: GinkgoTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: GinkgoTypography.tabularDigits,
              color: labelColor,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GinkgoTypography.caption.copyWith(color: secondaryColor),
          ),
        ),
        const SizedBox(width: GinkgoSpacing.small),
        Expanded(
          child: SegmentedCapsuleBar(
            height: _barHeight,
            segments: [
              BarSegment(
                fraction: ratio.clamp(0.0, 1.0),
                startColor: data.startColor,
                endColor: data.endColor,
              ),
            ],
          ),
        ),
        const SizedBox(width: GinkgoSpacing.sm),
        Text(
          data.trailing,
          style: GinkgoTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: GinkgoTypography.tabularDigits,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}
