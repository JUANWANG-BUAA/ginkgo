import 'src/rust/api/live.dart' as live;
import 'src/rust/api/live.dart' show SessionResponse, SessionState;
import 'src/rust/api/mirror.dart' as rust;
import 'src/rust/api/mirror.dart'
    show
        ClassroomQuery,
        ClassroomResponse,
        DemoScope,
        GradeResponse,
        HomeworkResponse,
        QueryDates,
        RuleExamples,
        ScheduleResponse,
        TodayResponse;

/// Page-facing boundary. Live and demo services share one interface so widget
/// tests never need a real Rust library or account.
abstract interface class MirrorService {
  bool get isDemo;

  Future<SessionResponse> restoreSession();
  Future<SessionResponse> login({
    required String account,
    required String password,
    String? captcha,
    required bool remember,
  });
  Future<SessionResponse> signOut();

  Future<QueryDates> dates(String instant);
  Future<ClassroomResponse> classrooms(DemoScope scope, ClassroomQuery query);
  Future<RuleExamples> rules();
  Future<ScheduleResponse> schedule({bool forceRefresh = false});
  Future<GradeResponse> grades({bool forceRefresh = false});
  Future<TodayResponse> today({bool forceRefresh = false});
  Future<HomeworkResponse> homework();
}

final class NativeMirrorService implements MirrorService {
  const NativeMirrorService();
  @override
  bool get isDemo => false;
  @override
  Future<SessionResponse> restoreSession() => live.restoreSession();
  @override
  Future<SessionResponse> login({
    required String account,
    required String password,
    String? captcha,
    required bool remember,
  }) => live.login(
    account: account,
    password: password,
    captcha: captcha,
    remember: remember,
  );
  @override
  Future<SessionResponse> signOut() => live.signOut();
  @override
  Future<QueryDates> dates(String instant) =>
      rust.loadQueryDates(instant: instant);
  @override
  Future<ClassroomResponse> classrooms(DemoScope scope, ClassroomQuery query) =>
      live.loadClassrooms(
        scope: live.LiveScope(
          campus: scope.campus,
          date: scope.date,
          forceRefresh: scope.forceRefresh,
        ),
        query: query,
      );
  @override
  Future<RuleExamples> rules() => rust.loadRuleExamples();
  @override
  Future<ScheduleResponse> schedule({bool forceRefresh = false}) =>
      live.loadSchedule(forceRefresh: forceRefresh);
  @override
  Future<GradeResponse> grades({bool forceRefresh = false}) =>
      live.loadGrades(forceRefresh: forceRefresh);
  @override
  Future<TodayResponse> today({bool forceRefresh = false}) =>
      live.loadToday(forceRefresh: forceRefresh);
  @override
  Future<HomeworkResponse> homework() => rust.loadDemoHomework();
}

final class DemoMirrorService implements MirrorService {
  const DemoMirrorService();
  @override
  bool get isDemo => true;
  @override
  Future<SessionResponse> restoreSession() async =>
      const SessionResponse(state: SessionState.signedOut, remembered: false);
  @override
  Future<SessionResponse> login({
    required String account,
    required String password,
    String? captcha,
    required bool remember,
  }) async =>
      const SessionResponse(state: SessionState.signedIn, remembered: false);
  @override
  Future<SessionResponse> signOut() async =>
      const SessionResponse(state: SessionState.signedOut, remembered: false);
  @override
  Future<QueryDates> dates(String instant) =>
      rust.loadQueryDates(instant: instant);
  @override
  Future<ClassroomResponse> classrooms(DemoScope scope, ClassroomQuery query) =>
      rust.queryDemoClassrooms(scope: scope, query: query);
  @override
  Future<RuleExamples> rules() => rust.loadRuleExamples();
  @override
  Future<ScheduleResponse> schedule({bool forceRefresh = false}) =>
      rust.loadDemoSchedule();
  @override
  Future<GradeResponse> grades({bool forceRefresh = false}) =>
      rust.loadDemoGrades();
  @override
  Future<TodayResponse> today({bool forceRefresh = false}) =>
      rust.loadDemoToday();
  @override
  Future<HomeworkResponse> homework() => rust.loadDemoHomework();
}
