import 'dart:typed_data';

enum CheckinQrSaveStatus { savedToGallery, savedToFile, cancelled, stale }

/// Saves a freshly rendered check-in QR PNG so the user can select it from
/// the top of the system photo album inside 智慧北航 on a single phone.
typedef CheckinQrSaver = Future<CheckinQrSaveStatus> Function(
  Uint8List pngBytes, {
  required bool Function() isCurrent,
});
