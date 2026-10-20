import 'src/rust/api/live.dart' as live;
import 'src/rust/api/live.dart'
    show GradeTermsResponse, RouteChoice, SessionResponse, SessionState;
import 'src/rust/api/mirror.dart' as rust;
import 'src/rust/api/mirror.dart'
    show
        CheckInResponse,
        ClassroomQuery,
        ClassroomResponse,
        DemoScope,
        GradeResponse,
        HomeworkResponse,
        LibraryAreasResponse,
        LibraryBookingsResponse,
        LibraryDemoResponse,
        LibrarySeatsResponse,
        LibrarySlot,
        LibrarySlotsResponse,
        LibraryVenuesResponse,
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
  Future<SessionResponse> setRoute(RouteChoice route);
  Future<bool> clearCache();

  Future<QueryDates> dates(String instant);
  Future<ClassroomResponse> classrooms(DemoScope scope, ClassroomQuery query);
  Future<RuleExamples> rules();
  Future<ScheduleResponse> schedule({
    String? termId,
    int? week,
    bool forceRefresh = false,
  });
  Future<GradeTermsResponse> gradeTerms();
  Future<GradeResponse> grades({String? termCode, bool forceRefresh = false});
  Future<TodayResponse> today({bool forceRefresh = false});
  Future<CheckInResponse> checkin({bool forceRefresh = false});
  Future<CheckInResponse> checkinOnDate(
    String date, {
    bool forceRefresh = false,
  });
  Future<live.ReadOnlyResponse> libraryStats({bool forceRefresh = false});
  Future<LibraryVenuesResponse> libraryVenues({bool forceRefresh = false});
  Future<LibraryAreasResponse> libraryAreas(String libraryId);
  Future<LibrarySlotsResponse> librarySlots(String areaId);
  Future<LibrarySeatsResponse> librarySeats({
    required String areaId,
    required LibrarySlot slot,
  });
  Future<LibraryBookingsResponse> libraryBookings({bool forceRefresh = false});
  Future<live.LibraryHistoryResponse> libraryHistory(
    int page, {
    bool forceRefresh = false,
  });
  Future<HomeworkResponse> homework({bool forceRefresh = false});
  Future<live.HomeworkDetailResponse> homeworkDetail(
    String assignmentId, {
    bool forceRefresh = false,
  });
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
  Future<SessionResponse> setRoute(RouteChoice route) =>
      live.setRoute(route: route);
  @override
  Future<bool> clearCache() => live.clearCache();
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
  Future<ScheduleResponse> schedule({
    String? termId,
    int? week,
    bool forceRefresh = false,
  }) =>
      live.loadSchedule(termId: termId, week: week, forceRefresh: forceRefresh);
  @override
  Future<GradeTermsResponse> gradeTerms() => live.loadGradeTerms();
  @override
  Future<GradeResponse> grades({String? termCode, bool forceRefresh = false}) =>
      live.loadGrades(termCode: termCode, forceRefresh: forceRefresh);
  @override
  Future<TodayResponse> today({bool forceRefresh = false}) =>
      live.loadToday(forceRefresh: forceRefresh);
  @override
  Future<CheckInResponse> checkin({bool forceRefresh = false}) =>
      live.loadCheckinToday(forceRefresh: forceRefresh);
  @override
  Future<CheckInResponse> checkinOnDate(
    String date, {
    bool forceRefresh = false,
  }) => live.loadCheckinOnDate(date: date, forceRefresh: forceRefresh);
  @override
  Future<live.ReadOnlyResponse> libraryStats({bool forceRefresh = false}) =>
      live.loadLibraryStats(forceRefresh: forceRefresh);
  @override
  Future<LibraryVenuesResponse> libraryVenues({bool forceRefresh = false}) =>
      live.loadLibraryVenues(forceRefresh: forceRefresh);
  @override
  Future<LibraryAreasResponse> libraryAreas(String libraryId) =>
      live.loadLibraryAreas(libraryId: libraryId);
  @override
  Future<LibrarySlotsResponse> librarySlots(String areaId) =>
      live.loadLibrarySlots(areaId: areaId);
  @override
  Future<LibrarySeatsResponse> librarySeats({
    required String areaId,
    required LibrarySlot slot,
  }) => live.loadLibrarySeats(
    areaId: areaId,
    slotId: slot.id,
    day: slot.day,
    start: slot.start,
    end: slot.end,
  );
  @override
  Future<LibraryBookingsResponse> libraryBookings({
    bool forceRefresh = false,
  }) => live.loadLibraryBookings(forceRefresh: forceRefresh);
  @override
  Future<live.LibraryHistoryResponse> libraryHistory(
    int page, {
    bool forceRefresh = false,
  }) => live.loadLibraryHistory(page: page, forceRefresh: forceRefresh);
  @override
  Future<HomeworkResponse> homework({bool forceRefresh = false}) =>
      live.loadHomework(forceRefresh: forceRefresh);
  @override
  Future<live.HomeworkDetailResponse> homeworkDetail(
    String assignmentId, {
    bool forceRefresh = false,
  }) => live.loadHomeworkDetail(
    assignmentId: assignmentId,
    forceRefresh: forceRefresh,
  );
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
