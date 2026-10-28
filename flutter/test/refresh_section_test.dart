import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';

void main() {
  test('old queued refresh cannot clear a newer forced refresh', () async {
    final section = RefreshSection<int>();
    addTearDown(section.dispose);
    final old = Completer<SectionResult<int>>();
    final current = Completer<SectionResult<int>>();
    var forcedReads = 0;
    final oldTask = section.refresh(() => old.future, fallbackError: 'old');
    final oldForced = section.refresh(
      () async => const SectionResult(value: 1),
      fallbackError: 'old',
      force: true,
    );
    section.invalidate();
    final currentTask = section.refresh(
      () => current.future,
      fallbackError: 'new',
    );
    Future<SectionResult<int>> forceRead() async {
      forcedReads++;
      return const SectionResult(value: 2);
    }

    final newForced = section.refresh(
      forceRead,
      fallbackError: 'new',
      force: true,
    );
    old.complete(const SectionResult(value: 0));
    await Future.wait([oldTask, oldForced]);
    final joined = section.refresh(
      forceRead,
      fallbackError: 'new',
      force: true,
    );
    expect(identical(joined, newForced), isTrue);
    current.complete(const SectionResult(value: 1));
    await Future.wait([currentTask, newForced, joined]);
    expect(forcedReads, 1);
    expect(section.value, 2);
  });

  testWidgets('old completion cannot cancel the current read stall timer', (
    tester,
  ) async {
    final section = RefreshSection<int>(
      stallDeadline: const Duration(seconds: 3),
    );
    addTearDown(section.dispose);
    final old = Completer<SectionResult<int>>();
    final current = Completer<SectionResult<int>>();
    final oldTask = section.refresh(() => old.future, fallbackError: 'old');
    section.invalidate();
    final currentTask = section.refresh(
      () => current.future,
      fallbackError: 'current',
    );
    old.complete(const SectionResult(value: 1));
    await oldTask;
    await tester.pump(const Duration(seconds: 4));
    expect(section.loading, isFalse);
    expect(section.error, 'current');
    current.complete(const SectionResult(value: 2));
    await currentTask;
    expect(section.value, isNull);
  });

  test(
    'overlapping refreshes share a read; failure preserves the last value',
    () async {
      final section = RefreshSection<List<int>>();
      addTearDown(section.dispose);
      await section.refresh(
        () async => const SectionResult(value: [1]),
        fallbackError: '无法读取',
      );
      final pending = Completer<SectionResult<List<int>>>();
      var reads = 0;
      Future<SectionResult<List<int>>> read() {
        reads++;
        return pending.future;
      }

      final first = section.refresh(read, fallbackError: '无法读取');
      final second = section.refresh(read, fallbackError: '无法读取');
      expect(identical(first, second), isTrue);
      expect(reads, 1);
      expect(section.value, [1]);
      expect(section.loading, isTrue);
      pending.complete(const SectionResult(error: '学校服务暂不可用'));
      await first;
      expect(section.value, [1]);
      expect(section.error, '学校服务暂不可用');
      expect(section.loading, isFalse);
      await section.refresh(
        () async => const SectionResult(value: []),
        fallbackError: '无法读取',
      );
      expect(section.value, isEmpty);
      expect(section.error, isNull);
    },
  );

  test('disposed provider cannot publish a delayed result', () async {
    final section = RefreshSection<int>();
    final pending = Completer<SectionResult<int>>();
    var notifications = 0;
    section.addListener(() => notifications++);
    final task = section.refresh(() => pending.future, fallbackError: '无法读取');
    section.dispose();
    pending.complete(const SectionResult(value: 42));
    await task;
    expect(notifications, 1);
    expect(section.value, isNull);
  });

  test(
    'a forced refresh arriving mid-read re-runs instead of being merged away',
    () async {
      final section = RefreshSection<int>();
      addTearDown(section.dispose);
      var reads = 0;
      final slow = Completer<SectionResult<int>>();
      Future<SectionResult<int>> cachedRead() async {
        reads++;
        return slow.future;
      }

      final first = section.refresh(cachedRead, fallbackError: '无法读取');
      expect(reads, 1);
      final forced = section.refresh(
        () async {
          reads++;
          return const SectionResult(value: 7);
        },
        fallbackError: '无法读取',
        force: true,
      );
      // The forced request is distinct and waits for the in-flight read.
      expect(identical(forced, first), isFalse);
      expect(reads, 1);
      slow.complete(const SectionResult(value: 1));
      await first;
      await forced;
      expect(reads, 2);
      expect(section.value, 7);
      expect(section.loading, isFalse);
    },
  );

  test(
    'a plain refresh joins the slot occupied by the forced re-run',
    () async {
      final section = RefreshSection<int>();
      addTearDown(section.dispose);
      final slow = Completer<SectionResult<int>>();
      var reads = 0;
      final first = section.refresh(() async {
        reads++;
        return slow.future;
      }, fallbackError: '无法读取');
      final forced = section.refresh(
        () async {
          reads++;
          return const SectionResult(value: 9);
        },
        fallbackError: '无法读取',
        force: true,
      );
      slow.complete(const SectionResult(value: 1));
      await first;
      // The forced re-run now occupies the slot; a plain caller must join it
      // instead of starting yet another read.
      final plain = section.refresh(() async {
        reads++;
        return const SectionResult(value: 99);
      }, fallbackError: '无法读取');
      await plain;
      expect(reads, 2, reason: 'plain caller must not start a second read');
      expect(identical(plain, forced), isTrue);
      await forced;
      expect(section.value, 9);
    },
  );

  test('invalidation starts a new read and abandons the old slot', () async {
    final section = RefreshSection<int>();
    addTearDown(section.dispose);
    final oldRead = Completer<SectionResult<int>>();
    final newRead = Completer<SectionResult<int>>();
    var reads = 0;

    final oldTask = section.refresh(
      () => oldRead.future,
      fallbackError: '无法读取',
    );
    section.invalidate();
    final newTask = section.refresh(() {
      reads++;
      return newRead.future;
    }, fallbackError: '无法读取');
    expect(reads, 1, reason: 'invalidation must reopen the slot immediately');

    oldRead.complete(const SectionResult(value: 1));
    await oldTask;
    expect(section.value, isNull);
    expect(section.loading, isTrue);

    final joined = section.refresh(() async {
      reads++;
      return const SectionResult(value: 99);
    }, fallbackError: '无法读取');
    expect(identical(joined, newTask), isTrue);
    expect(reads, 1, reason: 'the old completion must not clear the new slot');

    newRead.complete(const SectionResult(value: 2));
    await newTask;
    expect(section.value, 2);
    expect(section.loading, isFalse);
  });

  testWidgets('a read that never settles stalls instead of loading forever', (
    tester,
  ) async {
    final section = RefreshSection<List<int>>(
      stallDeadline: const Duration(seconds: 30),
    );
    addTearDown(section.dispose);
    await section.refresh(
      () async => const SectionResult(value: [1]),
      fallbackError: '无法读取',
    );

    // The read never completes.
    final pending = Completer<SectionResult<List<int>>>();
    final running = section.refresh(
      () => pending.future,
      fallbackError: '读取未完成',
    );
    expect(section.loading, isTrue);

    await tester.pump(const Duration(seconds: 29));
    expect(section.loading, isTrue, reason: 'the deadline has not passed yet');

    await tester.pump(const Duration(seconds: 2));
    expect(section.loading, isFalse, reason: 'the section must stop waiting');
    expect(section.error, '读取未完成');
    expect(section.value, [
      1,
    ], reason: 'a stalled read must not discard the last known value');

    // A later refresh is not captured by the stalled slot.
    await tester.pump();
    var reads = 0;
    final again = section.refresh(() async {
      reads++;
      return const SectionResult(value: [2]);
    }, fallbackError: '无法读取');
    await tester.pump();
    await tester.pump();
    await again;
    expect(reads, 1, reason: 'the stalled slot must not absorb a new read');
    expect(section.value, [2]);

    // The abandoned read stays abandoned.
    pending.complete(const SectionResult(value: [99]));
    await running;
    await tester.pump();
    expect(section.value, [2], reason: 'a late stalled result must not land');
  });
}
