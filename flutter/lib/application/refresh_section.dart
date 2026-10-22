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

  Future<void> refresh(
    Future<SectionResult<T>> Function() read, {
    required String fallbackError,
  }) =>
      _task ??= _refresh(read, fallbackError).whenComplete(() => _task = null);

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
