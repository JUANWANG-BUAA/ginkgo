import 'dart:convert';

/// Presentation values projected by Rust; no upstream fields or status inference.
class GraduateRow {
  GraduateRow.fromJson(Map<String, dynamic> json)
    : title = json['title'] as String,
      detail = json['detail'] as String,
      isCourse = json['isCourse'] == true,
      completed = json['completed'] as bool?,
      credit = json['credit'] as num?,
      semester = json['semester'] as String?;

  final String title, detail;
  final bool isCourse;
  final bool? completed;
  final num? credit;
  final String? semester;
}

/// Credit requirement projection (camelCase). Absent values stay null;
/// pending credits never reduce the gap.
class GraduateProgress {
  GraduateProgress.fromJson(Map<String, dynamic> json)
    : requiredCredits = json['required'] as num?,
      earned = json['earned'] as num?,
      pending = json['pending'] as num?;

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
  GraduateSection.fromJson(Map<String, dynamic> json)
    : title = json['title'] as String,
      rows = (json['rows'] as List)
          .map((row) => GraduateRow.fromJson(row as Map<String, dynamic>))
          .toList(growable: false),
      progress = json['progress'] == null
          ? null
          : GraduateProgress.fromJson(json['progress'] as Map<String, dynamic>);

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
  GraduateReport.fromJson(Map<String, dynamic> json)
    : sections = (json['sections'] as List? ?? const [])
          .map(
            (section) =>
                GraduateSection.fromJson(section as Map<String, dynamic>),
          )
          .toList(growable: false),
      notice = json['notice'] as String?;

  final List<GraduateSection> sections;
  final String? notice;
}

GraduateReport? graduateReport(String? payload) => payload == null
    ? null
    : GraduateReport.fromJson(jsonDecode(payload) as Map<String, dynamic>);

/// Liveness count for diagnostics: rows are counted as the school emitted
/// them, without requiring every presentation field to be present.
int graduatePayloadRowCount(String? payload) {
  if (payload == null) return 0;
  try {
    final sections = (jsonDecode(payload) as Map<String, dynamic>)['sections'];
    if (sections is! List) return 0;
    return sections.fold<int>(0, (sum, section) {
      final rows = section is Map ? section['rows'] : null;
      return sum + (rows is List ? rows.length : 0);
    });
  } catch (_) {
    return 0;
  }
}
