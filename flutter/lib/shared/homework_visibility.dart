import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/shared/course_visibility.dart';

/// The dashboard, the full list and the reminder planner share one policy for
/// which school assignments count as this user's own.
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

/// Orthogonal deadline status derived on the client; never mutates upstream
/// submission status (pending, submitted, unknown).
