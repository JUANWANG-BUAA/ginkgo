import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/infrastructure/native_command.dart';

void main() {
  test('a native command that answers passes its value through', () async {
    final value = await boundedNative(
      () async => 7,
      const Duration(seconds: 1),
    );
    expect(value, 7);
  });

  test('a native command that fails keeps its own error', () async {
    await expectLater(
      boundedNative(
        () async => throw StateError('native failure'),
        const Duration(seconds: 1),
      ),
      throwsStateError,
    );
  });

  test(
    'a native command that never answers fails instead of hanging forever',
    () async {
      final pending = Completer<int>();
      await expectLater(
        boundedNative(() => pending.future, const Duration(milliseconds: 50)),
        throwsA(isA<TimeoutException>()),
      );
      pending.complete(1);
    },
  );

  test('the read budget stays above the Rust read bound', () {
    // Rust allows 45 s for the gate wait and 45 s for the school round trip.
    // The Dart budget must not preempt a slow but legitimate request.
    expect(
      nativeReadBudget.inSeconds,
      greaterThan(45 + 45),
      reason: 'the Dart read budget must sit above the Rust read bound',
    );
  });

  test('the write budget stays above the Rust write bound', () {
    // Rust allows 90 s for the gate wait and 90 s for the command itself.
    expect(
      nativeWriteBudget.inSeconds,
      greaterThan(90 + 90),
      reason: 'the Dart write budget must sit above the Rust write bound',
    );
  });

  test('the read and write budgets differ', () {
    expect(nativeWriteBudget, greaterThan(nativeReadBudget));
  });
}
