import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/school_timestamp.dart';

void main() {
  test('timestamps use Beijing time for Z and offset instants', () {
    expect(schoolTimestampLabel('2026-10-21T03:10:33.396123Z'), '10月21日 11:10');
    expect(
      schoolTimestampLabel('2026-10-21T11:10:33.396123+08:00'),
      '10月21日 11:10',
    );
    expect(schoolTimestampLabel('2026-10-20T23:10:33-04:00'), '10月21日 11:10');
    expect(schoolTimestampLabel('2026-10-20T17:05:00Z'), '10月21日 01:05');
    expect(schoolTimestampLabel('2026-01-02 09:05:00'), '01月02日 09:05');
  });

  test('missing and invalid timestamps stay distinguishable', () {
    expect(schoolTimestampLabel(null), '未确认');
    expect(schoolTimestampLabel('  '), '未确认');
    for (final value in [
      'invalid',
      '2026-02-30T10:00:00Z',
      '2026-10-21T25:00:00Z',
    ]) {
      expect(schoolTimestampLabel(value), value);
      expect(parseSchoolTimestamp(value), isNull);
    }
    expect(schoolClockLabel('2026-10-21T03:10:00Z'), '11:10');
  });

  test('course ranges omit repeated day and seconds in Beijing', () {
    expect(
      schoolTimeRange('2026-10-21 08:00:00', '2026-10-21 09:35:00'),
      '08:00–09:35',
    );
    expect(
      schoolTimeRange('2026-10-21T00:00:00Z', '2026-10-21T09:35:00+08:00'),
      '08:00–09:35',
    );
    expect(
      schoolTimeRange('2026-10-20T23:00:00Z', '2026-10-21T00:30:00Z'),
      '07:00–08:30',
    );
  });

  test('cross-day and cross-year ranges retain dates', () {
    expect(
      schoolTimeRange('2026-10-21T15:30:00Z', '2026-10-21T16:30:00Z'),
      '10月21日 23:30–10月22日 00:30',
    );
    expect(
      schoolTimeRange('2026-12-31 23:30:00', '2027-01-01 00:30:00'),
      '2026年12月31日 23:30–2027年01月01日 00:30',
    );
  });

  test('unparseable range preserves original values', () {
    expect(
      schoolTimeRange('上游待确认', '2026-10-21 09:35:00'),
      '上游待确认–2026-10-21 09:35:00',
    );
    expect(schoolTimeRange('08:00', '09:35'), '08:00–09:35');
  });
}
