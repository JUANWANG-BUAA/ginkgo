import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/shared/course_visibility.dart';

/// Whether a SPOC course role belongs to teaching/assistant duties rather than
/// the student's own coursework.
bool isNonStudentCourseRole(String? role) =>
    role == 'assistant' || role == 'teacher';

/// Display label for a known SPOC course role.
String? homeworkCourseRoleLabel(String? role) => switch (role) {
  'assistant' => '助教课程',
  'teacher' => '教师课程',
  'student' => '我的课程',
  _ => null,
};

/// The dashboard, the full list and the reminder planner share one policy for
/// which school assignments count as this user's own.
List<HomeworkItem> personalHomeworkItems(
  Iterable<HomeworkItem> items,
  CourseVisibility? visibility,
) => items
    .where(
      (item) =>
          !isNonStudentCourseRole(item.courseRole) &&
          !(visibility?.hidden('spoc', item.courseId ?? item.id) ?? false),
    )
    .toList(growable: false);

/// Orthogonal deadline status derived on the client; never mutates upstream
/// submission status (pending, submitted, unknown).
