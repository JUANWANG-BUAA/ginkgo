import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persists the app-wide display and session-flow preferences.
///
/// The file format is versioned and contains no credentials or school data.
class DisplayPreferencesFileStore {
  DisplayPreferencesFileStore({Future<Directory> Function()? supportDirectory})
    : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _supportDirectory;

  Future<File> _file() async {
    final directory = await _supportDirectory();
    return File('${directory.path}/display-preferences-v1.json');
  }

  Future<void> write(Map<String, Object> value) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    await temporary.rename(file.path);
  }

  Future<Map<String, Object?>?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;

    final value = jsonDecode(await file.readAsString());
    if (value is Map<String, dynamic>) return Map<String, Object?>.from(value);
    throw const FormatException('Display preferences must be a JSON object');
  }
}
