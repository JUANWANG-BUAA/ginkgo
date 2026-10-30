import 'package:ginkgo_mirror/application/contracts.dart';

/// Presentation values projected by Rust; no upstream fields or status inference.
class GraduateRow {
  const GraduateRow({
    required this.title,
    required this.detail,
    required this.isCourse,
    this.completed,
    this.credit,
    this.semester,
  });

  final String title, detail;
  final bool isCourse;
  final bool? completed;
  final num? credit;
  final String? semester;
}

/// Credit requirement projection (camelCase). Absent values stay null;
/// pending credits never reduce the gap.
class GraduateProgress {
  const GraduateProgress({this.requiredCredits, this.earned, this.pending});

  final num? requiredCredits, earned, pending;

  /// Recognized share of the requirement. Null while either side is unknown:
  /// a missing number never reads as a zero-percent result.
  double? get earnedRatio {
    final required = requiredCredits;
    final value = earned;
    if (required == null || required <= 0 || value == null) return null;
    return (value / required).clamp(0.0, 1.0).toDouble();
  }

  /// Pending share of the requirement. Pending credits are never counted as
  /// earned, so they only widen the gap.
  double get pendingRatio {
    final required = requiredCredits;
    final value = pending;
    if (required == null || required <= 0 || value == null) return 0;
    return (value / required).clamp(0.0, 1.0).toDouble();
  }

  /// Credits still missing; null while either side is unknown.
  num? get remaining {
    final required = requiredCredits;
    final value = earned;
    if (required == null || value == null) return null;
    return (required - value).clamp(0, double.infinity);
  }
}

class GraduateSection {
  const GraduateSection({
    required this.title,
    required this.rows,
    this.progress,
  });

  final String title;
  final List<GraduateRow> rows;
  final GraduateProgress? progress;
}

class GraduateCourseEntry {
  const GraduateCourseEntry(this.section, this.row);
  final String section;
  final GraduateRow row;
}

enum GraduateCourseFilter {
  all('全部状态'),
  incomplete('未完成'),
  completed('已完成'),
  unknown('待确认');

  const GraduateCourseFilter(this.label);
  final String label;

  bool accepts(GraduateRow row) => switch (this) {
    all => true,
    incomplete => row.completed == false,
    completed => row.completed == true,
    unknown => row.completed == null,
  };
}

/// The three lenses on the graduate page.
enum GraduateView { credits, courses, profile }

/// Full report envelope: sections plus the school's own notice line.
class GraduateReport {
  const GraduateReport({required this.sections, this.notice});

  final List<GraduateSection> sections;
  final String? notice;
}

class GraduateRead {
  const GraduateRead({this.data, this.failure});
  final GraduateReport? data;
  final FailureCode? failure;
}
