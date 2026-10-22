import 'application/contracts.dart';
import 'course_visibility.dart';

/// The dashboard and full list use the same personal-course visibility policy.
List<HomeworkItem> personalHomeworkItems(
  Iterable<HomeworkItem> items,
  CourseVisibility? visibility,
) => items
    .where(
      (item) =>
          item.courseRole != 'assistant' &&
          !(visibility?.hidden('spoc', item.courseId ?? item.id) ?? false),
    )
    .toList(growable: false);
