import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Local-only, account-bound preferences. A null selection means defaults;
/// an empty selection is an intentional choice. Unknown IDs are retained.
class WorkspaceShortcutPreferences extends ChangeNotifier {
  WorkspaceShortcutPreferences({
    required this.accountId,
    required this.demo,
    this.storageRoot,
    this.read,
    this.write,
  });

  static const defaultIds = ['checkin', 'schedule', 'homework', 'reservations'];
  static const maxItems = 4;
  final String? accountId;
  final bool demo;
  final String? storageRoot;

  /// Test seams; the widget uses the file backend, not school services.
  final Future<String?> Function()? read;
  final Future<void> Function(String)? write;
  List<String>? _ids;
  List<String>? get ids => _ids;
  bool ready = false;
  bool loading = false;
  bool saving = false;
  String? error;
  bool _disposed = false;

  // Reserve ordering before any async path lookup. A -> B -> A can create a
  // second controller while the first A still writes; its restore must wait
  // for that write rather than reading stale data or being overwritten later.
  static final Map<String, Future<void>> _storageQueues = {};

  Future<T> _orderedStorage<T>(Future<T> Function() operation) {
    final root = storageRoot == null
        ? '<application-support>'
        : Directory(storageRoot!).absolute.path;
    final key = '$root/${sha256.convert(utf8.encode(accountId!))}';
    final previous = _storageQueues[key] ?? Future<void>.value();
    final result = previous.then((_) => operation());
    final settled = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _storageQueues[key] = settled;
    unawaited(
      settled.then((_) {
        if (identical(_storageQueues[key], settled)) _storageQueues.remove(key);
      }),
    );
    return result;
  }

  bool get memoryOnly => demo || accountId == null || accountId!.trim().isEmpty;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  static bool validIds(List<String> ids) =>
      ids.length <= maxItems &&
      ids.toSet().length == ids.length &&
      ids.every(
        (id) =>
            id.isNotEmpty &&
            id.length <= 128 &&
            id.trim() == id &&
            !id.runes.any((rune) => rune < 32 || rune == 127),
      );

  static List<String> decode(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic> ||
        value.length != 2 ||
        value['version'] is! int ||
        value['version'] != 1 ||
        value['ids'] is! List) {
      throw const FormatException('Invalid shortcut preferences');
    }
    final raw = value['ids'] as List;
    if (raw.any((id) => id is! String)) {
      throw const FormatException('Invalid shortcut IDs');
    }
    final ids = raw.cast<String>();
    if (!validIds(ids)) throw const FormatException('Invalid shortcut IDs');
    return List.unmodifiable(ids);
  }

  Future<File> _file() async {
    final root = storageRoot ?? (await getApplicationSupportDirectory()).path;
    final digest = sha256.convert(utf8.encode(accountId!));
    return File('$root/workspace-shortcuts-$digest.json');
  }

  Future<String?> _read() async {
    final file = await _file();
    // A missing file is the only normal fallback. Other I/O or schema errors
    // leave editing locked until an explicit retry succeeds.
    try {
      return await file.readAsString();
    } on FileSystemException catch (error) {
      if (error.osError?.errorCode == 2) return null;
      rethrow;
    }
  }

  Future<void> _write(String source) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    // Unique same-filesystem staging prevents overlapping old/new instances
    // from sharing a temp file. Never delete the previous preference first.
    final staging = await file.parent.createTemp('.workspace-shortcuts-');
    try {
      final temporary = File('${staging.path}/value.json');
      await temporary.writeAsString(source, flush: true);
      await temporary.rename(file.path);
    } finally {
      try {
        await staging.delete(recursive: true);
      } catch (_) {
        debugPrint('Shortcut preference staging cleanup failed');
      }
    }
  }

  Future<void> restore() async {
    if (_disposed || loading || saving || ready) return;
    loading = true;
    error = null;
    _changed();
    try {
      final source = memoryOnly ? null : await _orderedStorage(read ?? _read);
      final restored = source == null ? null : decode(source);
      if (_disposed) return;
      _ids = restored;
      ready = true;
    } catch (_) {
      debugPrint('Shortcut preference read failed');
      if (!_disposed) error = '无法读取常用服务偏好；为保护原设置，暂不能编辑。请重试。';
    } finally {
      loading = false;
      _changed();
    }
  }

  Future<bool> save(List<String> ids) async {
    if (_disposed || !ready || loading || saving) return false;
    if (!validIds(ids)) throw ArgumentError.value(ids, 'ids');
    final snapshot = List<String>.unmodifiable(ids);
    saving = true;
    error = null;
    _changed();
    try {
      if (!memoryOnly) {
        await _orderedStorage(
          () => (write ?? _write)(jsonEncode({'version': 1, 'ids': snapshot})),
        );
      }
      if (_disposed) return false;
      _ids = snapshot;
      return true;
    } catch (_) {
      debugPrint('Shortcut preference write failed');
      if (!_disposed) error = '保存失败，原设置未更改。请重试保存。';
      return false;
    } finally {
      saving = false;
      _changed();
    }
  }
}
