import 'dart:async';

/// Upper bound for a native read command.
///
/// Rust bounds the gate wait (45 s) and the school round trip (45 s)
/// separately, so a read answers within 90 s at worst. This budget sits
/// above that on purpose: it must only fire when a native command never
/// answers, never preempt a slow but legitimate school request.
const Duration nativeReadBudget = Duration(seconds: 120);

/// Upper bound for a native write or session command.
///
/// Rust allows 90 s for the gate and 90 s for the command itself.
const Duration nativeWriteBudget = Duration(seconds: 210);

/// Run a native command under an upper bound.
///
/// The Rust side already bounds every command, so this is the second line of
/// defence: a command that never answers must not leave a page spinning
/// forever. The timeout surfaces as an ordinary error — every gateway caller
/// already maps a thrown error onto its failure state, and the write paths
/// already treat a thrown error as "the school may have received it".
Future<T> boundedNative<T>(
  Future<T> Function() command,
  Duration budget,
) async => await command().timeout(budget);

/// Read variant of [boundedNative].
Future<T> boundedNativeRead<T>(Future<T> Function() command) =>
    boundedNative(command, nativeReadBudget);

/// Write and session variant of [boundedNative].
Future<T> boundedNativeWrite<T>(Future<T> Function() command) =>
    boundedNative(command, nativeWriteBudget);

final Map<String, Future<Object?>> _inFlightNativeReads = {};

/// Coalesces concurrent non-forced reads (`forceRefresh == false`) for the
/// same account + resource key so startup/tab bursts share one FFI/HTTP chain
/// instead of racing duplicate tokens or cookies.
Future<T> coalescedNativeRead<T>({
  required String? account,
  required String key,
  required bool forceRefresh,
  required Future<T> Function() command,
}) {
  if (forceRefresh) return command();
  final scopeKey = '${account ?? ''}:$key';
  final existing = _inFlightNativeReads[scopeKey];
  if (existing != null) return existing.then((value) => value as T);
  late final Future<T> created;
  created = command().whenComplete(() {
    if (identical(_inFlightNativeReads[scopeKey], created)) {
      _inFlightNativeReads.remove(scopeKey);
    }
  });
  _inFlightNativeReads[scopeKey] = created;
  return created;
}

void clearInFlightNativeReads() => _inFlightNativeReads.clear();
