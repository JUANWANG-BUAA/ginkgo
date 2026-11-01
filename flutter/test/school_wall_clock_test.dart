import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';

void main() {
  // 2026-11-01 23:20 Beijing, the moment a homework due at 11-02 00:00 was
  // reported as already overdue on a real device.
  final instant = DateTime.utc(2026, 11, 1, 15, 20);
  final wall = todaySchoolNow(instant);

  test('the school wall clock converts back to the real instant', () {
    expect(wall.hour, 23);
    expect(
      schoolWallClockMillis(wall),
      instant.millisecondsSinceEpoch,
      reason: 'a wall clock stamped as UTC would otherwise run 8 hours ahead',
    );
  });

  test('a real local clock lands on the same instant', () {
    expect(
      schoolWallClockMillis(instant.toLocal()),
      instant.millisecondsSinceEpoch,
    );
  });

  test('a deadline 40 minutes away is still in the future', () {
    final nowMillis = schoolWallClockMillis(wall);
    // 2026-11-02 00:00 Beijing is what the school sends for the next day.
    final dueMillis = DateTime.utc(2026, 11, 1, 16).millisecondsSinceEpoch;
    expect(dueMillis - nowMillis, const Duration(minutes: 40).inMilliseconds);
    expect(nowMillis, lessThan(dueMillis));
  });
}
