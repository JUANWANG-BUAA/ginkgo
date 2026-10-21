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

  String get completionLabel => switch (completed) {
    true => '已完成',
    false => '未完成',
    null => '待确认',
  };
}

class GraduateSection {
  GraduateSection.fromJson(Map<String, dynamic> json)
    : title = json['title'] as String,
      rows = (json['rows'] as List)
          .map((row) => GraduateRow.fromJson(row as Map<String, dynamic>))
          .toList(growable: false),
      progress = json['progress'] as Map<String, dynamic>?;

  final String title;
  final List<GraduateRow> rows;
  final Map<String, dynamic>? progress;
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
