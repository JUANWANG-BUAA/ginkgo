import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:ginkgo_mirror/application/reminder_store.dart';
import 'package:path_provider/path_provider.dart';

/// Stores the existing account-digest-named reminder document atomically.
class FileReminderStore implements ReminderStore {
  FileReminderStore(String account, {Future<Directory> Function()? directory})
    : accountDigest = sha256
          .convert(utf8.encode('$account:account'))
          .toString(),
      _directory = directory ?? getApplicationSupportDirectory;

  final String accountDigest;
  final Future<Directory> Function() _directory;
  static final Map<String, Future<void>> _queues = {};

  Future<T> _ordered<T>(Future<T> Function() operation) {
    final prior = _queues[accountDigest] ?? Future<void>.value();
    final result = prior.then((_) => operation());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _queues[accountDigest] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_queues[accountDigest], tail)) {
          _queues.remove(accountDigest);
        }
      }),
    );
    return result;
  }

  Future<File> _file() async =>
      File('${(await _directory()).path}/reminders-$accountDigest.json');

  @override
  Future<String?> read() => _ordered(() async {
    final file = await _file();
    return await file.exists() ? file.readAsString() : null;
  });

  @override
  Future<void> write(String data) => _ordered(() async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(data, flush: true);
    await temp.rename(file.path);
  });
}
