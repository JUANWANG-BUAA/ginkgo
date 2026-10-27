import 'dart:convert';

/// Typed projection of the BYKC payloads serialized by
/// `ginkgo_domain::features::bykc` plus the core `BykcCatalogView`
/// projection (`currentTerm`). Course fields keep the school's snake_case;
/// nested detail fields follow the upstream camelCase contract.

class BykcSemester {
  BykcSemester.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String? ?? '',
      name = json['name'] as String? ?? '',
      start = json['start'] as String?,
      end = json['end'] as String?;

  final String id, name;
  final String? start, end;
}

/// Course enrollment details. Absent values stay null; they are never
/// converted into zeros or guessed text.
class BykcCourseDetails {
  BykcCourseDetails.fromJson(Map<String, dynamic> json)
    : start = json['start'] as String?,
      end = json['end'] as String?,
      selectStart = json['selectStart'] as String?,
      selectEnd = json['selectEnd'] as String?,
      cancelEnd = json['cancelEnd'] as String?,
      capacity = json['capacity'] as int?,
      enrolled = json['enrolled'] as int?,
      campuses = (json['campuses'] as List? ?? const []).cast<String>(),
      summary = json['summary'] as String?,
      selected = json['selected'] as bool?,
      hasSignConfig = json['hasSignConfig'] as bool?;

  const BykcCourseDetails.empty()
    : start = null,
      end = null,
      selectStart = null,
      selectEnd = null,
      cancelEnd = null,
      capacity = null,
      enrolled = null,
      campuses = const [],
      summary = null,
      selected = null,
      hasSignConfig = null;

  final String? start, end, selectStart, selectEnd, cancelEnd, summary;
  final int? capacity, enrolled;
  final List<String> campuses;
  final bool? selected, hasSignConfig;
}

class BykcCourse {
  BykcCourse.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int? ?? 0,
      name = json['name'] as String? ?? '',
      teacher = json['teacher'] as String?,
      position = json['position'] as String?,
      category = json['category'] as String?,
      subcategory = json['subcategory'] as String?,
      details = json['details'] == null
          ? null
          : BykcCourseDetails.fromJson(json['details'] as Map<String, dynamic>);

  const BykcCourse._unnamed()
    : id = 0,
      name = '',
      teacher = null,
      position = null,
      category = null,
      subcategory = null,
      details = null;

  final int id;
  final String name;
  final String? teacher, position, category, subcategory;
  final BykcCourseDetails? details;

  /// Subcategory wins when present; an empty chain stays unclassified.
  String get categoryLabel {
    for (final value in [subcategory, category]) {
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return '未分类';
  }
}

/// Catalog view flattened by core: `terms`, `courses` and the projected
/// `currentTerm` chosen by the shared Beijing semester policy.
class BykcCatalog {
  BykcCatalog.fromJson(Map<String, dynamic> json)
    : currentTerm = json['currentTerm'] == null
          ? null
          : BykcSemester.fromJson(json['currentTerm'] as Map<String, dynamic>),
      courses = (json['courses'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(BykcCourse.fromJson)
          .toList(growable: false);

  final BykcSemester? currentTerm;
  final List<BykcCourse> courses;
}

class BykcChosenRecord {
  BykcChosenRecord.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int? ?? 0,
      course = json['course'] == null
          ? const BykcCourse._unnamed()
          : BykcCourse.fromJson(json['course'] as Map<String, dynamic>),
      selectedAt = json['selectedAt'] as String?,
      checkin = json['checkin'] as int?,
      passed = json['passed'] as int?,
      score = json['score'] as int?;

  final int id;
  final BykcCourse course;
  final String? selectedAt;
  // Null means the school did not disclose the value; it is not zero.
  final int? checkin, passed, score;

  String get attendanceLabel => switch (checkin) {
    1 => '已签到',
    null => '签到待确认',
    final value => '考勤 $value',
  };

  String get resultLabel => switch (passed) {
    1 => '已通过',
    0 => '未通过',
    null => '通过待确认',
    final value => '通过状态 $value',
  };
}

class BykcChosenCourses {
  BykcChosenCourses.fromJson(Map<String, dynamic> json)
    : term = json['term'] == null
          ? null
          : BykcSemester.fromJson(json['term'] as Map<String, dynamic>),
      // Null means no valid semester range was available, not zero selections.
      courses = json['courses'] == null
          ? null
          : (json['courses'] as List)
                .cast<Map<String, dynamic>>()
                .map(BykcChosenRecord.fromJson)
                .toList(growable: false);

  final BykcSemester? term;
  final List<BykcChosenRecord>? courses;
}

class BykcStatisticsEntry {
  BykcStatisticsEntry.fromJson(Map<String, dynamic> json)
    : category = json['category'] as String,
      subcategory = json['subcategory'] as String,
      requiredCount = json['required'] as int,
      completed = json['completed'] as int;

  final String category, subcategory;
  final int requiredCount, completed;

  bool get complete => requiredCount > 0 && completed >= requiredCount;
}

class BykcStatistics {
  BykcStatistics.fromJson(Map<String, dynamic> json)
    : validCourseCount = json['validCourseCount'] as int?,
      entries = (json['entries'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(BykcStatisticsEntry.fromJson)
          .toList(growable: false);

  final int? validCourseCount;
  final List<BykcStatisticsEntry> entries;
}

BykcCatalog bykcCatalog(String payload) =>
    BykcCatalog.fromJson(jsonDecode(payload) as Map<String, dynamic>);

BykcChosenCourses bykcChosenCourses(String payload) =>
    BykcChosenCourses.fromJson(jsonDecode(payload) as Map<String, dynamic>);

BykcStatistics bykcStatistics(String payload) =>
    BykcStatistics.fromJson(jsonDecode(payload) as Map<String, dynamic>);
