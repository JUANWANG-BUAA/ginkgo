import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';

void main() {
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

  test('a plain refresh joins the slot occupied by the forced re-run', () async {
    final section = RefreshSection<int>();
    addTearDown(section.dispose);
    final slow = Completer<SectionResult<int>>();
    var reads = 0;
    final first = section.refresh(() async {
      reads++;
      return slow.future;
    }, fallbackError: '无法读取');
    final forced = section.refresh(() async {
      reads++;
      return const SectionResult(value: 9);
    }, fallbackError: '无法读取', force: true);
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
  });
}
