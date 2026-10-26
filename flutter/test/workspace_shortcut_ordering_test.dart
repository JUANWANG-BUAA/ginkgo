import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/workspace/workspace_shortcut_preferences.dart';

void main() {
  test('A B A reconstruction orders disk reads after old writes, then preserves newer save', () async {
    final root = await Directory.systemTemp.createTemp('shortcut-order-');
    addTearDown(() => root.delete(recursive: true));
    final file = File(
      '${root.path}/workspace-shortcuts-${sha256.convert(utf8.encode('synthetic-a'))}.json',
    );
    await file.writeAsString(
      jsonEncode({
        'version': 1,
        'ids': ['schedule'],
      }),
    );
    final gate = Completer<void>();
    final started = Completer<void>();
    final oldA = WorkspaceShortcutPreferences(
      accountId: 'synthetic-a',
      demo: false,
      storageRoot: root.path,
      write: (value) async {
        started.complete();
        await gate.future;
        await file.writeAsString(value);
      },
    );
    await oldA.restore();
    final oldSave = oldA.save(['homework']);
    await started.future;
    oldA.dispose();
    final b = WorkspaceShortcutPreferences(
      accountId: 'synthetic-b',
      demo: false,
      storageRoot: root.path,
    );
    addTearDown(b.dispose);
    await b.restore();
    expect(await b.save(['tasks']), isTrue);
    final newA = WorkspaceShortcutPreferences(
      accountId: 'synthetic-a',
      demo: false,
      storageRoot: root.path,
    );
    addTearDown(newA.dispose);
    var restored = false;
    final loading = newA.restore().then((_) => restored = true);
    await Future<void>.delayed(Duration.zero);
    expect(restored, isFalse);
    gate.complete();
    await oldSave;
    await loading;
    expect(newA.ids, ['homework']);
    expect(await newA.save(['grades']), isTrue);
    final disk = WorkspaceShortcutPreferences.decode(await file.readAsString());
    expect(disk, ['grades']);
    expect(b.ids, ['tasks']);
  });
}
