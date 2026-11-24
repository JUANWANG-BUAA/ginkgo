import 'package:ginkgo_mirror/application/failure_code.dart';

enum EvaluationCourseStatus { pending, completed, unknown }

class EvaluationCourseItem {
  const EvaluationCourseItem({
    required this.id,
    required this.courseName,
    this.teacherName,
    this.questionnaireName,
    this.category,
    required this.status,
  });

  final String id;
  final String courseName;
  final String? teacherName;
  final String? questionnaireName;
  final String? category;
  final EvaluationCourseStatus status;
}

class TeachingEvaluationReport {
  const TeachingEvaluationReport({
    this.taskId,
    this.taskName,
    this.term,
    required this.courses,
    required this.fetchedAt,
    this.fromCache = false,
    this.stale = false,
  });

  final String? taskId;
  final String? taskName;
  final String? term;
  final List<EvaluationCourseItem> courses;
  final String fetchedAt;
  final bool fromCache;
  final bool stale;

  int get completedCount => courses
      .where((c) => c.status == EvaluationCourseStatus.completed)
      .length;

  int get pendingCount =>
      courses.where((c) => c.status == EvaluationCourseStatus.pending).length;

  int get unknownCount =>
      courses.where((c) => c.status == EvaluationCourseStatus.unknown).length;
}

class TeachingEvaluationRead {
  const TeachingEvaluationRead({this.data, this.failure});

  final TeachingEvaluationReport? data;
  final FailureCode? failure;
}

abstract interface class TeachingEvaluationGateway {
  Future<TeachingEvaluationRead> loadTeachingEvaluation({
    bool forceRefresh = false,
  });
}
