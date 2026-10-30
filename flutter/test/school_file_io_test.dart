import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/homework_files.dart';
import 'package:ginkgo_mirror/application/file_actions.dart';
import 'package:ginkgo_mirror/infrastructure/homework_file_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final file = HomeworkFileDownload(
    'synthetic.pdf',
    Uint8List.fromList([1, 2]),
  );
  test('stale before selection never asks for a destination', () async {
    var picks = 0;
    final service = SchoolFileSaveService.forTesting((_) async {
      picks++;
      return null;
    });
    final result = await service.save(file, isCurrent: () => false);
    expect(result.status, FileSaveStatus.stale);
    expect(picks, 0);
  });
  test('cancel is distinct from saved and does not open', () async {
    final service = SchoolFileSaveService.forTesting((_) async => null);
    final result = await service.save(file, isCurrent: () => true);
    expect(result.status, FileSaveStatus.cancelled);
    expect(result.canOpen, false);
    expect(await result.open(), FileOpenStatus.unsupported);
  });
  test(
    'late picker after navigation/account change discards without write',
    () async {
      final picker = Completer<SchoolFileDestination?>();
      var current = true, writes = 0, discards = 0;
      final service = SchoolFileSaveService.forTesting((_) => picker.future);
      final pending = service.save(file, isCurrent: () => current);
      current = false;
      picker.complete(
        SchoolFileDestination(
          commit: (_) async {
            writes++;
          },
          discard: () async {
            discards++;
          },
        ),
      );
      expect((await pending).status, FileSaveStatus.stale);
      expect(writes, 0);
      expect(discards, 1);
    },
  );
  test(
    'save snapshots mutable bytes; open is explicit and rechecks current',
    () async {
      final picker = Completer<SchoolFileDestination?>();
      var current = true, opens = 0;
      Uint8List? written;
      final mutable = HomeworkFileDownload(
        'test.pdf',
        Uint8List.fromList([1, 2]),
      );
      final service = SchoolFileSaveService.forTesting((_) => picker.future);
      final pending = service.save(mutable, isCurrent: () => current);
      mutable.bytes[0] = 99;
      picker.complete(
        SchoolFileDestination(
          commit: (bytes) async {
            written = bytes;
          },
          discard: () async {},
          open: () async {
            opens++;
            return FileOpenStatus.opened;
          },
        ),
      );
      final saved = await pending;
      expect(saved.status, FileSaveStatus.saved);
      expect(written, [1, 2]);
      expect(saved.canOpen, true);
      expect(opens, 0);
      expect(await saved.open(), FileOpenStatus.opened);
      expect(opens, 1);
      current = false;
      expect(await saved.open(), FileOpenStatus.stale);
      expect(opens, 1);
    },
  );
  test('write failure is not cancelled or successful', () async {
    final service = SchoolFileSaveService.forTesting(
      (_) async => SchoolFileDestination(
        commit: (_) async => throw StateError('synthetic failure'),
        discard: () async {},
      ),
    );
    await expectLater(
      service.save(file, isCurrent: () => true),
      throwsStateError,
    );
  });
  test(
    'change during authorized commit suppresses opening and stale result',
    () async {
      var current = true, opens = 0;
      final service = SchoolFileSaveService.forTesting(
        (_) async => SchoolFileDestination(
          commit: (_) async {
            current = false;
          },
          discard: () async {},
          open: () async {
            opens++;
            return FileOpenStatus.opened;
          },
        ),
      );
      final result = await service.save(
        file,
        isCurrent: () => current,
        openAfterSave: true,
      );
      expect(result.status, FileSaveStatus.stale);
      expect(opens, 0);
    },
  );
  test('open failure and absent handler are explicit', () async {
    final service = SchoolFileSaveService.forTesting(
      (_) async => SchoolFileDestination(
        commit: (_) async {},
        discard: () async {},
        open: () async => throw StateError('synthetic'),
      ),
    );
    expect(
      await (await service.save(file, isCurrent: () => true)).open(),
      FileOpenStatus.unavailable,
    );
    expect(
      await const FileSaveResult.saved().open(),
      FileOpenStatus.unsupported,
    );
  });
  test(
    'filename sanitization has no paths, controls, or reserved DOS name',
    () {
      expect(safeSchoolFileName('../a\\b\u0000.pdf'), '.._a_b_.pdf');
      expect(safeSchoolFileName('CON.txt'), '_CON.txt');
      expect(safeSchoolFileName('..'), '下载文件');
      expect(safeSchoolFileName('a' * 300).length, 200);
    },
  );
  group('Android channel contract without real files', () {
    const channel = MethodChannel('cn.edu.buaa.ginkgo/homework-files');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });
    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });
    test(
      'select transmits only name; commit/open use picker token, never URI',
      () async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'select' => 'opaque-synthetic',
            'open' => 'opened',
            _ => null,
          };
        });
        final result = await saveAndOpenSchoolFile(file, isCurrent: () => true);
        expect(calls.map((c) => c.method), ['select', 'commit']);
        expect((calls[0].arguments as Map).keys, ['name']);
        expect((calls[1].arguments as Map).keys.toSet(), {'token', 'bytes'});
        expect(await result.open(), FileOpenStatus.opened);
        expect(calls.last.arguments, {'token': 'opaque-synthetic'});
      },
    );
    test(
      'late native picker capability is discarded, never committed',
      () async {
        final selection = Completer<String?>();
        final calls = <String>[];
        var current = true;
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return call.method == 'select' ? selection.future : null;
        });
        final pending = saveAndOpenSchoolFile(file, isCurrent: () => current);
        await Future<void>.delayed(Duration.zero);
        current = false;
        selection.complete('opaque-synthetic');
        expect((await pending).status, FileSaveStatus.stale);
        expect(calls, ['select', 'discard']);
      },
    );
  });
}
