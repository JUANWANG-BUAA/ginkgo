import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/ginkgo_mark.dart';
import 'package:ginkgo_mirror/design/tokens/spacing.dart';
import 'package:ginkgo_mirror/design/tokens/typography.dart';

/// 冷启动画面：一枚银杏叶在纸感底色上展开，随后出现字标与细进度线。
///
/// 设计取自一线商业 App 的冷启动习惯：品牌元素先出现、动效克制、可关闭；
/// 末段把底色过渡回应用背景，让“启动页 → 登录页”不闪白。
class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  late final Animation<double> _leaf = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.62, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _wordmark = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.42, 0.78, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _backdrop = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.62, 1, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 减少动态效果时直接呈现最终状态，不播放展开动画。
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    if (!_controller.isAnimating && !_controller.isCompleted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final paper = CupertinoDynamicColor.resolve(
      const CupertinoDynamicColor.withBrightness(
        color: Color(0xffe5e4d8),
        darkColor: Color(0xff11160f),
      ),
      context,
    );
    final app = CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final backdrop = Color.lerp(paper, app, _backdrop.value) ?? paper;
    final ink = CupertinoColors.label.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: backdrop,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(GinkgoSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (reduced)
                  const GinkgoMark(
                    key: Key('startup-mark'),
                    size: 104,
                  )
                else
                  AnimatedBuilder(
                    key: const Key('startup-entrance'),
                    animation: _controller,
                    builder: (context, child) => GinkgoMark(
                      key: const Key('startup-mark'),
                      size: 104,
                      progress: _leaf.value,
                      veinColor: backdrop,
                    ),
                  ),
                const SizedBox(height: GinkgoSpacing.xl),
                if (reduced)
                  Text(
                    'Ginkgo',
                    textAlign: TextAlign.center,
                    style: GinkgoTypography.largeTitle.copyWith(
                      letterSpacing: -.6,
                      color: ink,
                    ),
                  )
                else
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => Opacity(
                      opacity: _wordmark.value,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - _wordmark.value)),
                        child: child,
                      ),
                    ),
                    child: Text(
                      'Ginkgo',
                      textAlign: TextAlign.center,
                      style: GinkgoTypography.largeTitle.copyWith(
                        letterSpacing: -.6,
                        color: ink,
                      ),
                    ),
                  ),
                const SizedBox(height: GinkgoSpacing.md),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Opacity(
                    opacity: reduced ? 1 : ((_wordmark.value - 0.4) / 0.6).clamp(0, 1),
                    child: child,
                  ),
                  child: Text(
                    '让校园生活井然有序',
                    textAlign: TextAlign.center,
                    style: GinkgoTypography.footnote.copyWith(
                      letterSpacing: .4,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ),
                const SizedBox(height: GinkgoSpacing.xxl),
                Semantics(
                  liveRegion: true,
                  label: '正在恢复本地会话',
                  excludeSemantics: true,
                  child: _StartupProgress(color: ink, enabled: !reduced),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 细进度线：一条来回扫过的高光线，替代传统转圈动画。
class _StartupProgress extends StatefulWidget {
  const _StartupProgress({required this.color, required this.enabled});

  final Color color;
  final bool enabled;

  @override
  State<_StartupProgress> createState() => _StartupProgressState();
}

class _StartupProgressState extends State<_StartupProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TickerMode 与“减少动态效果”都在依赖变化时读取，不在 initState 里取。
    final active = widget.enabled && TickerMode.valuesOf(context).enabled;
    if (active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 132,
    height: 3,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(
        painter: _SweepPainter(
          progress: _controller.value,
          color: widget.color.withValues(alpha: .38),
          highlight: widget.color.withValues(alpha: .78),
        ),
      ),
    ),
  );
}

class _SweepPainter extends CustomPainter {
  const _SweepPainter({
    required this.progress,
    required this.color,
    required this.highlight,
  });

  final double progress;
  final Color color;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(size.height / 2),
      ),
      track,
    );
    // 高光在轨道内往返，位置用三角波，保证衔接自然。
    final sweep = size.width * 0.42;
    final phase = progress < 0.5 ? progress * 2 : (1 - progress) * 2;
    final left = phase * (size.width - sweep);
    final glow = Paint()
      ..style = PaintingStyle.fill
      ..color = highlight;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, sweep, size.height),
        Radius.circular(size.height / 2),
      ),
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant _SweepPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
