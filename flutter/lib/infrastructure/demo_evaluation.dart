import 'package:ginkgo_mirror/application/evaluation.dart';

mixin DemoEvaluation implements TeachingEvaluationGateway {
  @override
  Future<TeachingEvaluationRead> loadTeachingEvaluation({
    bool forceRefresh = false,
  }) async => const TeachingEvaluationRead(
    data: TeachingEvaluationReport(
      taskId: 'synthetic-eval-task',
      taskName: '2026秋季学期课程评教示例',
      term: '2026-20271',
      courses: [
        EvaluationCourseItem(
          id: 'eval-demo-1',
          courseName: '软件工程基础（演示）',
          teacherName: '李文',
          questionnaireName: '理论课问卷',
          status: EvaluationCourseStatus.pending,
        ),
        EvaluationCourseItem(
          id: 'eval-demo-2',
          courseName: '计算机系统实验（演示）',
          teacherName: '张敏',
          questionnaireName: '实践课问卷',
          status: EvaluationCourseStatus.completed,
        ),
      ],
      fetchedAt: '2026-11-23T12:00:00+08:00',
    ),
  );
}
