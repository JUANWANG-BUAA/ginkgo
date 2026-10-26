import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/infrastructure/learning_snapshot_store.dart';

class Store implements LearningSnapshotStore {
  @override
  bool supported = true;
  bool consent = false, corrupt = false, failSave = false;
  int saves = 0, loads = 0, clears = 0;
  Uint8List? bytes;
  @override
  Future<bool> enabled() async => consent;
  @override
  Future<void> enable() async {
    consent = true;
  }

  @override
  Future<Uint8List?> load() async {
    loads++;
    if (corrupt) throw StateError('corrupt');
    return bytes;
  }

  @override
  Future<void> save(Uint8List value) async {
    if (failSave) throw StateError('unavailable');
    saves++;
    bytes = value;
  }

  @override
  Future<void> clear() async {
    clears++;
    consent = false;
    bytes = null;
  }
}

const success = ReadOnlyResponse(stale: false, payload: '[]');
void main() {
  test(
    'disabled storage does not load save or suppress normal reads',
    () async {
      final store = Store();
      final c = LearningSnapshotCoordinator(
        store: store,
        export: (_) async => Uint8List(1),
        restore: (_, _) async {},
      );
      var reads = 0;
      await c.read('a', () async {
        reads++;
        return success;
      });
      expect(reads, 1);
      expect(store.loads, 0);
      expect(store.saves, 0);
    },
  );
  test('enable is explicit and failures never extend archive age', () async {
    final store = Store();
    final c = LearningSnapshotCoordinator(
      store: store,
      export: (_) async => Uint8List.fromList([1]),
      restore: (_, _) async {},
    );
    expect((await c.setEnabled('a', true)).enabled, isTrue);
    expect(store.saves, 1);
    await c.read(
      'a',
      () async => const ReadOnlyResponse(
        stale: true,
        failure: FailureCode.serviceUnavailable,
      ),
    );
    expect(store.saves, 1);
    await c.read('a', () async => success);
    expect(store.saves, 2);
    await c.clear();
    expect(store.consent, isFalse);
    expect(store.bytes, isNull);
  });
  test(
    'corrupt or foreign archive is never overwritten by next successful read',
    () async {
      final store = Store()
        ..consent = true
        ..bytes = Uint8List(2);
      final c = LearningSnapshotCoordinator(
        store: store,
        export: (_) async => Uint8List(1),
        restore: (_, _) async => throw StateError('foreign'),
      );
      await c.read('b', () async => success);
      expect(store.saves, 0);
      expect(c.message, isNotNull);
    },
  );
  test('clear waits for in-flight save then removes all data', () async {
    final store = Store();
    final c = LearningSnapshotCoordinator(
      store: store,
      export: (_) async => Uint8List(1),
      restore: (_, _) async {},
    );
    await c.setEnabled('a', true);
    final pending = Completer<ReadOnlyResponse>();
    final reading = c.read('a', () => pending.future);
    final clearing = c.clear();
    pending.complete(success);
    await reading;
    await clearing;
    expect(store.bytes, isNull);
    expect(store.consent, isFalse);
  });
  test(
    'new coordinator can adopt encrypted archive only through Rust validator',
    () async {
      final store = Store()
        ..consent = true
        ..bytes = Uint8List.fromList([1, 2]);
      var adopted = 0;
      final c = LearningSnapshotCoordinator(
        store: store,
        export: (_) async => Uint8List(1),
        restore: (account, bytes) async {
          expect(account, 'a');
          expect(bytes, [1, 2]);
          adopted++;
        },
      );
      await c.read(
        'a',
        () async => const ReadOnlyResponse(
          stale: true,
          failure: FailureCode.serviceUnavailable,
        ),
      );
      expect(adopted, 1);
      expect(store.saves, 0);
    },
  );
}
