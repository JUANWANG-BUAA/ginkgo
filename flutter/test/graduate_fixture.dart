import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/graduate.dart';

/// Test fixtures stay map-shaped; production now receives a typed DTO.
GraduateRead graduateRead(Map<String, dynamic>? json, {FailureCode? failure}) {
  if (json == null) return GraduateRead(failure: failure);
  final sections = (json['sections'] as List? ?? const [])
      .cast<Map<String, dynamic>>();
  return GraduateRead(
    data: GraduateReport(
      notice: json['notice'] as String?,
      sections: [
        for (final section in sections)
          GraduateSection(
            title: section['title'] as String? ?? '',
            progress: section['progress'] == null
                ? null
                : _progress(section['progress'] as Map<String, dynamic>),
            rows: [
              for (final row
                  in (section['rows'] as List? ?? const [])
                      .cast<Map<String, dynamic>>())
                GraduateRow(
                  title: row['title'] as String? ?? '',
                  detail: row['detail'] as String? ?? '',
                  isCourse: row['isCourse'] == true,
                  completed: row['completed'] as bool?,
                  credit: row['credit'] as num?,
                  semester: row['semester'] as String?,
                ),
            ],
          ),
      ],
    ),
    failure: failure,
  );
}

GraduateProgress _progress(Map<String, dynamic> json) => GraduateProgress(
  requiredCredits: json['required'] as num?,
  earned: json['earned'] as num?,
  pending: json['pending'] as num?,
);
