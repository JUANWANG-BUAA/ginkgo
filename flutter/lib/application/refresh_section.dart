import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/diagnostic_log.dart';

/// A presentation result, including a usable stale value when refresh failed.
class SectionResult<T> {
  const SectionResult({this.value, this.error, this.failure});
  final T? value;
  final String? error;

  /// The typed code behind [error]. A page must not reverse-engineer localized
  /// copy to tell an offline device from a school outage; both read as "failed"
  /// but only one is fixed by waiting.
  final FailureCode? failure;
}

/// Independent section refreshes preserve content and join overlapping reads.
/// Disposing a section prevents a previous provider's late response resurfacing.
class RefreshSection<T> extends ChangeNotifier {
  RefreshSection({this.stallDeadline = const Duration(minutes: 3)});

  /// How long a read may stay in flight before the section stops waiting.
  ///
  /// A read that never settles would otherwise leave [loading] set forever and
  /// keep the slot occupied, so every later refresh joins a future that never
  /// completes. Reaching the deadline discards the late response the same way
  /// [invalidate] does, reports a stall, and reopens the slot.
  final Duration stallDeadline;

  T? value;
  String? error;

  /// Typed code behind [error]; `null` for a local exception or a stall.
  FailureCode? failure;
  bool loading = false;
  bool _disposed = false;
  Future<void>? _task;
  Future<void>? _forcedRun;
  int _generation = 0;
  Timer? _stall;

  /// Drops every in-flight read at its next await: call when the account or
  /// service generation behind [read] changes, so a late response from the
  /// previous context never lands. Follow with a forced refresh.
  void invalidate() => _generation++;

  /// A plain refresh joins the in-flight read. A forced refresh is never
  /// merged away: when one arrives while a (typically cached) read runs, it
  /// re-runs once that read settles and occupies the slot while doing so.
  Future<void> refresh(
    Future<SectionResult<T>> Function() read, {
    required String fallbackError,
    bool force = false,
  }) {
    final inFlight = _task;
    // Invalidated and stalled slots belong to an abandoned context. They must
    // not capture a new read, and their completion must not clear the new slot.
    if (inFlight == null || _isStalled || _taskGeneration != _generation) {
      _forcedRun = null;
      return _start(read, fallbackError);
    }
    if (!force) return inFlight;
    return _forcedRun ??= _chainForced(read, fallbackError, inFlight);
  }

  int _taskGeneration = 0;

  Future<void> _start(
    Future<SectionResult<T>> Function() read,
    String fallbackError,
  ) {
    final taskGeneration = _generation;
    _taskGeneration = taskGeneration;
    return _task = _refresh(read, fallbackError).whenComplete(() {
      if (_taskGeneration == taskGeneration) _task = null;
    });
  }

  /// Whether the last read hit [stallDeadline] and was discarded.
  bool _isStalled = false;

  Future<void> _chainForced(
    Future<SectionResult<T>> Function() read,
    String fallbackError,
    Future<void> inFlight,
  ) {
    final epoch = _generation;
    late final Future<void> run;
    run = inFlight
        .then((_) async {
          if (_disposed || epoch != _generation) return;
          _task = run;
          await _refresh(read, fallbackError);
        })
        .whenComplete(() {
          if (identical(_forcedRun, run)) _forcedRun = null;
          if (identical(_task, run)) _task = null;
        });
    return run;
  }

  Future<void> _refresh(
    Future<SectionResult<T>> Function() read,
    String fallbackError,
  ) async {
    if (_disposed) return;
    final epoch = _generation;
    _isStalled = false;
    loading = true;
    error = null;
    failure = null;
    notifyListeners();
    // The read itself is not cancelled (a native command cannot be); only the
    // caller stops waiting and its late result is discarded via the epoch.
    _stall?.cancel();
    final stall = Timer(stallDeadline, () {
      if (_disposed || epoch != _generation || !loading) return;
      _generation++;
      _isStalled = true;
      loading = false;
      error = fallbackError;
      notifyListeners();
    });
    _stall = stall;
    try {
      final result = await read();
      if (_disposed || epoch != _generation) return;
      if (result.value != null) value = result.value;
      error = result.error;
      failure = result.failure;
    } catch (_) {
      if (_disposed || epoch != _generation) return;
      DiagnosticLog.shared.record(null, showHint: false);
      error = fallbackError;
    } finally {
      stall.cancel();
      if (identical(_stall, stall)) _stall = null;
      if (!_disposed && epoch == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stall?.cancel();
    _stall = null;
    super.dispose();
  }
}
