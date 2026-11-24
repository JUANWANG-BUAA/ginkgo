import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:ginkgo_mirror/application/checkin_qr.dart';
import 'package:ginkgo_mirror/application/file_actions.dart';
import 'package:ginkgo_mirror/application/homework_files.dart';
import 'package:ginkgo_mirror/infrastructure/homework_file_io.dart';

const _checkinQrChannel = MethodChannel('cn.edu.buaa.ginkgo/checkin-qr');

Future<CheckinQrSaveStatus> saveCheckinQrPng(
  Uint8List pngBytes, {
  required bool Function() isCurrent,
}) async {
  if (!isCurrent()) return CheckinQrSaveStatus.stale;
  if (defaultTargetPlatform == TargetPlatform.android) {
    final outcome = await _checkinQrChannel.invokeMethod<String>('savePng', {
      'bytes': pngBytes,
    });
    if (!isCurrent()) return CheckinQrSaveStatus.stale;
    if (outcome == 'saved') return CheckinQrSaveStatus.savedToGallery;
  }
  final fallback = await saveAndOpenSchoolFile(
    HomeworkFileDownload('ginkgo_checkin_qr.png', pngBytes),
    isCurrent: isCurrent,
  );
  return switch (fallback.status) {
    FileSaveStatus.saved => CheckinQrSaveStatus.savedToFile,
    FileSaveStatus.cancelled => CheckinQrSaveStatus.cancelled,
    FileSaveStatus.stale => CheckinQrSaveStatus.stale,
  };
}

class AndroidCheckinQrQuickHelper implements CheckinQrQuickHelper {
  AndroidCheckinQrQuickHelper._();

  static final AndroidCheckinQrQuickHelper shared =
      AndroidCheckinQrQuickHelper._();

  Future<void> Function()? _refreshHandler;
  bool _channelListening = false;

  bool get _supported => defaultTargetPlatform == TargetPlatform.android;

  void _ensureListening() {
    if (_channelListening || !_supported) return;
    _channelListening = true;
    _checkinQrChannel.setMethodCallHandler((call) async {
      if (call.method == 'refreshAndSaveFromNotification') {
        final handler = _refreshHandler;
        if (handler != null) {
          await handler();
        }
      }
      return null;
    });
  }

  @override
  Future<CheckinScannerHost> probeScannerApp() async {
    if (!_supported) return CheckinScannerHost.none;
    try {
      final result = await _checkinQrChannel.invokeMethod<String>(
        'probeScannerApp',
      );
      return _parseScannerHost(result);
    } catch (_) {
      return CheckinScannerHost.none;
    }
  }

  @override
  Future<CheckinScannerHost> launchScannerApp() async {
    if (!_supported) return CheckinScannerHost.none;
    try {
      final result = await _checkinQrChannel.invokeMethod<String>(
        'launchScannerApp',
      );
      return _parseScannerHost(result);
    } catch (_) {
      return CheckinScannerHost.none;
    }
  }

  @override
  Future<CheckinQuickNotificationStatus> showQuickNotification({
    String? statusText,
  }) async {
    if (!_supported) return CheckinQuickNotificationStatus.unavailable;
    _ensureListening();
    try {
      final result = await _checkinQrChannel.invokeMethod<String>(
        'showQuickNotification',
        {'statusText': statusText},
      );
      return switch (result) {
        'shown' => CheckinQuickNotificationStatus.shown,
        'permission_denied' => CheckinQuickNotificationStatus.permissionDenied,
        _ => CheckinQuickNotificationStatus.unavailable,
      };
    } catch (_) {
      return CheckinQuickNotificationStatus.unavailable;
    }
  }

  @override
  Future<void> dismissQuickNotification() async {
    if (!_supported) return;
    try {
      await _checkinQrChannel.invokeMethod<bool>('dismissQuickNotification');
    } catch (_) {}
  }

  @override
  void setRefreshFromNotificationHandler(Future<void> Function()? handler) {
    _refreshHandler = handler;
    if (handler != null) {
      _ensureListening();
    }
  }

  static CheckinScannerHost _parseScannerHost(String? raw) => switch (raw) {
    'ibuaa' => CheckinScannerHost.ibuaa,
    'wecom' => CheckinScannerHost.wecom,
    _ => CheckinScannerHost.none,
  };
}
