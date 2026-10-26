import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/homework_files.dart';

typedef HomeworkFilePicker = Future<XFile?> Function();
typedef HomeworkFileSaver = Future<void> Function(HomeworkFileDownload file);
typedef SchoolFileSaver = Future<FileSaveResult> Function(
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

Future<XFile?> pickHomeworkFile() => openFile();

/// Compatibility only. New callers must supply their page/account guard.
Future<void> saveHomeworkFile(HomeworkFileDownload file) async {
  await saveAndOpenSchoolFile(file, isCurrent: () => true);
}

Future<FileSaveResult> saveAndOpenSchoolFile(
  HomeworkFileDownload file, {
  required bool Function() isCurrent,
  bool openAfterSave = false,
}) => const SchoolFileSaveService().save(
  file,
  isCurrent: isCurrent,
  openAfterSave: openAfterSave,
);

/// Selection and byte commit are separate so a dismissed page/account never
/// writes bytes to a late picker result. The commit is the authorization point:
/// a completed/in-flight authorized write cannot be recalled by navigation.
class SchoolFileSaveService {
  const SchoolFileSaveService() : _select = _selectDestination;
  @visibleForTesting
  const SchoolFileSaveService.forTesting(SchoolFileDestinationPicker select)
    : _select = select;

  final SchoolFileDestinationPicker _select;
  Future<FileSaveResult> save(
    HomeworkFileDownload file, {
    required bool Function() isCurrent,
    bool openAfterSave = false,
  }) async {
    if (!isCurrent()) return const FileSaveResult.stale();
    if (file.bytes.length > 20 * 1024 * 1024) {
      throw ArgumentError('文件超过本机保存大小限制');
    }
    final name = safeSchoolFileName(file.name);
    // Keep a snapshot while the picker is awaiting user input.
    final bytes = Uint8List.fromList(file.bytes);
    final target = await _select(name);
    if (target == null) {
      return isCurrent()
          ? const FileSaveResult.cancelled()
          : const FileSaveResult.stale();
    }
    if (!isCurrent()) {
      await target.discard();
      return const FileSaveResult.stale();
    }
    try {
      // No await between the guard and starting this one-use commit.
      await target.commit(bytes);
    } catch (_) {
      await target.discard();
      rethrow;
    }
    if (!isCurrent()) {
      await target.discard();
      return const FileSaveResult.stale();
    }
    final result = FileSaveResult.saved(
      opener: target.open == null
          ? null
          : () async {
              if (!isCurrent()) return FileOpenStatus.stale;
              try {
                return await target.open!();
              } catch (_) {
                return FileOpenStatus.unavailable;
              }
            },
    );
    if (openAfterSave && result.canOpen) await result.open();
    return result;
  }
}

@visibleForTesting
typedef SchoolFileDestinationPicker = Future<SchoolFileDestination?> Function(
  String suggestedName,
);

/// Opaque local selection capability. Production never accepts a caller URI.
@visibleForTesting
class SchoolFileDestination {
  const SchoolFileDestination({
    required this.commit,
    required this.discard,
    this.open,
  });
  final Future<void> Function(Uint8List bytes) commit;
  final Future<void> Function() discard;
  final Future<FileOpenStatus> Function()? open;
}

String safeSchoolFileName(String raw) {
  var name = raw.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f\x7f]'), '_').trim();
  name = name.replaceAll(RegExp(r'[. ]+$'), '');
  if (name.isEmpty || name == '.' || name == '..') name = '下载文件';
  if (RegExp(
    r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)',
    caseSensitive: false,
  ).hasMatch(name)) {
    name = '_$name';
  }
  if (name.length > 200) name = name.substring(0, 200);
  return name;
}

const _files = MethodChannel('cn.edu.buaa.ginkgo/homework-files');
Future<SchoolFileDestination?> _selectDestination(String name) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    final token = await _files.invokeMethod<String>('select', {'name': name});
    if (token == null) return null;
    return SchoolFileDestination(
      commit: (bytes) =>
          _files.invokeMethod<void>('commit', {'token': token, 'bytes': bytes}),
      discard: () => _files.invokeMethod<void>('discard', {'token': token}),
      open: () async {
        final status = await _files.invokeMethod<String>('open', {
          'token': token,
        });
        return switch (status) {
          'opened' => FileOpenStatus.opened,
          'unsupported' => FileOpenStatus.unsupported,
          _ => FileOpenStatus.unavailable,
        };
      },
    );
  }
  final destination = await getSaveLocation(suggestedName: name);
  if (destination == null) return null;
  return SchoolFileDestination(
    commit: (bytes) =>
        XFile.fromData(bytes, name: name).saveTo(destination.path),
    discard: () async {},
    // Windows uses the plugin's ShellExecute URL API, never command strings.
    open: defaultTargetPlatform != TargetPlatform.windows
        ? null
        : () async {
            final uri = Uri.file(destination.path, windows: true);
            final opened = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            return opened ? FileOpenStatus.opened : FileOpenStatus.unavailable;
          },
  );
}
