import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/checkin_qr.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/failure_message.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/features/checkin/checkin_qr_render.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

export 'package:ginkgo_mirror/features/checkin/checkin_qr_render.dart';

/// Live classroom QR modal for scanning in 智慧北航 (either from another screen,
/// via single-phone album overwrite + app jump, or via silent notification-shade
/// refresh while staying inside 智慧北航's scanner screen).
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
  bool _inBackground = false;
  int _serial = 0;
  CheckinScannerHost _scannerHost = CheckinScannerHost.none;
  CheckinQuickNotificationStatus? _quickNotificationStatus;

  CheckinQrQuickHelper? get _helper =>
      widget.service.isDemo ? null : widget.platformActions.checkinQrHelper;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final helper = _helper;
    if (helper != null) {
      helper.setRefreshFromNotificationHandler(_refreshAndSaveFromNotification);
      unawaited(_probeScannerHost(helper));
    }
    unawaited(_fetchQr(revalidateCourse: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    final helper = _helper;
    if (helper != null) {
      helper.setRefreshFromNotificationHandler(null);
      unawaited(helper.dismissQuickNotification());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _inBackground = true;
      _refreshTimer?.cancel();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _inBackground = false;
      if (mounted && !_confirmedSigned && widget.isContextValid()) {
        unawaited(_verifyStatus(automatic: true));
        final seconds = _ticket?.refreshSeconds ?? 0;
        if (seconds > 0) {
          _scheduleAutoRefresh(seconds);
        }
      }
    }
  }

  Future<void> _probeScannerHost(CheckinQrQuickHelper helper) async {
    final host = await helper.probeScannerApp();
    if (!mounted || !widget.isContextValid()) return;
    if (host != _scannerHost) {
      setState(() => _scannerHost = host);
    }
  }

  Future<void> _ensureQuickNotification({String? statusText}) async {
    final helper = _helper;
    if (helper == null || _confirmedSigned) return;
    final status = await helper.showQuickNotification(statusText: statusText);
    if (!mounted || !widget.isContextValid()) return;
    if (_quickNotificationStatus != status) {
      setState(() => _quickNotificationStatus = status);
    }
  }

  void _scheduleAutoRefresh(int seconds) {
    _refreshTimer?.cancel();
    if (widget.service.isDemo ||
        _confirmedSigned ||
        _inBackground ||
        seconds <= 0) {
      return;
    }
    _refreshTimer = Timer.periodic(Duration(seconds: seconds), (_) {
      if (!mounted || !widget.isContextValid() || _inBackground) {
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

  Future<CheckInQrResponse?> _fetchQr({
    required bool revalidateCourse,
    int offsetMs = 0,
  }) async {
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
        offsetMs: offsetMs,
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
      if (_quickNotificationStatus == null && _helper != null) {
        unawaited(_ensureQuickNotification());
      }
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

  Future<void> _saveToAlbum({bool launchScanner = false}) async {
    final saver = widget.platformActions.checkinQrSaver;
    if (saver == null || _saving || !widget.isContextValid()) return;
    setState(() {
      _saving = true;
      _feedback = null;
    });
    try {
      final latest =
          await _fetchQr(
            revalidateCourse: false,
            offsetMs: kCheckinQrSaveOffsetMs,
          ) ??
          _ticket;
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
      if (status == CheckinQrSaveStatus.savedToGallery) {
        final clock = schoolClockLabel(latest.fetchedAt);
        unawaited(
          _ensureQuickNotification(
            statusText: '已于 $clock 存入相册首图（+2秒缓冲），可在扫一扫页直接选图或再次点此刷新',
          ),
        );
        if (launchScanner && _helper != null) {
          final launched = await _helper!.launchScannerApp();
          if (!mounted || !widget.isContextValid()) return;
          setState(() {
            _feedback = launched != CheckinScannerHost.none
                ? '已存相册首图（+2秒缓冲）并打开${launched.displayName}，扫一扫页可下拉通知栏秒刷新'
                : '已存至系统相册首张，请打开智慧北航扫一扫并从相册选择';
          });
          return;
        }
      }
      setState(() {
        _feedback = switch (status) {
          CheckinQrSaveStatus.savedToGallery =>
            '已存至系统相册首张（+2秒缓冲），可在智慧北航扫一扫中选择',
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

  Future<void> _refreshAndSaveFromNotification() async {
    final saver = widget.platformActions.checkinQrSaver;
    if (saver == null ||
        _saving ||
        _confirmedSigned ||
        !mounted ||
        !widget.isContextValid()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final latest = await _fetchQr(
        revalidateCourse: false,
        offsetMs: kCheckinQrSaveOffsetMs,
      );
      if (!mounted || !widget.isContextValid()) return;
      if (latest == null) {
        unawaited(_ensureQuickNotification(statusText: '刷新签到码失败，请点击重试或返回核对'));
        return;
      }
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
      final clock = schoolClockLabel(latest.fetchedAt);
      if (status == CheckinQrSaveStatus.savedToGallery) {
        setState(() => _feedback = '已通过通知栏于 $clock 刷新相册首图（+2秒缓冲）');
        unawaited(
          _ensureQuickNotification(
            statusText: '已于 $clock 刷新相册首图（+2秒缓冲），请在相册选第一张',
          ),
        );
      } else {
        unawaited(_ensureQuickNotification(statusText: '写入相册未完成，请重试'));
      }
    } catch (_) {
      unawaited(_ensureQuickNotification(statusText: '刷新签到码失败，请稍后重试'));
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
        unawaited(_helper?.dismissQuickNotification());
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
    final canLaunchScanner =
        !widget.service.isDemo && _scannerHost != CheckinScannerHost.none;

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
                        ? const CheckinQrConfirmedView()
                        : CheckinQrDisplayCard(
                            courseName: widget.course.courseName,
                            ticket: ticket,
                            loadingQr: _loadingQr,
                            isDemo: widget.service.isDemo,
                            issue: _issue,
                            secondary: secondary,
                            onRetry: () => _fetchQr(revalidateCourse: true),
                          ),
                  ),
                  if (!_confirmedSigned && _quickNotificationStatus != null) ...[
                    const SizedBox(height: GinkgoSpacing.sm),
                    CheckinQrQuickHelperBanner(
                      status: _quickNotificationStatus!,
                      secondary: secondary,
                    ),
                  ],
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
                          : () => _saveToAlbum(launchScanner: canLaunchScanner),
                      child: _saving
                          ? const GinkgoActivity()
                          : Text(
                              canLaunchScanner
                                  ? '存相册并打开${_scannerHost.displayName}'
                                  : '保存到相册（单机扫码）',
                            ),
                    ),
                    const SizedBox(height: GinkgoSpacing.sm),
                  ],
                  if (!_confirmedSigned)
                    canLaunchScanner && saverAvailable
                        ? Row(
                            children: [
                              Expanded(
                                child: CupertinoButton.tinted(
                                  key: const Key('checkin-qr-save-only'),
                                  padding: GinkgoSpacing.edgeInsetsListTile,
                                  onPressed:
                                      _saving || (ticket == null && _loadingQr)
                                      ? null
                                      : () =>
                                            _saveToAlbum(launchScanner: false),
                                  child: const Text('仅存相册'),
                                ),
                              ),
                              const SizedBox(width: GinkgoSpacing.sm),
                              Expanded(
                                child: CupertinoButton.tinted(
                                  key: const Key('checkin-qr-verify'),
                                  padding: GinkgoSpacing.edgeInsetsListTile,
                                  onPressed: _verifying
                                      ? null
                                      : () => _verifyStatus(),
                                  child: _verifying
                                      ? const GinkgoActivity()
                                      : const Text('核对结果'),
                                ),
                              ),
                            ],
                          )
                        : CupertinoButton.tinted(
                            key: const Key('checkin-qr-verify'),
                            onPressed: _verifying
                                ? null
                                : () => _verifyStatus(),
                            child: _verifying
                                ? const GinkgoActivity()
                                : const Text('我已扫码，核对结果'),
                          ),
                  const SizedBox(height: GinkgoSpacing.sm),
                  Text(
                    widget.service.isDemo
                        ? '演示模式仅展示合成二维码，不会连接学校服务。'
                        : '技巧：先打开智慧北航“扫一扫”就绪，再下拉通知栏点“刷新码到相册”并选首张图，2 秒完成；走移动流量需先连学校 VPN1。',
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
}
