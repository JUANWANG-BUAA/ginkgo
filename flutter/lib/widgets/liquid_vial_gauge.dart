import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';

/// Color themes for the 3D glass liquid column inside [LiquidVialWell].
enum LiquidPalette {
  /// Signature deep royal cobalt -> azure -> luminous sky aqua.
  cobalt(
    bottom: Color(0xFF0032B8),
    middle: Color(0xFF0B68F5),
    top: Color(0xFF38BDF8),
    meniscus: Color(0xFF7DD3FC),
    rim: Color(0xFFE0F2FE),
  ),

  /// Completion & healthy quota emerald -> jade -> mint.
  emerald(
    bottom: Color(0xFF065F46),
    middle: Color(0xFF10B981),
    top: Color(0xFF5EEAD4),
    meniscus: Color(0xFF99F6E4),
    rim: Color(0xFFECFDF5),
  ),

  /// Caution / high-consumption amber -> gold -> warm honey.
  amber(
    bottom: Color(0xFF9A3412),
    middle: Color(0xFFF59E0B),
    top: Color(0xFFFCD34D),
    meniscus: Color(0xFFFDE68A),
    rim: Color(0xFFFFFBEB),
  ),

  /// Privacy vault / financial indigo -> amethyst -> lavender.
  violet(
    bottom: Color(0xFF3B0764),
    middle: Color(0xFF7C3AED),
    top: Color(0xFFC084FC),
    meniscus: Color(0xFFE9D5FF),
    rim: Color(0xFFFAF5FF),
  );

  const LiquidPalette({
    required this.bottom,
    required this.middle,
    required this.top,
    required this.meniscus,
    required this.rim,
  });

  final Color bottom;
  final Color middle;
  final Color top;
  final Color meniscus;
  final Color rim;
}

/// Tactile recessed instrument well housing a 3D glass test-tube gauge,
/// top code/percentage readout, precision graduation ticks, and bottom footer.
class LiquidVialWell extends StatelessWidget {
  const LiquidVialWell({
    super.key,
    required this.code,
    required this.readout,
    required this.fillRatio,
    this.palette = LiquidPalette.cobalt,
    this.scaleTicks = const ['75%', '50%', '25%'],
    this.footer,
    this.semanticLabel,
    this.frosted = false,
  });

  /// Short uppercase code in top-left of the well (e.g. `NET`, `EVAL`, `FIN`).
  final String code;

  /// Top-right crisp tabular readout (e.g. `58%`, `--`, `••`).
  final String readout;

  /// Liquid level from `0.0` to `1.0`, or `null` when unqueried / unknown.
  final double? fillRatio;

  final LiquidPalette palette;

  /// Three major tick labels from top (75%) to bottom (25%).
  final List<String> scaleTicks;

  /// Optional bottom metric inside the well (e.g. `12.5G 已用`).
  final String? footer;

  final String? semanticLabel;

  /// Renders a subtle frosted/locked liquid appearance when values are masked.
  final bool frosted;

  static const double _wellWidth = 118.0;
  static const double _canvasHeight = 148.0;
  static const Duration _animDuration = Duration(milliseconds: 420);
  static const EdgeInsets _wellPadding = EdgeInsets.symmetric(
    horizontal: GinkgoSpacing.sm + GinkgoSpacing.xs,
    vertical: GinkgoSpacing.sm + GinkgoSpacing.xs,
  );

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final wellBg = dark ? const Color(0xFF171B24) : const Color(0xFFF3F1EC);
    final wellBorder = dark
        ? const Color(0xFF2D3545)
        : const Color(0xFFE3DFD6);
    final codeColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final readoutColor = CupertinoColors.label.resolveFrom(context);
    final targetRatio = fillRatio?.clamp(0.0, 1.0);

    final well = Container(
      width: _wellWidth,
      padding: _wellPadding,
      decoration: BoxDecoration(
        color: wellBg,
        borderRadius: BorderRadius.circular(GinkgoRadii.panel),
        border: Border.all(color: wellBorder, width: GinkgoSpacing.hairline * 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GinkgoTypography.caption2.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: codeColor,
                  ),
                ),
              ),
              const SizedBox(width: GinkgoSpacing.xs),
              Flexible(
                child: Text(
                  readout,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GinkgoTypography.footnote.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: GinkgoTypography.tabularDigits,
                    color: readoutColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: GinkgoSpacing.sm),
          SizedBox(
            height: _canvasHeight,
            child: targetRatio == null
                ? CustomPaint(
                    painter: _GlassVialPainter(
                      ratio: null,
                      palette: palette,
                      dark: dark,
                      frosted: frosted,
                      scaleTicks: scaleTicks,
                      tickLabelColor: codeColor,
                    ),
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: targetRatio, end: targetRatio),
                    duration: reduceMotion ? Duration.zero : _animDuration,
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedRatio, _) => CustomPaint(
                      painter: _GlassVialPainter(
                        ratio: animatedRatio,
                        palette: palette,
                        dark: dark,
                        frosted: frosted,
                        scaleTicks: scaleTicks,
                        tickLabelColor: codeColor,
                      ),
                    ),
                  ),
          ),
          if (footer != null && footer!.isNotEmpty) ...[
            const SizedBox(height: GinkgoSpacing.small),
            Text(
              footer!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GinkgoTypography.caption2.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: GinkgoTypography.tabularDigits,
                color: codeColor,
              ),
            ),
          ],
        ],
      ),
    );

    if (semanticLabel == null) return well;
    return Semantics(
      container: true,
      label: semanticLabel,
      value: readout,
      child: ExcludeSemantics(child: well),
    );
  }
}

class _GlassVialPainter extends CustomPainter {
  const _GlassVialPainter({
    required this.ratio,
    required this.palette,
    required this.dark,
    required this.frosted,
    required this.scaleTicks,
    required this.tickLabelColor,
  });

  final double? ratio;
  final LiquidPalette palette;
  final bool dark;
  final bool frosted;
  final List<String> scaleTicks;
  final Color tickLabelColor;

  static const List<(double xFrac, double yFrac, double radius, double alpha)>
  _bubbles = [
    (0.34, 0.14, 1.5, 0.45),
    (0.66, 0.22, 2.1, 0.55),
    (0.45, 0.33, 1.3, 0.38),
    (0.72, 0.44, 1.8, 0.48),
    (0.30, 0.52, 2.3, 0.52),
    (0.58, 0.63, 1.4, 0.42),
    (0.40, 0.74, 2.0, 0.50),
    (0.68, 0.83, 1.5, 0.44),
    (0.50, 0.90, 1.2, 0.36),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final tubeWidth = math.min(34.0, size.width * 0.38);
    final tubeLeft = 6.0;
    final tubeTop = 3.0;
    final tubeBottom = size.height - 4.0;
    final tubeHeight = tubeBottom - tubeTop;
    final tubeRect = Rect.fromLTWH(tubeLeft, tubeTop, tubeWidth, tubeHeight);
    final tubeRadius = Radius.circular(tubeWidth / 2);
    final outerRRect = RRect.fromRectAndRadius(tubeRect, tubeRadius);

    // 1. Soft ambient base shadow beneath the glass tube.
    final shadowPaint = Paint()
      ..color = (dark ? const Color(0x66000000) : const Color(0x221E293B))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawRRect(outerRRect.shift(const Offset(1.5, 2.5)), shadowPaint);

    // 2. Empty glass cylinder body gradient (subtle cylindrical depth).
    final glassBodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(tubeLeft, tubeTop),
        Offset(tubeLeft + tubeWidth, tubeTop),
        dark
            ? const [
                Color(0xFF283142),
                Color(0xFF1D2432),
                Color(0xFF161B26),
                Color(0xFF263042),
              ]
            : const [
                Color(0xFFFFFFFF),
                Color(0xFFE7ECF4),
                Color(0xFFD9E1EE),
                Color(0xFFF4F7FB),
              ],
        const [0.0, 0.30, 0.75, 1.0],
      );
    canvas.drawRRect(outerRRect, glassBodyPaint);

    // 3. Liquid column + meniscus + effervescent bubbles inside inner cavity.
    final wallInset = 2.4;
    final innerRect = tubeRect.deflate(wallInset);
    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      Radius.circular(innerRect.width / 2),
    );

    final activeRatio = ratio;
    if (activeRatio != null && activeRatio > 0.008) {
      final clamped = activeRatio.clamp(0.03, 1.0);
      final liquidHeight = innerRect.height * clamped;
      final liquidTop = innerRect.bottom - liquidHeight;
      final liquidRect = Rect.fromLTRB(
        innerRect.left,
        liquidTop,
        innerRect.right,
        innerRect.bottom,
      );

      canvas.save();
      canvas.clipRRect(innerRRect);

      final opacity = frosted ? 0.58 : 1.0;
      final liquidPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(innerRect.center.dx, innerRect.bottom),
          Offset(innerRect.center.dx, liquidTop),
          [
            palette.bottom.withValues(alpha: opacity),
            palette.middle.withValues(alpha: opacity),
            palette.top.withValues(alpha: opacity),
          ],
          const [0.0, 0.58, 1.0],
        );
      canvas.drawRect(liquidRect, liquidPaint);

      // Cylindrical horizontal shading across the liquid so it feels round.
      final cylinderShade = Paint()
        ..shader = ui.Gradient.linear(
          Offset(innerRect.left, liquidTop),
          Offset(innerRect.right, liquidTop),
          [
            const Color(0x38FFFFFF),
            const Color(0x00FFFFFF),
            const Color(0x2E000A24),
          ],
          const [0.0, 0.45, 1.0],
        );
      canvas.drawRect(liquidRect, cylinderShade);

      // Rising micro-bubbles inside the submerged region.
      if (!frosted && liquidHeight > 16) {
        for (final (xf, yf, r, a) in _bubbles) {
          final by = innerRect.bottom - (innerRect.height * (1.0 - yf));
          if (by > liquidTop + 6 && by < innerRect.bottom - 5) {
            final bx = innerRect.left + innerRect.width * xf;
            final bubblePaint = Paint()
              ..color = palette.rim.withValues(alpha: a);
            canvas.drawCircle(Offset(bx, by), r, bubblePaint);
          }
        }
      }

      // 3D elliptical meniscus surface plane at the top of the liquid!
      if (clamped < 0.96) {
        final meniscusHeight = math.min(7.0, innerRect.width * 0.24);
        final meniscusRect = Rect.fromCenter(
          center: Offset(innerRect.center.dx, liquidTop),
          width: innerRect.width - 0.8,
          height: meniscusHeight,
        );
        final surfaceFill = Paint()
          ..shader = ui.Gradient.linear(
            meniscusRect.topCenter,
            meniscusRect.bottomCenter,
            [
              palette.rim.withValues(alpha: frosted ? 0.55 : 0.88),
              palette.meniscus.withValues(alpha: frosted ? 0.40 : 0.72),
            ],
          );
        canvas.drawOval(meniscusRect, surfaceFill);

        final surfaceRim = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = palette.rim.withValues(alpha: frosted ? 0.65 : 0.95);
        canvas.drawOval(meniscusRect, surfaceRim);
      }

      canvas.restore();
    }

    // 4. Specular vertical highlight streak along the left glass wall.
    canvas.save();
    canvas.clipRRect(outerRRect);
    final highlightRect = Rect.fromLTWH(
      tubeLeft + 3.5,
      tubeTop + 6,
      tubeWidth * 0.16,
      tubeHeight - 12,
    );
    final highlightPaint = Paint()
      ..shader = ui.Gradient.linear(
        highlightRect.topCenter,
        highlightRect.bottomCenter,
        [
          const Color(0xB8FFFFFF),
          const Color(0x55FFFFFF),
          const Color(0x18FFFFFF),
          const Color(0x45FFFFFF),
        ],
        const [0.0, 0.35, 0.78, 1.0],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(highlightRect, const Radius.circular(4)),
      highlightPaint,
    );

    // Subtle secondary rim reflection on the right glass edge.
    final rightRimRect = Rect.fromLTWH(
      tubeRect.right - 4.8,
      tubeTop + 12,
      1.8,
      tubeHeight - 24,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rightRimRect, const Radius.circular(2)),
      Paint()..color = const Color(0x42FFFFFF),
    );
    canvas.restore();

    // 5. Crisp outer glass contour border.
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..shader = ui.Gradient.linear(
        tubeRect.topLeft,
        tubeRect.bottomRight,
        dark
            ? const [Color(0xFF64748B), Color(0xFF334155), Color(0xFF475569)]
            : const [Color(0xFF64748B), Color(0xFF475569), Color(0xFF94A3B8)],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRRect(outerRRect, borderPaint);

    // 6. Precision scale ticks & labels to the right of the glass cylinder.
    final tickStartX = tubeRect.right + 4.5;
    final minorPaint = Paint()
      ..color = tickLabelColor.withValues(alpha: 0.32)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    final majorPaint = Paint()
      ..color = tickLabelColor.withValues(alpha: 0.68)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    const fractions = [0.875, 0.75, 0.625, 0.50, 0.375, 0.25, 0.125];
    const majorIndices = {1: 0, 3: 1, 5: 2};

    for (var i = 0; i < fractions.length; i++) {
      final frac = fractions[i];
      final y = innerRect.bottom - innerRect.height * frac;
      final majorIdx = majorIndices[i];
      if (majorIdx != null) {
        canvas.drawLine(
          Offset(tickStartX, y),
          Offset(tickStartX + 4.5, y),
          majorPaint,
        );
        if (majorIdx < scaleTicks.length && scaleTicks[majorIdx].isNotEmpty) {
          final tp = TextPainter(
            text: TextSpan(
              text: scaleTicks[majorIdx],
              style: TextStyle(
                fontFamily: GinkgoTypography.font,
                fontFamilyFallback: GinkgoTypography.fallback,
                fontSize: GinkgoTypography.tabLabel.fontSize,
                fontWeight: FontWeight.w600,
                fontFeatures: GinkgoTypography.tabularDigits,
                color: tickLabelColor.withValues(alpha: 0.85),
              ),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout(maxWidth: math.max(0, size.width - tickStartX - 7));
          tp.paint(canvas, Offset(tickStartX + 6.5, y - tp.height / 2));
        }
      } else {
        canvas.drawLine(
          Offset(tickStartX, y),
          Offset(tickStartX + 2.6, y),
          minorPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GlassVialPainter oldDelegate) =>
      oldDelegate.ratio != ratio ||
      oldDelegate.palette != palette ||
      oldDelegate.dark != dark ||
      oldDelegate.frosted != frosted ||
      oldDelegate.tickLabelColor != tickLabelColor ||
      oldDelegate.scaleTicks != scaleTicks;
}
