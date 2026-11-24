import 'dart:typed_data';

/// Forward timestamp buffer applied when saving a check-in QR to the album or
/// refreshing it from the notification shade so single-phone app switching
/// absorbs ~2s without risking upstream future-timestamp rejection.
const int kCheckinQrSaveOffsetMs = 2000;

enum CheckinQrSaveStatus { savedToGallery, savedToFile, cancelled, stale }

enum CheckinScannerHost { ibuaa, wecom, none }

enum CheckinQuickNotificationStatus { shown, permissionDenied, unavailable }

extension CheckinScannerHostLabel on CheckinScannerHost {
  String get displayName => switch (this) {
    CheckinScannerHost.ibuaa => '智慧北航',
    CheckinScannerHost.wecom => '企业微信',
    CheckinScannerHost.none => '智慧北航',
  };
}

/// Saves a freshly rendered check-in QR PNG so the user can select it from
/// the top of the system photo album inside 智慧北航 on a single phone.
typedef CheckinQrSaver = Future<CheckinQrSaveStatus> Function(
  Uint8List pngBytes, {
  required bool Function() isCurrent,
});

/// Optional Android single-phone check-in QR acceleration port:
/// launches the official scanner host (智慧北航 / 企业微信) and hosts a silent
/// notification-shade refresh button so users never have to leave the scanner.
abstract interface class CheckinQrQuickHelper {
  Future<CheckinScannerHost> probeScannerApp();

  Future<CheckinScannerHost> launchScannerApp();

  Future<CheckinQuickNotificationStatus> showQuickNotification({
    String? statusText,
  });

  Future<void> dismissQuickNotification();

  void setRefreshFromNotificationHandler(Future<void> Function()? handler);
}
