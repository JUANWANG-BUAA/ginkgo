import '../application/bykc.dart';
import '../application/contracts.dart';
import '../src/rust/api/live.dart' as live;

BykcSemester _semester(live.BykcSemesterDto dto) =>
    BykcSemester(id: dto.id, name: dto.name, start: dto.start, end: dto.end);

BykcCourse _course(live.BykcCourseDto dto) => BykcCourse(
  id: dto.id,
  name: dto.name,
  teacher: dto.teacher,
  position: dto.position,
  category: dto.category,
  subcategory: dto.subcategory,
  details: dto.details == null
      ? null
      : BykcCourseDetails(
          start: dto.details!.start,
          end: dto.details!.end,
          selectStart: dto.details!.selectStart,
          selectEnd: dto.details!.selectEnd,
          cancelEnd: dto.details!.cancelEnd,
          capacity: dto.details!.capacity,
          enrolled: dto.details!.enrolled,
          campuses: List.unmodifiable(dto.details!.campuses),
          summary: dto.details!.summary,
          selected: dto.details!.selected,
          hasSignConfig: dto.details!.hasSignConfig,
        ),
);

BykcCatalogRead decodeBykcCatalog(live.BykcCatalogResponse response) {
  final data = response.data;
  if (data == null) {
    return BykcCatalogRead(
      failure: response.failure ?? FailureCode.changedResponse,
    );
  }
  return BykcCatalogRead(
    data: BykcCatalog(
      currentTerm: data.currentTerm == null
          ? null
          : _semester(data.currentTerm!),
      courses: List.unmodifiable(data.courses.map(_course)),
    ),
    failure: response.failure,
  );
}

BykcChosenRead decodeBykcChosen(live.BykcChosenResponse response) {
  final data = response.data;
  if (data == null) {
    return BykcChosenRead(
      failure: response.failure ?? FailureCode.changedResponse,
    );
  }
  return BykcChosenRead(
    data: BykcChosenCourses(
      term: data.term == null ? null : _semester(data.term!),
      // Null stays null: an unusable semester range is not zero selections.
      courses: data.courses
          ?.map((record) {
            return BykcChosenRecord(
              id: record.id,
              course: _course(record.course),
              selectedAt: record.selectedAt,
              checkin: record.checkin,
              passed: record.passed,
              score: record.score,
            );
          })
          .toList(growable: false),
    ),
    failure: response.failure,
  );
}

BykcStatisticsRead decodeBykcStatistics(live.BykcStatisticsResponse response) {
  final data = response.data;
  if (data == null) {
    return BykcStatisticsRead(
      failure: response.failure ?? FailureCode.changedResponse,
    );
  }
  return BykcStatisticsRead(
    data: BykcStatistics(
      validCourseCount: data.validCourseCount,
      entries: List.unmodifiable(
        data.entries.map(
          (entry) => BykcStatisticsEntry(
            category: entry.category,
            subcategory: entry.subcategory,
            requiredCount: entry.required_,
            completed: entry.completed,
          ),
        ),
      ),
    ),
    failure: response.failure,
  );
}
