import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/checkin_qr.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

/// Paints a black-on-white ISO 18004 QR matrix with a standard 4-module quiet zone.
class CheckinQrPainter extends CustomPainter {
  const CheckinQrPainter({required this.matrixSize, required this.modules});

  final int matrixSize;
  final List<bool> modules;
  static const int quietZone = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(Offset.zero & size, white);
    if (matrixSize <= 0 || modules.length < matrixSize * matrixSize) return;

    final totalModules = matrixSize + quietZone * 2;
    final cell = size.shortestSide / totalModules;
    final originX = (size.width - cell * totalModules) / 2;
    final originY = (size.height - cell * totalModules) / 2;
    final dark = Paint()
      ..color = const Color(0xFF000000)
      ..isAntiAlias = false;

    for (var r = 0; r < matrixSize; r++) {
      for (var c = 0; c < matrixSize; c++) {
        if (modules[r * matrixSize + c]) {
          canvas.drawRect(
            Rect.fromLTWH(
              originX + (c + quietZone) * cell,
              originY + (r + quietZone) * cell,
              cell,
              cell,
            ),
            dark,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CheckinQrPainter oldDelegate) =>
      oldDelegate.matrixSize != matrixSize || oldDelegate.modules != modules;
}

/// Rasterizes a crisp black-on-white QR PNG with a standard 4-module quiet zone.
Future<Uint8List> renderCheckinQrPng({
  required int matrixSize,
  required List<bool> modules,
}) async {
  const quiet = CheckinQrPainter.quietZone;
  final total = (matrixSize > 0 ? matrixSize : 21) + quiet * 2;
  final scale = (960 ~/ total).clamp(8, 32);
  final dimension = total * scale;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  CheckinQrPainter(
    matrixSize: matrixSize,
    modules: modules,
  ).paint(canvas, Size(dimension.toDouble(), dimension.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(dimension, dimension);
  try {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('failed to encode QR PNG');
    }
    return byteData.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

class CheckinQrQuickHelperBanner extends StatelessWidget {
  const CheckinQrQuickHelperBanner({
    super.key,
    required this.status,
    required this.secondary,
  });

  final CheckinQuickNotificationStatus status;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final shown = status == CheckinQuickNotificationStatus.shown;
    final tint = shown
        ? AppleDesign.statusSuccess.resolveFrom(context)
        : AppleDesign.statusPending.resolveFrom(context);
    final label = shown
        ? '通知栏快捷刷码已开启 · 在智慧北航扫一扫页下拉点按钮可秒刷新首图'
        : '开启系统通知权限后，可在智慧北航内下拉通知栏秒刷新相册首图';
    return Container(
      key: const Key('checkin-qr-quick-helper-banner'),
      padding: GinkgoSpacing.edgeInsetsListTile,
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(GinkgoRadii.button),
      ),
      child: Row(
        children: [
          Icon(
            shown
                ? CupertinoIcons.bell_circle_fill
                : CupertinoIcons.bell_slash_fill,
            size: GinkgoSpacing.xl,
            color: tint,
          ),
          const SizedBox(width: GinkgoSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppleDesign.caption.copyWith(color: secondary),
            ),
          ),
        ],
      ),
    );
  }
}

class CheckinQrConfirmedView extends StatelessWidget {
  const CheckinQrConfirmedView({super.key});

  @override
  Widget build(BuildContext context) {
    final success = AppleDesign.statusSuccess.resolveFrom(context);
    return Column(
      key: const Key('checkin-qr-confirmed'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          CupertinoIcons.checkmark_circle_fill,
          color: success,
          size: GinkgoSpacing.xxl,
        ),
        const SizedBox(height: GinkgoSpacing.sm),
        Text(
          '签到已确认',
          style: AppleDesign.headline.copyWith(color: success),
        ),
      ],
    );
  }
}

class CheckinQrDisplayCard extends StatelessWidget {
  const CheckinQrDisplayCard({
    super.key,
    required this.courseName,
    required this.ticket,
    required this.loadingQr,
    required this.isDemo,
    required this.issue,
    required this.secondary,
    required this.onRetry,
  });

  final String courseName;
  final CheckInQrResponse? ticket;
  final bool loadingQr;
  final bool isDemo;
  final String? issue;
  final Color secondary;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final current = ticket;
    if (current == null) {
      if (loadingQr) {
        return const Padding(
          padding: GinkgoSpacing.edgeInsetsBalanceHero,
          child: Center(child: GinkgoActivity()),
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            issue ?? '暂时无法生成签到码',
            textAlign: TextAlign.center,
            style: AppleDesign.subheadline.copyWith(
              color: AppleDesign.statusDanger.resolveFrom(context),
            ),
          ),
          const SizedBox(height: GinkgoSpacing.sm),
          CupertinoButton.tinted(
            key: const Key('checkin-qr-retry'),
            onPressed: loadingQr ? null : onRetry,
            child: const Text('重试生成'),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: GinkgoLayout.desktopSidebarWidth,
          ),
          child: AspectRatio(
            aspectRatio: 1,
            child: Semantics(
              label: '$courseName 实时签到二维码',
              image: true,
              child: DecoratedBox(
                key: const Key('checkin-qr-canvas'),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(GinkgoRadii.button),
                ),
                child: CustomPaint(
                  painter: CheckinQrPainter(
                    matrixSize: current.matrixSize,
                    modules: current.modules,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: GinkgoSpacing.sm),
        Text(
          issue ??
              (isDemo
                  ? '演示二维码已就绪'
                  : '每 ${current.refreshSeconds} 秒自动更新 · 时间 ${schoolClockLabel(current.fetchedAt)}'),
          textAlign: TextAlign.center,
          style: AppleDesign.caption.copyWith(
            color: issue != null
                ? AppleDesign.statusPending.resolveFrom(context)
                : secondary,
          ),
        ),
      ],
    );
  }
}
