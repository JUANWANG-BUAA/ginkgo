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
}
