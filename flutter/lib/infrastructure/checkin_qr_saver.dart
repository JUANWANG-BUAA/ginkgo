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
