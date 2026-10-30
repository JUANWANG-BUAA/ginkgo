import '../application/contracts.dart';
import '../application/graduate.dart';
import '../src/rust/api/live.dart' as live;

GraduateRead decodeGraduate(live.GraduateResponse response) {
  final data = response.data;
  if (data == null) {
    return GraduateRead(
      failure: response.failure ?? FailureCode.changedResponse,
    );
  }
  return GraduateRead(
    data: GraduateReport(
      notice: data.notice,
      sections: List.unmodifiable(
        data.sections.map(
          (section) => GraduateSection(
            title: section.title,
            progress: section.progress == null
                ? null
                : GraduateProgress(
                    requiredCredits: section.progress!.required_,
                    earned: section.progress!.earned,
                    pending: section.progress!.pending,
                  ),
            rows: List.unmodifiable(
              section.rows.map(
                (row) => GraduateRow(
                  title: row.title,
                  detail: row.detail,
                  isCourse: row.isCourse,
                  completed: row.completed,
                  credit: row.credit,
                  semester: row.semester,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    failure: response.failure,
  );
}
