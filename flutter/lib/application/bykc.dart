import 'package:ginkgo_mirror/application/contracts.dart';

/// Typed BYKC values projected by Rust. Course fields keep the school's
/// snake_case; nothing here parses an upstream response.

class BykcSemester {
  const BykcSemester({
    required this.id,
    required this.name,
    this.start,
    this.end,
  });

  final String id, name;
  final String? start, end;
}

/// Course enrollment details. Absent values stay null; they are never
/// converted into zeros or guessed text.
class BykcCourseDetails {
  const BykcCourseDetails({
    this.start,
    this.end,
    this.selectStart,
    this.selectEnd,
    this.cancelEnd,
    this.capacity,
    this.enrolled,
    this.campuses = const [],
    this.summary,
    this.selected,
    this.hasSignConfig,
  });

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
  const BykcCourse({
    required this.id,
    required this.name,
    this.teacher,
    this.position,
    this.category,
    this.subcategory,
    this.details,
  });

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
  const BykcCatalog({required this.courses, this.currentTerm});

  final BykcSemester? currentTerm;
  final List<BykcCourse> courses;
}

class BykcChosenRecord {
  const BykcChosenRecord({
    required this.id,
    required this.course,
    this.selectedAt,
    this.checkin,
    this.passed,
    this.score,
  });

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
  const BykcChosenCourses({this.term, this.courses});

  final BykcSemester? term;
  final List<BykcChosenRecord>? courses;
}

class BykcStatisticsEntry {
  const BykcStatisticsEntry({
    required this.category,
    required this.subcategory,
    required this.requiredCount,
    required this.completed,
  });

  final String category, subcategory;
  final int requiredCount, completed;

  bool get complete => requiredCount > 0 && completed >= requiredCount;
}

class BykcStatistics {
  const BykcStatistics({required this.entries, this.validCourseCount});

  final int? validCourseCount;
  final List<BykcStatisticsEntry> entries;
}

sealed class BykcPartRead {
  const BykcPartRead();
  FailureCode? get failure;
}

class BykcCatalogRead extends BykcPartRead {
  const BykcCatalogRead({this.data, this.failure});
  final BykcCatalog? data;
  @override
  final FailureCode? failure;
}

class BykcChosenRead extends BykcPartRead {
  const BykcChosenRead({this.data, this.failure});
  final BykcChosenCourses? data;
  @override
  final FailureCode? failure;
}

class BykcStatisticsRead extends BykcPartRead {
  const BykcStatisticsRead({this.data, this.failure});
  final BykcStatistics? data;
  @override
  final FailureCode? failure;
}
