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
