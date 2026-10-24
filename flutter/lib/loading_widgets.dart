import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'apple_design.dart';

/// A small ginkgo fan breathes without suggesting a measured percentage.
/// No ticker runs when motion is reduced or the containing tab is inactive.
class GinkgoActivity extends StatefulWidget {
  const GinkgoActivity({super.key, this.size = 22});
  final double size;

  @override
  State<GinkgoActivity> createState() => _GinkgoActivityState();
}

class _GinkgoActivityState extends State<GinkgoActivity>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _pulse.stop();
      _pulse.value = 0.5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Opacity(
        opacity: 0.55 + 0.45 * _pulse.value,
        child: Transform.scale(scale: 0.92 + 0.08 * _pulse.value, child: child),
      ),
      child: CustomPaint(
        size: Size.square(widget.size),
        // The ginkgo leaf is brand identity, not a theme accent: a blue or
        // coral leaf reads as a generic leaf. Page accents stay in controls.
        painter: _GinkgoPainter(AppleDesign.accent.resolveFrom(context)),
      ),
    ),
  );
}

class _GinkgoPainter extends CustomPainter {
  const _GinkgoPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final leaf = Path()
      ..moveTo(12, 18)
      ..quadraticBezierTo(4, 17, 2, 7)
      ..quadraticBezierTo(6, 1, 11, 4)
      ..lineTo(12, 7)
      ..lineTo(13, 4)
      ..quadraticBezierTo(18, 1, 22, 7)
      ..quadraticBezierTo(20, 17, 12, 18)
      ..close();
    canvas.drawPath(leaf, Paint()..color = color.withValues(alpha: 0.18));
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(leaf, stroke);
    for (final angle in [-0.85, -0.4, 0.4, 0.85]) {
      canvas.drawLine(
        const Offset(12, 17),
        Offset(12 + math.sin(angle) * 10, 17 - math.cos(angle) * 11),
        stroke,
      );
    }
    canvas.drawLine(const Offset(12, 18), const Offset(10, 23), stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GinkgoPainter oldDelegate) => color != oldDelegate.color;
}

/// Unified first-load feedback: a branded leaf plus one stable live-region
/// announcement. It never implies a measured percentage or fake progress.
class GinkgoLoadingView extends StatelessWidget {
  const GinkgoLoadingView({
    super.key,
    required this.label,
    this.detail,
    this.compact = false,
  });

  final String label;
  final String? detail;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: detail == null ? label : '$label，$detail',
    excludeSemantics: true,
    child: Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 16 : 40,
        horizontal: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GinkgoActivity(size: compact ? 24 : 36),
          SizedBox(height: compact ? 8 : 14),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 14 : 15,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppleDesign.statusInactive.resolveFrom(context),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Stable, inline status: stale content stays in place during refresh/failure.
class SectionFeedback extends StatelessWidget {
  const SectionFeedback({
    super.key,
    required this.loading,
    required this.label,
    required this.hasData,
    this.error,
    this.onRetry,
  });
  final bool loading, hasData;
  final String label;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (!loading && error == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (loading)
              const GinkgoActivity()
            else
              const Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 22,
                color: CupertinoColors.systemOrange,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loading ? label : error!),
                  if (hasData) ...[
                    const SizedBox(height: 3),
                    Text(
                      '保留上次结果',
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!loading && onRetry != null)
              CupertinoButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

/// Fade only on first insertion; later refreshes keep layout and content steady.
class SectionReveal extends StatelessWidget {
  const SectionReveal({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppleDesign.duration(context, 180),
    builder: (context, value, child) => Opacity(opacity: value, child: child),
    child: child,
  );
}

/// Desktop refresh lives in the focused page, including its search fields.
class PageRefreshShortcut extends StatelessWidget {
  const PageRefreshShortcut({super.key, required this.child, this.onRefresh});
  final Widget child;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    if (!AppleDesign.desktop(context)) return child;
    void refresh() => onRefresh?.call();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): refresh,
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): refresh,
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
