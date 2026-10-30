import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/local_tasks.dart';

void main() {
  test('deadline validates real calendar and RFC3339 offsets', () {
    for (final value in [
      '',
      '2024-02-29',
      '2026-10-22T18:30:00+08:00',
      '2026-10-22T10:30:00Z',
    ]) {
      expect(isLocalTaskDue(value), isTrue, reason: value);
    }
    for (final value in [
      '2026-02-29',
      '2026-04-31',
      '2026-10-22T18:30:00+25:00',
      '2026-10-22T18:30:00+08:99',
      '2026-02-30T18:30:00Z',
      '2026-10-22T24:00:00Z',
      '2026-10-22T18:30:00',
      '2026-10-22T18:30+08:00',
    ]) {
      expect(isLocalTaskDue(value), isFalse, reason: value);
    }
  });

  test(
    'homework deadline preserves instant and annotates school wall time',
    () {
      expect(
        localTaskDueFromHomework('2026-10-22T10:30:00Z'),
        '2026-10-22T10:30:00Z',
      );
      expect(
        localTaskDueFromHomework('2026-10-22 18:30:00'),
        '2026-10-22T18:30:00+08:00',
      );
      expect(
        localTaskDueFromHomework('2026-10-22 18:30:00.500123456'),
        '2026-10-22T18:30:00.500123456+08:00',
      );
      expect(
        localTaskDueFromHomework('2026-10-22 18:30'),
        '2026-10-22T18:30:00+08:00',
      );
      expect(localTaskDueFromHomework('2026-10-22T18:30:00+25:00'), '');
      expect(localTaskDueFromHomework(null), '');
      expect(localTaskDueFromHomework('bad'), '');
      expect(
        localTaskDueLabel('2026-10-22T10:30:00Z'),
        '2026-10-22 18:30（北京时间）',
      );
    },
  );
}
