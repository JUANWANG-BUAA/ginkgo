import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ginkgo_mirror/shared/course_visibility.dart';

/// Keeps the existing account-scoped digest list and atomic replacement format.
class CourseVisibilityFileStore {
  CourseVisibilityFileStore(
    this.account, {
    Future<Directory> Function()? supportDirectory,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final String account;
  final Future<Directory> Function() _supportDirectory;

  Future<File> _file() async {
    final directory = await _supportDirectory();
    final digest = sha256.convert(utf8.encode(account));
    return File('${directory.path}/course-visibility-$digest.json');
  }

  Future<Set<String>> read() async {
    final file = await _file();
    if (!await file.exists()) return {};
    final values = jsonDecode(await file.readAsString());
    if (values is! List) {
      throw const FormatException('Course visibility must be a digest list');
    }
    return values
        .whereType<String>()
        .where((value) => RegExp(r'^[a-f0-9]{64}$').hasMatch(value))
        .toSet();
  }

  Future<void> write(Set<String> value) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(value.toList()), flush: true);
    await temporary.rename(file.path);
  }

  CourseVisibility createController() =>
      CourseVisibility(account, load: read, save: write);
}
