import 'package:flutter/foundation.dart';
import 'diagnostic_log.dart';

/// A presentation result, including a usable stale value when refresh failed.
class SectionResult<T> {
  const SectionResult({this.value, this.error});
  final T? value;
  final String? error;
}

/// Independent section refreshes preserve content and join overlapping reads.
/// Disposing a section prevents a previous provider's late response resurfacing.
class RefreshSection<T> extends ChangeNotifier {
  T? value;
  String? error;
  bool loading = false;
  bool _disposed = false;
  Future<void>? _task;
  Future<void>? _forcedRun;

  /// A plain refresh joins the in-flight read. A forced refresh is never
  /// merged away: when one arrives while a (typically cached) read runs, it
  /// re-runs once that read settles and occupies the slot while doing so.
  Future<void> refresh(
    Future<SectionResult<T>> Function() read, {
    required String fallbackError,
    bool force = false,
  }) {
    final inFlight = _task;
    if (inFlight == null) {
      _forcedRun = null;
      return _task = _refresh(
        read,
        fallbackError,
      ).whenComplete(() => _task = null);
    }
    if (!force) return inFlight;
    return _forcedRun ??= _chainForced(read, fallbackError, inFlight);
  }

  Future<void> _chainForced(
    Future<SectionResult<T>> Function() read,
    String fallbackError,
    Future<void> inFlight,
  ) {
    late final Future<void> run;
    run = inFlight.then((_) async {
      if (_disposed) return;
      _task = run;
      await _refresh(read, fallbackError);
    }).whenComplete(() {
      _forcedRun = null;
      if (identical(_task, run)) _task = null;
    });
    return run;
  }

  Future<void> _refresh(
    Future<SectionResult<T>> Function() read,
    String fallbackError,
  ) async {
    if (_disposed) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await read();
      if (_disposed) return;
      if (result.value != null) value = result.value;
      error = result.error;
    } catch (_) {
      if (_disposed) return;
      DiagnosticLog.shared.record(null);
      error = fallbackError;
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
