import 'src/rust/api/mirror.dart';

abstract interface class MirrorService {
  Future<QueryDates> dates(String instant);
  Future<ClassroomResponse> classrooms(DemoScope scope, ClassroomQuery query);
  Future<RuleExamples> rules();
  Future<ScheduleResponse> schedule();
  Future<GradeResponse> grades();
  Future<TodayResponse> today();
  Future<HomeworkResponse> homework();
}

final class NativeMirrorService implements MirrorService {
  const NativeMirrorService();
  @override
  Future<QueryDates> dates(String instant) => loadQueryDates(instant: instant);
  @override
  Future<ClassroomResponse> classrooms(DemoScope scope, ClassroomQuery query) =>
      queryDemoClassrooms(scope: scope, query: query);
  @override
  Future<RuleExamples> rules() => loadRuleExamples();
  @override
  Future<ScheduleResponse> schedule() => loadDemoSchedule();
  @override
  Future<GradeResponse> grades() => loadDemoGrades();
  @override
  Future<TodayResponse> today() => loadDemoToday();
  @override
  Future<HomeworkResponse> homework() => loadDemoHomework();
}
