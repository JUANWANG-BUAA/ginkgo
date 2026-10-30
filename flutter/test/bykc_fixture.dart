import 'package:ginkgo_mirror/application/bykc.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';

/// Test fixtures stay map-shaped; production now receives typed values, so
/// fixtures are lifted here in one place.
BykcPartRead bykcRead(BykcPart part, Map<String, dynamic> data) =>
    switch (part) {
      BykcPart.catalog => BykcCatalogRead(data: _catalog(data)),
      BykcPart.chosen => BykcChosenRead(data: _chosen(data)),
      BykcPart.statistics => BykcStatisticsRead(data: _statistics(data)),
    };

BykcSemester? _semester(Object? json) => json is Map<String, dynamic>
    ? BykcSemester(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        start: json['start'] as String?,
        end: json['end'] as String?,
      )
    : null;

BykcCatalog _catalog(Map<String, dynamic> data) => BykcCatalog(
  currentTerm: _semester(data['currentTerm']),
  courses: [
    for (final course
        in (data['courses'] as List? ?? const []).cast<Map<String, dynamic>>())
      _course(course),
  ],
);

BykcCourse _course(Map<String, dynamic> json) {
  final details = json['details'];
  return BykcCourse(
    id: json['id'] as int? ?? 0,
    name: json['name'] as String? ?? '',
    teacher: json['teacher'] as String?,
    position: json['position'] as String?,
    category: json['category'] as String?,
    subcategory: json['subcategory'] as String?,
    details: details is Map<String, dynamic>
        ? BykcCourseDetails(
            start: details['start'] as String?,
            end: details['end'] as String?,
            selectStart: details['selectStart'] as String?,
            selectEnd: details['selectEnd'] as String?,
            cancelEnd: details['cancelEnd'] as String?,
            capacity: details['capacity'] as int?,
            enrolled: details['enrolled'] as int?,
            campuses: (details['campuses'] as List? ?? const []).cast<String>(),
            summary: details['summary'] as String?,
            selected: details['selected'] as bool?,
            hasSignConfig: details['hasSignConfig'] as bool?,
          )
        : null,
  );
}

BykcChosenCourses _chosen(Map<String, dynamic> data) => BykcChosenCourses(
  term: _semester(data['term']),
  courses: data['courses'] == null
      ? null
      : [
          for (final record
              in (data['courses'] as List).cast<Map<String, dynamic>>())
            BykcChosenRecord(
              id: record['id'] as int? ?? 0,
              course: _course(
                (record['course'] as Map<String, dynamic>?) ?? const {},
              ),
              selectedAt: record['selectedAt'] as String?,
              checkin: record['checkin'] as int?,
              passed: record['passed'] as int?,
              score: record['score'] as int?,
            ),
        ],
);

BykcStatistics _statistics(Map<String, dynamic> data) => BykcStatistics(
  validCourseCount: data['validCourseCount'] as int?,
  entries: [
    for (final entry
        in (data['entries'] as List? ?? const []).cast<Map<String, dynamic>>())
      BykcStatisticsEntry(
        category: entry['category'] as String? ?? '',
        subcategory: entry['subcategory'] as String? ?? '',
        requiredCount: entry['required'] as int? ?? 0,
        completed: entry['completed'] as int? ?? 0,
      ),
  ],
);

/// Direct typed fixtures for tests that assert on decoded fields.
BykcCatalog bykcCatalogFrom(Map<String, dynamic> data) => _catalog(data);
BykcChosenCourses bykcChosenFrom(Map<String, dynamic> data) => _chosen(data);
BykcStatistics bykcStatisticsFrom(Map<String, dynamic> data) =>
    _statistics(data);
