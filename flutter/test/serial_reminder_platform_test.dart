import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/reminder_platform.dart';
import 'package:ginkgo_mirror/infrastructure/serial_reminder_platform.dart';

class _Platform implements ReminderPlatform {
  final calls = <String>[];
  final first = Completer<void>();

  @override
  Future<void> replace(List<Map<String, Object>> plans) async {
    final label = plans.isEmpty ? 'clear' : plans.single['key'] as String;
    calls.add(label);
    if (label == 'old') await first.future;
    if (label == 'clear') throw StateError('clear failed');
  }
}

void main() {
  test('old replacement, cleanup and new replacement remain ordered even on failure', () async {
    final delegate = _Platform();
    final platform = SerialReminderPlatform(delegate);
    final old = platform.replace([
      {'key': 'old'},
    ]);
    final cleanup = platform.replace([]);
    final cleanupFailure = expectLater(cleanup, throwsStateError);
    final next = platform.replace([
      {'key': 'new'},
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(delegate.calls, ['old']);
    delegate.first.complete();
    await old;
    await cleanupFailure;
    await next;
    expect(delegate.calls, ['old', 'clear', 'new']);
  });
}
