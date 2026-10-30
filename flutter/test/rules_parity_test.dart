import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/features/homework/homework_projection.dart';
import 'package:ginkgo_mirror/shared/reminder_rules.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';

/// The shared rule tables in `fixtures/rules/`. The Rust domain rules own the
/// same files through the upstream contract runner, so a rule that changes on
/// one side of the language boundary fails on the other side too.
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('../fixtures/rules/$name').readAsStringSync())
        as Map<String, dynamic>;

String _deadlineName(HomeworkDeadlineStatus status) => switch (status) {
  HomeworkDeadlineStatus.active => 'active',
  HomeworkDeadlineStatus.overdue => 'overdue',
  HomeworkDeadlineStatus.undated => 'undated',
  HomeworkDeadlineStatus.invalid => 'invalid',
};

void main() {
  test('the homework deadline rule matches the shared table', () {
    final fixture = _fixture('homework-deadline-v1.json');
    final cases = fixture['input']['cases'] as List<dynamic>;
    final expected = fixture['expected']['results'] as List<dynamic>;
    expect(cases.length, expected.length);

    for (var index = 0; index < cases.length; index++) {
      final testCase = cases[index] as Map<String, dynamic>;
      final want = expected[index] as Map<String, dynamic>;
      final dueAt = testCase['dueAt'] as String?;
      final now = todaySchoolNow(DateTime.parse(testCase['now'] as String));
      final status = classifyHomeworkDeadline(dueAt, now);
      expect(
        _deadlineName(status),
        want['status'],
        reason: 'case $index ($dueAt) must classify the same on both sides',
      );
      expect(
        isHomeworkOverdue(dueAt, now),
        want['overdue'],
        reason: 'case $index ($dueAt) must agree on the overdue flag',
      );
    }
  });

  test('the sign-in window rule matches the shared table', () {
    final fixture = _fixture('checkin-window-v1.json');
    final cases = fixture['input']['cases'] as List<dynamic>;
    final expected = fixture['expected']['results'] as List<dynamic>;
    expect(cases.length, expected.length);

    for (var index = 0; index < cases.length; index++) {
      final testCase = cases[index] as Map<String, dynamic>;
      final want = expected[index] as Map<String, dynamic>;
      final course = CheckInCourse(
        id: 'synthetic',
        courseName: '合成课程',
        beginsAt: testCase['beginsAt'] as String,
        endsAt: testCase['endsAt'] as String,
        status: CheckInStatus.notSigned,
        mergedRecordCount: 1,
        conflicting: false,
      );
      final open = checkinWindowOpen(
        course,
        testCase['date'] as String,
        DateTime.parse(testCase['now'] as String),
      );
      expect(
        open,
        want['open'],
        reason:
            'case $index (${testCase['beginsAt']}) must open the same window '
            'on both sides',
      );
    }
  });
}
