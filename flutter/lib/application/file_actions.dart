import 'package:cross_file/cross_file.dart';

import 'package:ginkgo_mirror/application/homework_files.dart';

/// Local file actions the presentation layer needs. The composition root binds
/// the real implementations; a page never names one, because a page that
/// reaches for the platform on its own owns a different capability than the
/// workspace it belongs to.
typedef HomeworkFilePicker = Future<XFile?> Function();

/// Saves the file the user chose. The commit is the authorization point: a
/// completed or in-flight write cannot be recalled by navigation.
typedef HomeworkFileSave = Future<FileSaveResult> Function(
  HomeworkFileDownload file, {
  required bool Function() isCurrent,
  bool openAfterSave,
});

enum FileSaveStatus { saved, cancelled, stale }

enum FileOpenStatus { opened, unsupported, unavailable, stale }

/// Contains a local capability only, never a school URL, credential or raw URI.
class FileSaveResult {
  const FileSaveResult.saved({Future<FileOpenStatus> Function()? opener})
    : status = FileSaveStatus.saved,
      // Named public callback initializes a deliberately private capability.
      // ignore: prefer_initializing_formals
      _opener = opener;
  const FileSaveResult.cancelled()
    : status = FileSaveStatus.cancelled,
      _opener = null;
  const FileSaveResult.stale() : status = FileSaveStatus.stale, _opener = null;

  final FileSaveStatus status;
  final Future<FileOpenStatus> Function()? _opener;
  bool get canOpen => status == FileSaveStatus.saved && _opener != null;
  Future<FileOpenStatus> open() async =>
      await _opener?.call() ?? FileOpenStatus.unsupported;
}
