import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/evaluation.dart';
import 'package:ginkgo_mirror/application/service_health.dart';
import 'package:ginkgo_mirror/infrastructure/native_command.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' as live;

EvaluationCourseStatus _decodeEvaluationStatus(
  live.EvaluationCourseStatusDto status,
) => switch (status) {
  live.EvaluationCourseStatusDto.pending => EvaluationCourseStatus.pending,
  live.EvaluationCourseStatusDto.completed => EvaluationCourseStatus.completed,
  live.EvaluationCourseStatusDto.unknown => EvaluationCourseStatus.unknown,
};

TeachingEvaluationRead decodeTeachingEvaluation(
  live.TeachingEvaluationResponse response,
) {
  final report = response.data;
  if (report == null) {
    return TeachingEvaluationRead(
      failure: response.failure ?? FailureCode.changedResponse,
    );
  }
  return TeachingEvaluationRead(
    data: TeachingEvaluationReport(
      taskId: report.taskId,
      taskName: report.taskName,
      term: report.term,
      courses: List.unmodifiable(
        report.courses.map(
          (course) => EvaluationCourseItem(
            id: course.id,
            courseName: course.courseName,
            teacherName: course.teacherName,
            questionnaireName: course.questionnaireName,
            category: course.category,
            status: _decodeEvaluationStatus(course.status),
          ),
        ),
      ),
      fetchedAt: report.fetchedAt,
      fromCache: report.fromCache,
      stale: report.stale,
    ),
    failure: response.failure,
  );
}

mixin NativeEvaluation implements TeachingEvaluationGateway {
  String? get expectedAccount;

  @override
  Future<TeachingEvaluationRead> loadTeachingEvaluation({
    bool forceRefresh = false,
  }) async {
    final owner = expectedAccount;
    if (owner == null || owner.isEmpty) {
      return const TeachingEvaluationRead(failure: FailureCode.sessionExpired);
    }
    return ServiceHealthTracker.shared.observe(
      ServiceEndpointId.teachingEvaluation,
      () async => decodeTeachingEvaluation(
        await boundedNativeRead(
          () => live.loadTeachingEvaluation(
            expectedAccount: owner,
            forceRefresh: forceRefresh,
          ),
        ),
      ),
      failureOf: (r) => r.failure,
      staleOf: (r) => r.data?.stale ?? false,
      cachedOf: (r) => r.data?.fromCache ?? false,
    );
  }
}
