import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/liquid_vial_gauge.dart';
import 'package:ginkgo_mirror/widgets/status_chip.dart';

/// One colored segment inside [SegmentedCapsuleBar].
class BarSegment {
  const BarSegment({
    required this.fraction,
    required this.startColor,
    required this.endColor,
  });

  final double fraction;
  final Color startColor;
  final Color endColor;
}

/// One horizontal meter row inside [TelemetryInstrumentCard]
/// (e.g. `免费剩余  [═══════░░░]  58% · 17.5G`).
class TelemetryMeterData {
  const TelemetryMeterData({
    required this.label,
    required this.trailing,
    this.ratio,
    this.startColor = const Color(0xFF0B68F5),
    this.endColor = const Color(0xFF38BDF8),
  });

  final String label;
  final String trailing;

  /// When `null`, renders only a clean key-value telemetry row without a bar.
  final double? ratio;
  final Color startColor;
  final Color endColor;
}

/// Glowing dot + crisp label pill used in telemetry card headers.
class TelemetryPill extends StatelessWidget {
  const TelemetryPill({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.dotColor,
  });

  final String label;
  final StatusTone tone;
  final Color? dotColor;

  static const double _dotSize = 6.5;
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: GinkgoSpacing.sm + GinkgoSpacing.opticalIconInset * 2,
    vertical: GinkgoSpacing.xs,
  );

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final resolvedDot =
        dotColor ??
        switch (tone) {
          StatusTone.success => const Color(0xFF10B981),
          StatusTone.pending => const Color(0xFFF59E0B),
          StatusTone.danger => const Color(0xFFEF4444),
          StatusTone.uncertain => const Color(0xFF94A3B8),
          StatusTone.accent => const Color(0xFF189840),
          StatusTone.neutral => const Color(0xFF0EA5E9),
        };
    final bg = switch (tone) {
      StatusTone.success => resolvedDot.withValues(alpha: dark ? 0.18 : 0.11),
      StatusTone.pending => resolvedDot.withValues(alpha: dark ? 0.20 : 0.12),
      StatusTone.danger => resolvedDot.withValues(alpha: dark ? 0.20 : 0.12),
      _ =>
        dark
            ? const Color(0xFF232936)
            : const Color(0xFFF2F4F8),
    };
    final border = resolvedDot.withValues(alpha: dark ? 0.35 : 0.24);
    final textColor = switch (tone) {
      StatusTone.success => AppleDesign.statusSuccess.resolveFrom(context),
      StatusTone.pending => AppleDesign.statusPending.resolveFrom(context),
      StatusTone.danger => AppleDesign.statusDanger.resolveFrom(context),
      _ => CupertinoColors.label.resolveFrom(context),
    };

    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(GinkgoRadii.pill),
        border: Border.all(color: border, width: GinkgoSpacing.hairline * 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(
              color: resolvedDot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: GinkgoSpacing.xs + GinkgoSpacing.opticalIconInset),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GinkgoTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recessed multi-segment rounded capsule bar (like the dual-blue context bar).
class SegmentedCapsuleBar extends StatelessWidget {
  const SegmentedCapsuleBar({
    super.key,
    required this.segments,
    this.height = 7.5,
  });

  final List<BarSegment> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final trackColor = dark
        ? const Color(0xFF222834)
        : const Color(0xFFE6E9EF);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        var usedFraction = 0.0;
        final children = <Widget>[];
        for (var i = 0; i < segments.length; i++) {
          final seg = segments[i];
          final available = (1.0 - usedFraction).clamp(0.0, 1.0);
          final frac = seg.fraction.clamp(0.0, available);
          if (frac <= 0.002) continue;
          final segLeft = maxW * usedFraction;
          final segWidth = maxW * frac;
          usedFraction += frac;
          children.add(
            Positioned(
              left: segLeft,
              top: 0,
              bottom: 0,
              width: segWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(GinkgoRadii.pill),
                  gradient: LinearGradient(
                    colors: [seg.startColor, seg.endColor],
                  ),
                ),
              ),
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(GinkgoRadii.pill),
          child: Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(GinkgoRadii.pill),
            ),
            child: Stack(children: children),
          ),
        );
      },
    );
  }
}

/// Compact pill switcher (modeled after `Gemini | Claude` segmented capsule).
class TelemetryModeSwitcher extends StatelessWidget {
  const TelemetryModeSwitcher({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const EdgeInsets _outerPadding = EdgeInsets.all(
    GinkgoSpacing.opticalIconInset * 2.5,
  );
  static const EdgeInsets _itemPadding = EdgeInsets.symmetric(
    horizontal: GinkgoSpacing.sm + GinkgoSpacing.xs,
    vertical: GinkgoSpacing.xs,
  );

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final shellBg = dark ? const Color(0xFF1A202C) : const Color(0xFFEDEFF4);
    final activeBg = dark ? const Color(0xFF2D3B55) : const Color(0xFFDCE5F7);
    final activeText = dark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF);
    final idleText = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Container(
      padding: _outerPadding,
      decoration: BoxDecoration(
        color: shellBg,
        borderRadius: BorderRadius.circular(GinkgoRadii.pill),
        border: Border.all(
          color: CupertinoColors.separator
              .resolveFrom(context)
              .withValues(alpha: 0.25),
          width: GinkgoSpacing.hairline,
        ),
      ),
      child: Wrap(
        spacing: GinkgoSpacing.opticalIconInset * 2,
        children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(i),
              child: Container(
                padding: _itemPadding,
                decoration: BoxDecoration(
                  color: i == selectedIndex ? activeBg : null,
                  borderRadius: BorderRadius.circular(GinkgoRadii.pill),
                ),
                child: Text(
                  labels[i],
                  style: GinkgoTypography.caption.copyWith(
                    fontWeight: i == selectedIndex
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: i == selectedIndex ? activeText : idleText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
  static const EdgeInsets _innerPadding = EdgeInsets.all(
    GinkgoSpacing.md + GinkgoSpacing.opticalIconInset * 2,
  );
  static const double _labelColWidth = 68.0;

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
          const SizedBox(height: GinkgoSpacing.opticalIconInset * 2),
          Text(
            subheadline!,
            style: GinkgoTypography.caption.copyWith(
              fontFeatures: GinkgoTypography.tabularDigits,
              color: secondaryColor,
            ),
          ),
        ],
        if (segments.isNotEmpty) ...[
          const SizedBox(height: GinkgoSpacing.sm + GinkgoSpacing.opticalIconInset * 2),
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
          const SizedBox(height: GinkgoSpacing.sm + GinkgoSpacing.xs),
          ColoredBox(
            color: dividerColor,
            child: const SizedBox(height: GinkgoSpacing.hairline),
          ),
          const SizedBox(height: GinkgoSpacing.sm + GinkgoSpacing.opticalIconInset * 2),
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
              color: dark
                  ? const Color(0x38000000)
                  : const Color(0x0F0F172A),
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
                    const SizedBox(width: GinkgoSpacing.md + GinkgoSpacing.opticalIconInset * 2),
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
