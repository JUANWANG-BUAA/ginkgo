import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
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

/// One horizontal meter row inside `TelemetryInstrumentCard`
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
  static const double _pillHorizontal = GinkgoSpacing.sm + GinkgoSpacing.xs;
  static const double _dotGap =
      GinkgoSpacing.xs + GinkgoSpacing.opticalIconInset;
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: _pillHorizontal,
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
      _ => dark ? const Color(0xFF232936) : const Color(0xFFF2F4F8),
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
          const SizedBox(width: _dotGap),
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

/// Recessed multi-segment rounded capsule bar.
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

/// Compact pill switcher for multi-mode telemetry panels.
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

  static const double _outerPad = GinkgoSpacing.xs;
  static const EdgeInsets _outerPadding = EdgeInsets.all(_outerPad);
  static const EdgeInsets _itemPadding = EdgeInsets.symmetric(
    horizontal: GinkgoSpacing.md,
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
        spacing: GinkgoSpacing.xs,
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
