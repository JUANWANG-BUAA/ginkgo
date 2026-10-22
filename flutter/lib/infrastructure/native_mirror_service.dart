import 'dart:convert';

import '../application/contracts.dart';
import '../application/mirror_service.dart';
import '../src/rust/api/live.dart' as live;
import '../src/rust/api/mirror.dart' as rust;

final class NativeMirrorService implements MirrorService, CgyyBookingGateway {
  const NativeMirrorService();
  @override
  Future<ReadOnlyResponse> executeCgyy(Map<String, Object?> command) =>
      live.executeCgyy(command: jsonEncode(command));
  @override
  Future<live.ReadOnlyResponse> checkinProgress() => live.checkinLoadProgress();
  @override
  Future<live.ReadOnlyResponse> bykcPart(
    BykcPart part, {
    bool forceRefresh = false,
  }) => switch (part) {
    BykcPart.catalog => live.loadBykc(forceRefresh: forceRefresh),
    BykcPart.chosen => live.loadBykcChosen(forceRefresh: forceRefresh),
    BykcPart.statistics => live.loadBykcStatistics(forceRefresh: forceRefresh),
  };
  @override
  Future<live.ReadOnlyResponse> graduatePart({
    required bool report,
    required bool forceRefresh,
  }) => live.loadGraduatePart(report: report, forceRefresh: forceRefresh);
  @override
  Future<live.ReadOnlyResponse> notices({bool forceRefresh = false}) =>
      live.loadNotices(forceRefresh: forceRefresh);
  @override
  Future<live.ReadOnlyResponse> cgyy({
    required String kind,
    required int siteId,
    required String date,
    required bool forceRefresh,
  }) => live.loadCgyy(
    kind: kind,
    siteId: siteId,
    date: date,
    forceRefresh: forceRefresh,
  );
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
    demo: false,
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
  }) => live.reserveLibrarySeat(areaId: areaId, seatId: seatId, slot: slot);
  @override
  Future<live.MutationResponse> performLibraryAction(
    String bookingId,
    String action,
  ) => live.performLibraryAction(bookingId: bookingId, action: action);
  @override
  Future<live.MutationResponse> submitCheckin(String courseId) =>
      live.submitCheckin(courseId: courseId);
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
