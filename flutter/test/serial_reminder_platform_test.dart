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

class _ScopedPlatform extends _Platform implements ScopedReminderPlatform {
  Set<String>? receivedGroups;
  List<Map<String, Object>>? receivedPlans;

  @override
  Future<void> synchronize({
    required String owner,
    required bool checkin,
    required bool homework,
    required Set<String> groups,
    required List<Map<String, Object>> plans,
  }) async {
    calls.add('sync:$owner:$checkin:$homework');
    receivedGroups = groups;
    receivedPlans = plans;
  }

  @override
  Future<void> clearOwner(String owner) async {
    calls.add('clear:$owner');
    if (owner == 'fail') throw StateError('synthetic scoped failure');
  }
}

void main() {
  test('replacement captures list and map values when enqueued', () async {
    final delegate = _Platform();
    final platform = SerialReminderPlatform(delegate);
    final old = platform.replace([
      {'key': 'old'},
    ]);
    final plan = <String, Object>{'key': 'new'};
    final plans = [plan];
    final next = platform.replace(plans);
    plan['key'] = 'changed';
    plans.clear();
    delegate.first.complete();
    await old;
    await next;
    expect(delegate.calls, ['old', 'new']);
  });

  test('scoped and legacy commands share one failure-tolerant queue', () async {
    final delegate = _ScopedPlatform();
    final platform = SerialReminderPlatform(delegate);
    final old = platform.replace([
      {'key': 'old'},
    ]);
    final clearing = platform.clearOwner('fail');
    final failed = expectLater(clearing, throwsStateError);
    final syncing = platform.synchronize(
      owner: 'next',
      checkin: true,
      homework: false,
      groups: {'checkin'},
      plans: [],
    );
    final cleanup = platform.clearOwner('next');
    await Future<void>.delayed(Duration.zero);
    expect(delegate.calls, ['old']);
    delegate.first.complete();
    await Future.wait([old, failed, syncing, cleanup]);
    expect(delegate.calls, [
      'old',
      'clear:fail',
      'sync:next:true:false',
      'clear:next',
    ]);
  });

  test(
    'scoped updates capture group and plan snapshots before waiting',
    () async {
      final delegate = _ScopedPlatform();
      final platform = SerialReminderPlatform(delegate);
      final old = platform.replace([
        {'key': 'old'},
      ]);
      final groups = {'homework'};
      final plan = <String, Object>{'key': 'new', 'at': 123};
      final plans = [plan];
      final next = platform.synchronize(
        owner: 'next',
        checkin: false,
        homework: true,
        groups: groups,
        plans: plans,
      );
      groups.clear();
      plan['at'] = 456;
      plans.clear();
      delegate.first.complete();
      await Future.wait([old, next]);
      expect(delegate.receivedGroups, {'homework'});
      expect(delegate.receivedPlans, [
        {'key': 'new', 'at': 123},
      ]);
    },
  );

  test('legacy delegates retain scoped fallback ordering', () async {
    final delegate = _Platform();
    final platform = SerialReminderPlatform(delegate);
    final clearing = platform.clearOwner('old');
    final failed = expectLater(clearing, throwsStateError);
    final next = platform.synchronize(
      owner: 'next',
      checkin: true,
      homework: true,
      groups: {'homework'},
      plans: [
        {'key': 'new'},
      ],
    );
    await Future.wait([failed, next]);
    expect(delegate.calls, ['clear', 'new']);
  });

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
