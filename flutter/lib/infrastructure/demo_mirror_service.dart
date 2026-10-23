import '../application/contracts.dart';
import '../application/mirror_service.dart';
import '../src/rust/api/live.dart' as live;
import '../src/rust/api/mirror.dart' as rust;

final class DemoMirrorService implements MirrorService {
  const DemoMirrorService();
  @override
  Future<live.ReadOnlyResponse> checkinProgress() async =>
      const live.ReadOnlyResponse(stale: false);
  @override
  Future<live.ReadOnlyResponse> bykcPart(
    BykcPart part, {
    bool forceRefresh = false,
  }) => switch (part) {
    BykcPart.catalog => live.loadDemoBykc(),
    BykcPart.chosen => live.loadDemoBykcChosen(),
    BykcPart.statistics => live.loadDemoBykcStatistics(),
  };
  @override
  Future<live.ReadOnlyResponse> graduatePart({
    required bool report,
    required bool forceRefresh,
  }) => report ? live.loadDemoGraduate() : live.loadDemoGraduateStatus();
  @override
  Future<live.ReadOnlyResponse> notices({bool forceRefresh = false}) =>
      live.loadDemoNotices();
  @override
  Future<live.ReadOnlyResponse> cgyy({
    required String kind,
    required int siteId,
    required String date,
    required bool forceRefresh,
  }) => live.loadDemoCgyy(kind: kind);
  @override
  Future<live.ReadOnlyResponse> editTasks({
    required String root,
    required String action,
    String? id,
    String? title,
    String? due,
    bool? completed,
  }) => live.editTasks(
    root: root,
    demo: true,
    action: action,
    id: id,
    title: title,
    due: due,
    completed: completed,
  );
  @override
  Future<bool> verifyBridgeContract() async {
    final result = await rust.loadDemoSchedule();
    return result.failure == null && result.courses.isNotEmpty;
  }

  @override
  Future<live.MutationResponse> reserveLibrarySeat({
    required String areaId,
    required String seatId,
    required LibrarySlot slot,
  }) async =>
      const live.MutationResponse(state: 'notSubmitted', message: '演示模式不会提交预约');
  @override
  Future<live.MutationResponse> performLibraryAction(
    String bookingId,
    String action,
  ) async =>
      const live.MutationResponse(state: 'notSubmitted', message: '演示模式不会修改预约');
  @override
  Future<live.MutationResponse> submitCheckin(String courseId) async =>
      const live.MutationResponse(state: 'notSubmitted', message: '演示模式不会提交签到');
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
  Future<SessionResponse> setRoute(RouteChoice route) async =>
      const SessionResponse(state: SessionState.signedOut, remembered: false);
  @override
  Future<bool> clearCache() async => true;
  @override
  Future<QueryDates> dates(String instant) =>
      rust.loadQueryDates(instant: instant);
  @override
  Future<ClassroomResponse> classrooms(DemoScope scope, ClassroomQuery query) =>
      rust.queryDemoClassrooms(scope: scope, query: query);
  @override
  Future<RuleExamples> rules() => rust.loadRuleExamples();
  @override
  Future<ScheduleResponse> schedule({
    String? termId,
    int? week,
    bool forceRefresh = false,
  }) => rust.loadDemoSchedule();
  @override
  Future<GradeTermsResponse> gradeTerms() async {
    final schedule = await rust.loadDemoSchedule();
    return GradeTermsResponse(terms: schedule.terms);
  }

  @override
  Future<GradeResponse> grades({String? termCode, bool forceRefresh = false}) =>
      rust.loadDemoGrades();
  @override
  Future<TodayResponse> today({bool forceRefresh = false}) =>
      rust.loadDemoToday();
  @override
  Future<CheckInResponse> checkin({bool forceRefresh = false}) =>
      rust.loadDemoCheckin();
  @override
  Future<CheckInResponse> checkinOnDate(
    String date, {
    bool forceRefresh = false,
  }) async {
    final result = await rust.loadDemoCheckin();
    return CheckInResponse(
      date: date,
      courses: result.courses,
      fetchedAt: result.fetchedAt,
      fromCache: false,
      stale: false,
    );
  }

  Future<LibraryDemoResponse> _demoLibrary() => rust.loadDemoLibrary();
  @override
  Future<live.ReadOnlyResponse> libraryStats({bool forceRefresh = false}) =>
      live.loadDemoLibraryStats();
  @override
  Future<live.ReadOnlyResponse> libraryBooks({
    required String query,
    required int page,
  }) async => const live.ReadOnlyResponse(
    payload: '{"page":1,"pageSize":20,"total":0,"actualTotal":0,'
        '"items":[],"hasMore":false}',
    stale: false,
  );
  @override
  Future<live.ReadOnlyResponse> libraryHoldings(String bibId) async =>
      const live.ReadOnlyResponse(payload: '[]', stale: false);
  @override
  Future<LibraryVenuesResponse> libraryVenues({
    bool forceRefresh = false,
  }) async {
    final library = await _demoLibrary();
    return LibraryVenuesResponse(
      venues: library.venues,
      fromCache: false,
      stale: false,
    );
  }

  @override
  Future<LibraryAreasResponse> libraryAreas(String libraryId) async {
    final library = await _demoLibrary();
    return LibraryAreasResponse(areas: library.areas);
  }

  @override
  Future<LibrarySlotsResponse> librarySlots(String areaId) async {
    final library = await _demoLibrary();
    return LibrarySlotsResponse(slots: library.slots);
  }

  @override
  Future<LibrarySeatsResponse> librarySeats({
    required String areaId,
    required LibrarySlot slot,
  }) async {
    final library = await _demoLibrary();
    return LibrarySeatsResponse(seats: library.seats);
  }

  @override
  Future<LibraryBookingsResponse> libraryBookings({
    bool forceRefresh = false,
  }) async {
    final library = await _demoLibrary();
    return LibraryBookingsResponse(
      bookings: library.bookings,
      fromCache: false,
      stale: false,
    );
  }

  @override
  Future<live.LibraryHistoryResponse> libraryHistory(
    int page, {
    bool forceRefresh = false,
  }) async => live.loadDemoLibraryHistory(page: page);
  @override
  Future<HomeworkResponse> homework({bool forceRefresh = false}) =>
      rust.loadDemoHomework();
  @override
  Future<live.HomeworkDetailResponse> homeworkDetail(
    String assignmentId, {
    bool forceRefresh = false,
  }) async => const live.HomeworkDetailResponse(
    content: '合成作业说明：阅读教材并完成练习。',
    status: '待完成',
    stale: false,
  );
}
