import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/checkin_qr.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/failure_message.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

/// Live classroom QR modal for scanning in 智慧北航 (either from another screen
/// or by saving to the top of the system photo album on a single phone).
class CheckinQrSheet extends StatefulWidget {
  const CheckinQrSheet({
    super.key,
    required this.course,
    required this.dateLabel,
    required this.service,
    required this.platformActions,
    required this.isContextValid,
    required this.onVerifySigned,
  });

  final CheckInCourse course;
  final String dateLabel;
  final CheckInGateway service;
  final PlatformActions platformActions;
  final bool Function() isContextValid;
  final Future<bool> Function() onVerifySigned;

  @override
  State<CheckinQrSheet> createState() => _CheckinQrSheetState();
}

class _CheckinQrSheetState extends State<CheckinQrSheet>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  CheckInQrResponse? _ticket;
  String? _issue;
  String? _feedback;
  bool _loadingQr = true;
  bool _saving = false;
  bool _verifying = false;
  bool _confirmedSigned = false;
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_fetchQr(revalidateCourse: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        !_confirmedSigned &&
        widget.isContextValid()) {
      unawaited(_verifyStatus(automatic: true));
    }
  }

  void _scheduleAutoRefresh(int seconds) {
    _refreshTimer?.cancel();
    if (widget.service.isDemo || _confirmedSigned || seconds <= 0) return;
    _refreshTimer = Timer.periodic(Duration(seconds: seconds), (_) {
      if (!mounted || !widget.isContextValid()) {
        _refreshTimer?.cancel();
        return;
      }
      if (!_loadingQr && !_saving && !_verifying) {
        unawaited(_fetchQr(revalidateCourse: false));
      }
    });
  }

  String _describeQrFailure(FailureCode code, String? detail) =>
      switch (detail) {
        'already_signed' => '该课程已完成签到，请点击下方核对结果',
        'outside_window' => '课前 10 分钟开放签到，课程结束后关闭',
        'course_changed' => '当天课程已变更，请关闭后重新核对列表',
        'status_unconfirmed' => '课程记录冲突或待确认，无法生成签到码',
        _ when code == FailureCode.moduleAuthRequired =>
          'iClass 认证尚未完成，请稍后重试',
        _ => failureMessage(code),
      };

  Future<CheckInQrResponse?> _fetchQr({required bool revalidateCourse}) async {
    if (!widget.isContextValid()) return null;
    final current = ++_serial;
    setState(() {
      _loadingQr = true;
      if (_ticket == null) _issue = null;
    });
    try {
      final response = await widget.service.prepareCheckinQr(
        widget.course.id,
        revalidateCourse: revalidateCourse,
      );
      if (!mounted || current != _serial || !widget.isContextValid()) {
        return null;
      }
      if (response.failure != null || response.modules.isEmpty) {
        final detail = response.failureDetail;
        if (detail == 'already_signed') {
          unawaited(_verifyStatus(automatic: true));
        }
        setState(() {
          _loadingQr = false;
          _issue = _describeQrFailure(
            response.failure ?? FailureCode.serviceUnavailable,
            detail,
          );
        });
        return null;
      }
      setState(() {
        _loadingQr = false;
        _issue = null;
        _ticket = response;
      });
      _scheduleAutoRefresh(response.refreshSeconds);
      return response;
    } catch (_) {
      if (!mounted || current != _serial || !widget.isContextValid()) {
        return null;
      }
      setState(() {
        _loadingQr = false;
        _issue = failureMessage(null);
      });
      return null;
    }
  }

  Future<void> _saveToAlbum() async {
    final saver = widget.platformActions.checkinQrSaver;
    if (saver == null || _saving || !widget.isContextValid()) return;
    setState(() {
      _saving = true;
      _feedback = null;
    });
    try {
      // Mint a fresh timestamp right before saving so single-phone album scans
      // carry the widest remaining validity window.
      final latest = await _fetchQr(revalidateCourse: false) ?? _ticket;
      if (!mounted || !widget.isContextValid() || latest == null) return;
      final png = await renderCheckinQrPng(
        matrixSize: latest.matrixSize,
        modules: latest.modules,
      );
      if (!mounted || !widget.isContextValid()) return;
      final status = await saver(
        png,
        isCurrent: () => mounted && widget.isContextValid(),
      );
      if (!mounted || !widget.isContextValid()) return;
      setState(() {
        _feedback = switch (status) {
          CheckinQrSaveStatus.savedToGallery =>
            '已存至系统相册首张，请打开智慧北航扫一扫并从相册选择',
          CheckinQrSaveStatus.savedToFile => '已保存签到码图片，可在智慧北航扫一扫中选择',
          CheckinQrSaveStatus.cancelled || CheckinQrSaveStatus.stale => null,
        };
      });
    } catch (_) {
      if (!mounted || !widget.isContextValid()) return;
      setState(() => _feedback = '保存签到码失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _verifyStatus({bool automatic = false}) async {
    if (_verifying || !widget.isContextValid()) return;
    setState(() {
      _verifying = true;
      if (!automatic) _feedback = null;
    });
    try {
      final signed = await widget.onVerifySigned();
      if (!mounted || !widget.isContextValid()) return;
      if (signed) {
        _refreshTimer?.cancel();
        setState(() {
          _confirmedSigned = true;
          _issue = null;
          _feedback = '学校已确认签到成功';
        });
      } else if (!automatic) {
        setState(() => _feedback = '当前仍为未签到，请在智慧北航完成扫码后再核对');
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final background = CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    );
    final cardColor = CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final ticket = _ticket;
    final saverAvailable = widget.platformActions.checkinQrSaver != null;

    return Container(
      key: const Key('checkin-qr-sheet'),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppleDesign.panelRadius(context)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: GinkgoSpacing.edgeInsetsCard,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: GinkgoLayout.formMaxWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.course.courseName,
                          style: AppleDesign.headline.copyWith(
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                      ),
                      CupertinoButton(
                        key: const Key('checkin-qr-close'),
                        padding: GinkgoSpacing.edgeInsetsPickerCompactAction,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                  Text(
                    [
                      widget.dateLabel,
                      schoolTimeRange(
                        widget.course.beginsAt,
                        widget.course.endsAt,
                      ),
                      if (widget.course.classroomName != null)
                        widget.course.classroomName!,
                    ].join(' · '),
                    style: AppleDesign.footnote.copyWith(color: secondary),
                  ),
                  const SizedBox(height: GinkgoSpacing.md),
                  Container(
                    padding: GinkgoSpacing.edgeInsetsCard,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(GinkgoRadii.group),
                    ),
                    child: _confirmedSigned
                        ? _buildConfirmedView(context)
                        : _buildQrContent(context, ticket, secondary),
                  ),
                  if (_feedback != null) ...[
                    const SizedBox(height: GinkgoSpacing.sm),
                    Text(
                      _feedback!,
                      textAlign: TextAlign.center,
                      style: AppleDesign.footnote.copyWith(
                        color: _confirmedSigned
                            ? AppleDesign.statusSuccess.resolveFrom(context)
                            : secondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: GinkgoSpacing.md),
                  if (!_confirmedSigned && saverAvailable) ...[
                    CupertinoButton.filled(
                      key: const Key('checkin-qr-save'),
                      onPressed: _saving || (ticket == null && _loadingQr)
                          ? null
                          : _saveToAlbum,
                      child: _saving
                          ? const GinkgoActivity()
                          : const Text('保存到相册（单机扫码）'),
                    ),
                    const SizedBox(height: GinkgoSpacing.sm),
                  ],
                  if (!_confirmedSigned)
                    CupertinoButton.tinted(
                      key: const Key('checkin-qr-verify'),
                      onPressed: _verifying ? null : () => _verifyStatus(),
                      child: _verifying
                          ? const GinkgoActivity()
                          : const Text('我已扫码，核对结果'),
                    ),
                  const SizedBox(height: GinkgoSpacing.sm),
                  Text(
                    widget.service.isDemo
                        ? '演示模式仅展示合成二维码，不会连接学校服务。'
                        : '请在智慧北航内打开智慧课堂“我的 → 扫一扫”并从相册选择首张图；使用移动流量时需先连接学校 VPN1 客户端。',
                    textAlign: TextAlign.center,
                    style: AppleDesign.caption.copyWith(color: secondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmedView(BuildContext context) {
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

  Widget _buildQrContent(
    BuildContext context,
    CheckInQrResponse? ticket,
    Color secondary,
  ) {
    if (ticket == null) {
      if (_loadingQr) {
        return const Padding(
          padding: GinkgoSpacing.edgeInsetsBalanceHero,
          child: Center(child: GinkgoActivity()),
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _issue ?? '暂时无法生成签到码',
            textAlign: TextAlign.center,
            style: AppleDesign.subheadline.copyWith(
              color: AppleDesign.statusDanger.resolveFrom(context),
            ),
          ),
          const SizedBox(height: GinkgoSpacing.sm),
          CupertinoButton.tinted(
            key: const Key('checkin-qr-retry'),
            onPressed: _loadingQr
                ? null
                : () => _fetchQr(revalidateCourse: true),
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
              label: '${widget.course.courseName} 实时签到二维码',
              image: true,
              child: DecoratedBox(
                key: const Key('checkin-qr-canvas'),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(GinkgoRadii.button),
                ),
                child: CustomPaint(
                  painter: CheckinQrPainter(
                    matrixSize: ticket.matrixSize,
                    modules: ticket.modules,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: GinkgoSpacing.sm),
        Text(
          _issue ??
              (widget.service.isDemo
                  ? '演示二维码已就绪'
                  : '每 ${ticket.refreshSeconds} 秒自动更新 · 时间 ${schoolClockLabel(ticket.fetchedAt)}'),
          textAlign: TextAlign.center,
          style: AppleDesign.caption.copyWith(
            color: _issue != null
                ? AppleDesign.statusPending.resolveFrom(context)
                : secondary,
          ),
        ),
      ],
    );
  }
}

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
