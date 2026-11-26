import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/shared/course_visibility.dart';
import 'package:ginkgo_mirror/shared/homework_visibility.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';

/// Canonical per-course visibility key for iClass check-in entries.
String checkinCourseKey(CheckInCourse course) =>
    course.courseId ?? course.courseNum ?? course.id;

/// Conservative course-name normalization for cross-system matching
/// (iClass <-> Academic Affairs timetable / SPOC).
String normalizeCheckinCourseName(String raw) => raw
    .trim()
    .replaceAll(RegExp(r'[\s\u3000]+'), '')
    .replaceAll('（', '(')
    .replaceAll('）', ')')
    .replaceAll('：', ':')
    .toLowerCase();

/// Normalized names of courses confirmed as non-student (assistant/teacher) in
/// SPOC, excluding any name also confirmed as a student course.
Set<String> nonStudentCourseNamesFromHomework(HomeworkResponse? homework) {
  if (homework == null) return const {};
  final nonStudent = <String>{};
  final student = <String>{};
  for (final item in homework.items) {
    final name = normalizeCheckinCourseName(item.courseName);
    if (name.isEmpty) continue;
    if (isNonStudentCourseRole(item.courseRole)) {
      nonStudent.add(name);
    } else if (item.courseRole == 'student') {
      student.add(name);
    }
  }
  return nonStudent.difference(student);
}

bool _matchesNormalizedCourseName(String left, String right) {
  if (left.isEmpty || right.isEmpty) return false;
  if (left == right) return true;
  if (left.length >= 2 && right.length >= 2) {
    return left.contains(right) || right.contains(left);
  }
  return false;
}

/// Filter iClass check-in courses down to the student's own courses:
/// 1. Respects explicit user hiding in `CourseVisibility` (`iclass`).
/// 2. When [todaySchedule] is an error-free timetable confirmed for the same
///    school day as [checkinDate], keeps only iClass sessions matching a
///    student timetable course on that day so TA courses mixed into iClass
///    `get_stu_course_sched.action` never appear on Today.
/// 3. Otherwise excludes courses confirmed as TA/teacher in SPOC [homework].
List<CheckInCourse> personalCheckInCourses(
  Iterable<CheckInCourse> courses, {
  CourseVisibility? visibility,
  HomeworkResponse? homework,
  TodayResponse? todaySchedule,
  String? checkinDate,
}) {
  final spocNonStudent = nonStudentCourseNamesFromHomework(homework);
  final checkinDay = checkinDate == null ? null : todayDate(checkinDate);
  final scheduleConfirmedForDay =
      todaySchedule != null &&
      todaySchedule.failure == null &&
      checkinDay != null &&
      todayDate(todaySchedule.date) == checkinDay;
  final scheduleNames = scheduleConfirmedForDay
      ? [
          for (final course in todaySchedule.courses)
            normalizeCheckinCourseName(course.name),
        ].where((name) => name.isNotEmpty).toList(growable: false)
      : const <String>[];

  return courses
      .where((course) {
        if (visibility?.hidden('iclass', checkinCourseKey(course)) ?? false) {
          return false;
        }
        final name = normalizeCheckinCourseName(course.courseName);
        if (scheduleConfirmedForDay) {
          if (scheduleNames.isEmpty) return false;
          return scheduleNames.any(
            (schedName) => _matchesNormalizedCourseName(name, schedName),
          );
        }
        if (spocNonStudent.any(
          (taName) => _matchesNormalizedCourseName(name, taName),
        )) {
          return false;
        }
        return true;
      })
      .toList(growable: false);
}

String? _startClock(String? raw) {
  final match = RegExp(r'(\d{1,2}:\d{2})').firstMatch(raw ?? '');
  if (match == null) return null;
  final parts = match.group(1)!.split(':');
  return '${parts[0].padLeft(2, '0')}:${parts[1]}';
}

/// Find the iClass check-in record corresponding to a student timetable course
/// on the same day so Today can fuse check-in directly into the course card
/// without duplicating the course in a second section.
CheckInCourse? matchCheckInForTodayCourse(
  TodayCourse course,
  Iterable<CheckInCourse> checkins,
) {
  final targetName = normalizeCheckinCourseName(course.name);
  if (targetName.isEmpty) return null;
  final candidates = [
    for (final item in checkins)
      if (_matchesNormalizedCourseName(
        normalizeCheckinCourseName(item.courseName),
        targetName,
      ))
        item,
  ];
  if (candidates.isEmpty) return null;
  if (candidates.length == 1) return candidates.first;
  final targetStart = _startClock(course.time);
  if (targetStart != null) {
    for (final item in candidates) {
      if (_startClock(item.beginsAt) == targetStart) return item;
    }
  }
  return candidates.firstWhere(
    (item) =>
        item.status == CheckInStatus.notSigned ||
        item.status == CheckInStatus.unknown,
    orElse: () => candidates.first,
  );
}
