import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/busy_gate.dart';

void main() {
  test('the gate rejects a second entry while it is held', () {
    final gate = BusyGate(deadline: const Duration(minutes: 1));
    addTearDown(gate.dispose);
    expect(gate.busy, isFalse);
    expect(gate.enter(), isTrue);
    expect(gate.busy, isTrue);
    expect(gate.enter(), isFalse);
  });

  test('leaving reopens the gate so the next attempt can run', () {
    final gate = BusyGate(deadline: const Duration(minutes: 1));
    addTearDown(gate.dispose);
    gate.enter();
    gate.leave();
    expect(gate.busy, isFalse);
    expect(gate.enter(), isTrue);
  });

  test('leaving twice is harmless', () {
    final gate = BusyGate(deadline: const Duration(minutes: 1));
    addTearDown(gate.dispose);
    gate.leave();
    gate.leave();
    expect(gate.busy, isFalse);
  });

  testWidgets('a held gate reopens on its own after the deadline', (
    tester,
  ) async {
    final gate = BusyGate(deadline: const Duration(seconds: 30));
    addTearDown(gate.dispose);
    var expired = 0;
    gate.onExpired = () => expired++;
    expect(gate.enter(), isTrue);

    await tester.pump(const Duration(seconds: 29));
    expect(gate.busy, isTrue, reason: 'the deadline has not passed yet');
    expect(expired, 0);

    await tester.pump(const Duration(seconds: 2));
    expect(gate.busy, isFalse, reason: 'the gate must reopen by itself');
    expect(expired, 1, reason: 'the recovery must be observable');
    // A recovered gate accepts the next attempt.
    expect(gate.enter(), isTrue);
    gate.leave();
  });

  testWidgets('a completed attempt never reports an expiry', (tester) async {
    final gate = BusyGate(deadline: const Duration(seconds: 30));
    addTearDown(gate.dispose);
    var expired = 0;
    gate.onExpired = () => expired++;
    gate.enter();
    gate.leave();
    await tester.pump(const Duration(minutes: 1));
    expect(expired, 0, reason: 'the watchdog must be cancelled on leave');
    expect(gate.busy, isFalse);
  });

  test('dispose stops the watchdog', () {
    final gate = BusyGate(deadline: const Duration(milliseconds: 1));
    var expired = 0;
    gate.onExpired = () => expired++;
    gate.enter();
    gate.dispose();
    expect(gate.busy, isFalse);
    expect(gate.onExpired, isNull);
  });
}
