import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../application/contracts.dart';
import '../application/query_snapshots.dart';
import '../src/rust/api/live.dart' as live;

import 'package:ginkgo_mirror/infrastructure/native_command.dart';

/// The only disk adapter is Android Keystore AES-GCM. No plaintext fallback.
abstract interface class LearningSnapshotStore {
  bool get supported;
  Future<bool> enabled();
  Future<void> enable();
  Future<Uint8List?> load();
  Future<void> save(Uint8List bytes);
  Future<void> clear();
}

class AndroidLearningSnapshotStore implements LearningSnapshotStore {
  static const channel = MethodChannel('cn.edu.buaa.ginkgo/learning-snapshots');
  @override
  // Public builds keep this unreviewed optional store unavailable.
  bool get supported => !kReleaseMode && Platform.isAndroid;
  @override
  Future<bool> enabled() async =>
      await channel.invokeMethod<bool>('enabled') ?? false;
  @override
  Future<void> enable() => channel.invokeMethod<void>('enable');
  @override
  Future<Uint8List?> load() => channel.invokeMethod<Uint8List>('load');
  @override
  Future<void> save(Uint8List bytes) =>
      channel.invokeMethod<void>('save', bytes);
  @override
  Future<void> clear() => channel.invokeMethod<void>('clear');
}

/// Serializes disk read/commit with clear and account changes. Native commands
/// still verify the expected account and Rust holds the lifecycle lock.
class LearningSnapshotCoordinator {
  LearningSnapshotCoordinator({
    required this.store,
    required this.export,
    required this.restore,
  });
  final LearningSnapshotStore store;
  final Future<Uint8List> Function(String account) export;
  final Future<void> Function(String account, Uint8List bytes) restore;
  Future<void> _tail = Future.value();
  String? _adoptedAccount;
  String? message;
  bool? _enabled;
  Future<T> _serial<T>(Future<T> Function() work) {
    final result = _tail.then((_) => work());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<LearningSnapshotStatus> status() => _serial(() async {
    if (!store.supported) return const LearningSnapshotStatus(supported: false);
    try {
      _enabled = await store.enabled();
    } catch (_) {
      _enabled = false;
      message = '安全快照状态未能确认，未启用磁盘读取';
    }
    return LearningSnapshotStatus(
      supported: true,
      enabled: _enabled == true,
      message: message,
    );
  });
  Future<LearningSnapshotStatus> setEnabled(
    String account,
    bool enabled,
  ) => _serial(() async {
    if (!store.supported) return const LearningSnapshotStatus(supported: false);
    try {
      if (enabled) {
        // Export proves current authentication before changing consent/disk.
        final bytes = await export(account);
        await store.enable();
        try {
          await store.save(bytes);
        } catch (_) {
          await store.clear();
          rethrow;
        }
        _enabled = true;
        _adoptedAccount = account;
      } else {
        _enabled = false;
        _adoptedAccount = null;
        await store.clear();
      }
      message = null;
    } catch (_) {
      _enabled = false;
      message = '安全快照未启用或清除未完成，请重试；不会回退到明文存储';
    }
    return LearningSnapshotStatus(
      supported: true,
      enabled: _enabled == true,
      message: message,
    );
  });
  Future<void> clear() => _serial(() async {
    _enabled = false;
    _adoptedAccount = null;
    message = null;
    if (store.supported) {
      try {
        await store.clear();
      } catch (_) {
        message = '安全快照清除未完成，已停用读取，请重试';
        rethrow;
      }
    }
  });
  Future<ReadOnlyResponse> read(
    String account,
    Future<ReadOnlyResponse> Function() fetch,
  ) async {
    if (!store.supported) return fetch();
    // The queued section owns the entire disk transaction and read. This is
    // opt-in only; ordinary disabled learning reads retain their concurrency.
    if (_enabled == false) return fetch();
    return _serial(() async {
      try {
        _enabled ??= await store.enabled();
        if (_enabled == true && _adoptedAccount != account) {
          final bytes = await store.load();
          if (bytes != null) await restore(account, bytes);
          _adoptedAccount = account;
        }
      } catch (_) {
        // Corrupt/foreign/expired archives are not overwritten or adopted.
        _enabled = false;
        message = '旧安全快照无法采用（可能过期、损坏或属于其他账号），请关闭后重新开启';
      }
      final response = await fetch();
      if (_enabled == true && response.failure == null) {
        try {
          await store.save(await export(account));
        } catch (_) {
          message = '本次查询成功，但安全快照未更新；原成功时间不变';
        }
      }
      return response;
    });
  }
}

final learningSnapshots = LearningSnapshotCoordinator(
  store: AndroidLearningSnapshotStore(),
  export: (account) async {
    final result = await boundedNativeWrite(
      () => live.exportLearningSnapshots(expectedAccount: account),
    );
    if (result.failure != null || result.bytes == null) {
      throw StateError('snapshot export unavailable');
    }
    return Uint8List.fromList(result.bytes!);
  },
  restore: (account, bytes) async {
    final result = await boundedNativeWrite(
      () =>
          live.importLearningSnapshots(expectedAccount: account, bytes: bytes),
    );
    if (result.failure != null) throw StateError('snapshot import unavailable');
  },
);

mixin NativeLearningSnapshots implements LearningSnapshotGateway {
  String? get expectedAccount;
  @override
  Future<LearningSnapshotStatus> learningSnapshotStatus() =>
      learningSnapshots.status();
  @override
  Future<LearningSnapshotStatus> setLearningSnapshotsEnabled(bool enabled) =>
      learningSnapshots.setEnabled(expectedAccount ?? '', enabled);
}
