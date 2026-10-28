import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

/// Ginkgo 品牌标记：银杏叶的矢量绘制，与 Android 启动图标、主页 logo 同源。
///
/// 用矢量而不是位图有三个理由：任意尺寸清晰、可以按进度“画出来”，并且不新增
/// 资源打包负担。图形与 `docs/images/ginkgo-mark.svg` 同形（48×48 视区）。
class GinkgoMark extends StatelessWidget {
  const GinkgoMark({
    super.key,
    this.size = 96,
    this.color,
    this.progress = 1,
    this.veinColor,
  });

  /// 叶片外接尺寸（正方形）。
  final double size;

  /// 叶片颜色；默认取品牌绿。
  final Color? color;

  /// 绘制进度：0 为空白，1 为完整叶片。中间值按笔画长度逐段显现。
  final double progress;

  /// 叶脉颜色；默认取背景色，形成镂空质感。
  final Color? veinColor;

  @override
  Widget build(BuildContext context) {
    final leaf =
        color ??
        CupertinoDynamicColor.resolve(
          const CupertinoDynamicColor.withBrightness(
            color: Color(0xff2f6b3a),
            darkColor: Color(0xff8fd6a4),
          ),
          context,
        );
    final veins =
        veinColor ??
        CupertinoDynamicColor.resolve(
          const CupertinoDynamicColor.withBrightness(
            color: Color(0xffe5e4d8),
            darkColor: Color(0xff14201a),
          ),
          context,
        );
    final normalizedProgress = progress.clamp(0, 1).toDouble();
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GinkgoMarkPainter(
          leaf: leaf,
          vein: veins,
          progress: normalizedProgress,
        ),
        isComplex: true,
      ),
    );
  }
}

class _GinkgoMarkPainter extends CustomPainter {
  const _GinkgoMarkPainter({
    required this.leaf,
    required this.vein,
    required this.progress,
  });

  final Color leaf;
  final Color vein;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 48;
    canvas.save();
    canvas.scale(scale);

    final leafPath = _leafPath();
    final veinPath = _veinPath();

    // 轮廓先描出，叶片随后填充：像叶子展开一样。
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = leaf;
    canvas.drawPath(_partial(leafPath, progress * 0.7), outline);

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = leaf.withValues(alpha: _fillOpacity);
    canvas.drawPath(leafPath, fill);

    if (_veinOpacity > 0) {
      final veinPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round
        ..color = vein.withValues(alpha: _veinOpacity);
      canvas.drawPath(_partial(veinPath, _veinOpacity), veinPaint);
    }
    canvas.restore();
  }

  double get _fillOpacity => ((progress - 0.45) / 0.35).clamp(0, 1);
  double get _veinOpacity => ((progress - 0.6) / 0.3).clamp(0, 1);

  /// 叶片轮廓（与 ginkgo-mark.svg 的路径一致）。
  Path _leafPath() => Path()
    ..moveTo(25, 35)
    ..cubicTo(24, 31, 23, 27, 23, 22)
    ..moveTo(23, 27)
    ..cubicTo(18, 26, 11, 23, 9, 18)
    ..cubicTo(10, 12, 17, 8, 22, 12)
    ..lineTo(24, 19)
    ..lineTo(26, 12)
    ..cubicTo(31, 9, 38, 13, 39, 19)
    ..cubicTo(36, 24, 29, 27, 24, 27);

  /// 叶脉镂空线。
  Path _veinPath() => Path()
    ..moveTo(12, 17)
    ..lineTo(23, 26)
    ..moveTo(18, 14)
    ..lineTo(24, 26)
    ..moveTo(30, 17)
    ..lineTo(18, 26)
    ..moveTo(36, 14)
    ..lineTo(30, 26);

  /// 按路径长度截取一段，用于“逐段显现”的描边。
  Path _partial(Path path, double fraction) {
    if (fraction >= 1) return path;
    if (fraction <= 0) return Path();
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (sum, metric) => sum + metric.length);
    if (total <= 0) return path;
    final target = total * fraction;
    final result = Path();
    var remaining = target;
    for (final metric in metrics) {
      if (remaining <= 0) break;
      final length = math.min(metric.length, remaining);
      result.addPath(metric.extractPath(0, length), Offset.zero);
      remaining -= length;
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant _GinkgoMarkPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.leaf != leaf ||
      oldDelegate.vein != vein;
}
