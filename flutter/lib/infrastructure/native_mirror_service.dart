import 'dart:convert';
import 'dart:typed_data';

import '../application/homework_files.dart';

import 'package:path_provider/path_provider.dart';

import '../application/contracts.dart';
import '../application/campus_activities.dart';
import '../application/mirror_service.dart';
import '../src/rust/api/live.dart' as live;
import '../src/rust/api/mirror.dart' as rust;

import 'package:ginkgo_mirror/infrastructure/native_learning.dart';
import 'package:ginkgo_mirror/infrastructure/native_campus_activities.dart';
import 'package:ginkgo_mirror/infrastructure/native_career.dart';
import 'package:ginkgo_mirror/infrastructure/native_library_loans.dart';
import 'package:ginkgo_mirror/infrastructure/learning_snapshot_store.dart';
import 'package:ginkgo_mirror/infrastructure/native_reminder_planning.dart';
import 'package:ginkgo_mirror/infrastructure/graduate_credit_map_payload.dart';
import 'package:ginkgo_mirror/infrastructure/native_command.dart';

final class NativeMirrorService
    with
        NativeLearning,
        NativeCareer,
        NativeCampusActivities,
        NativeReminderPlanning,
        NativeLibraryLoans,
        NativeLearningSnapshots
    implements
        MirrorService,
        CgyyBookingGateway,
        CampusCardGateway,
        StudentServiceLinksGateway,
        HomeworkFilesGateway,
        CareerEventsGateway,
        CampusActivitiesGateway,
        GraduateCreditMapGateway {
  const NativeMirrorService({this.expectedAccount});
  @override
  String? studentServiceUrl(String id) => live.studentServiceUrl(id: id);
  @override
  final String? expectedAccount;

  @override
  Future<live.CampusCardBalanceResponse> campusCardBalance() =>
      boundedNativeRead(() => live.loadCampusCardBalance());

  String get _homeworkOwner {
    final owner = expectedAccount;
    if (owner == null || owner.isEmpty) {
      throw StateError('账号未绑定');
    }
    return owner;
  }

  Map<String, dynamic> _homeworkPayload(live.ReadOnlyResponse response) {
    if (response.failure != null || response.payload == null) {
      throw StateError('作业服务暂不可用，请刷新或前往官网');
    }
    return jsonDecode(response.payload!) as Map<String, dynamic>;
  }

  Future<void> _prepareHomework() async {
    final root = await getApplicationSupportDirectory();
    final canonical = await root.resolveSymbolicLinks();
    final r = await boundedNativeRead(
      () => live.configureHomeworkRecovery(
        expectedAccount: _homeworkOwner,
        storageRoot: canonical,
      ),
    );
    if (r.failure != null) {
      throw StateError('提交保护存储不可用，已阻止写入；附件读取不受影响');
    }
  }

  @override
  Future<List<HomeworkPendingSubmission>> pendingHomeworkSubmissions({
    String? assignmentId,
  }) async {
    await _prepareHomework();
    final r = await boundedNativeRead(
      () => live.pendingHomeworkSubmissions(
        expectedAccount: _homeworkOwner,
        assignmentId: assignmentId,
      ),
    );
    if (r.failure != null || r.payload == null) {
      throw StateError('未能读取待核实提交，请勿重复提交');
    }
    return (jsonDecode(r.payload!) as List)
        .map(
          (v) => HomeworkPendingSubmission.fromJson(v as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  @override
  Future<List<HomeworkCapabilityEvidence>> homeworkCapabilities(
    String assignmentId,
  ) async {
    await _prepareHomework();
    final r = await boundedNativeRead(
      () => live.homeworkCapabilities(
        expectedAccount: _homeworkOwner,
        assignmentId: assignmentId,
      ),
    );
    if (r.failure != null || r.payload == null) {
      throw StateError('作业接口状态检测失败，请重新登录或重试');
    }
    return (jsonDecode(r.payload!) as List)
        .map(
          (v) => HomeworkCapabilityEvidence.fromJson(v as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  @override
  Future<GraduateCreditMapRead> graduateCreditMap({
    bool forceRefresh = false,
  }) async => decodeGraduateCreditMapRead(
    await boundedNativeRead(
      () => live.loadGraduateCreditMap(
        expectedAccount: _homeworkOwner,
        forceRefresh: forceRefresh,
      ),
    ),
  );

  @override
  Future<HomeworkFileWorkspace> homeworkFiles(String assignmentId) async =>
      HomeworkFileWorkspace.fromJson(
        _homeworkPayload(
          await boundedNativeRead(
            () => live.homeworkFileWorkspace(
              expectedAccount: _homeworkOwner,
              assignmentId: assignmentId,
            ),
          ),
        ),
      );
  @override
  Future<HomeworkFileReceipt> uploadHomeworkFile(
    String assignmentId,
    String name,
    Uint8List bytes,
  ) async {
    await _prepareHomework();
    final j = _homeworkPayload(
      await boundedNativeWrite(
        () => live.uploadHomeworkFile(
          expectedAccount: _homeworkOwner,
          assignmentId: assignmentId,
          name: name,
          bytes: bytes,
        ),
      ),
    );
    return HomeworkFileReceipt(
      j['handle'] as String,
      j['fileName'] as String,
      j['size'] as int,
    );
  }

  @override
  Future<MutationResponse> submitHomeworkFile(String handle) async {
    await _prepareHomework();
    return boundedNativeWrite(
      () => live.submitHomeworkFile(
        expectedAccount: _homeworkOwner,
        handle: handle,
        confirmed: true,
      ),
    );
  }

  @override
  Future<MutationResponse> reconcileHomeworkFile(String handle) => live
      .reconcileHomeworkFile(expectedAccount: _homeworkOwner, handle: handle);
  @override
  Future<HomeworkFileDownload> downloadHomeworkFile(
    String assignmentId,
    String attachmentId,
  ) async {
    final r = await boundedNativeWrite(
      () => live.downloadHomeworkFile(
        expectedAccount: _homeworkOwner,
        assignmentId: assignmentId,
        attachmentId: attachmentId,
      ),
    );
    if (r.failure != null || r.bytes == null || r.name == null) {
      throw StateError('附件下载失败，请前往官网');
    }
    return HomeworkFileDownload(r.name!, Uint8List.fromList(r.bytes!));
  }

  @override
  Future<ReadOnlyResponse> executeCgyy(Map<String, Object?> command) async {
    // Old routes/callbacks must not mutate a newly authenticated account.
    // This value is a precondition only; Rust still derives the actual owner.
    if (expectedAccount?.isNotEmpty != true) {
      throw StateError('CGYY requires an account-bound workspace');
    }
    final root = await getApplicationSupportDirectory();
    return boundedNativeWrite(
      () => live.executeCgyy(
        command: jsonEncode({
          ...command,
          'storage_root': root.path,
          'expected_account': expectedAccount,
        }),
      ),
    );
  }

  @override
  Future<live.ReadOnlyResponse> checkinProgress() =>
      boundedNativeRead(() => live.checkinLoadProgress());
  @override
  Future<live.ReadOnlyResponse> bykcPart(
    BykcPart part, {
    bool forceRefresh = false,
  }) => switch (part) {
    BykcPart.catalog => boundedNativeRead(
      () => live.loadBykc(forceRefresh: forceRefresh),
    ),
    BykcPart.chosen => boundedNativeRead(
      () => live.loadBykcChosen(forceRefresh: forceRefresh),
    ),
    BykcPart.statistics => boundedNativeRead(
      () => live.loadBykcStatistics(forceRefresh: forceRefresh),
    ),
  };
  @override
  Future<live.ReadOnlyResponse> graduatePart({
    required bool report,
    required bool forceRefresh,
  }) => boundedNativeRead(
    () => live.loadGraduatePart(report: report, forceRefresh: forceRefresh),
  );
  @override
  Future<live.ReadOnlyResponse> notices({bool forceRefresh = false}) =>
      boundedNativeRead(() => live.loadNotices(forceRefresh: forceRefresh));
  @override
  Future<live.ReadOnlyResponse> cgyy({
    required String kind,
    required int siteId,
    required String date,
    required bool forceRefresh,
  }) => boundedNativeRead(
    () => live.loadCgyy(
      kind: kind,
      siteId: siteId,
      date: date,
      forceRefresh: forceRefresh,
    ),
  );
  @override
  Future<live.ReadOnlyResponse> editTasks({
    required String root,
    required String action,
    String? id,
    String? title,
    String? due,
    bool? completed,
  }) => boundedNativeRead(
    () => live.editTasks(
      root: root,
      demo: false,
      action: action,
      id: id,
      title: title,
      due: due,
      completed: completed,
    ),
  );
  @override
  Future<bool> verifyBridgeContract() async {
    final result = await boundedNativeRead(() => rust.loadDemoSchedule());
    return result.failure == null && result.courses.isNotEmpty;
  }

  @override
  Future<live.MutationResponse> reserveLibrarySeat({
    required String areaId,
    required String seatId,
    required LibrarySlot slot,
  }) => boundedNativeWrite(
    () => live.reserveLibrarySeat(areaId: areaId, seatId: seatId, slot: slot),
  );
  @override
  Future<live.MutationResponse> performLibraryAction(
    String bookingId,
    String action,
  ) => boundedNativeWrite(
    () => live.performLibraryAction(bookingId: bookingId, action: action),
  );
  @override
  Future<live.MutationResponse> submitCheckin(String courseId) =>
      boundedNativeWrite(() => live.submitCheckin(courseId: courseId));
  @override
  bool get isDemo => false;
  @override
  Future<SessionResponse> restoreSession() =>
      boundedNativeWrite(() => live.restoreSession());
  @override
  Future<SessionResponse> login({
    required String account,
    required String password,
    String? captcha,
    required bool remember,
  }) => boundedNativeWrite(
    () => live.login(
      account: account,
      password: password,
      captcha: captcha,
      remember: remember,
    ),
  );
  @override
  Future<SessionResponse> signOut() async {
    try {
      await learningSnapshots.clear();
    } catch (_) {
      /* Storage is fail-closed; authentication must still be revoked. */
    }
    return boundedNativeWrite(() => live.signOut());
  }

  @override
  Future<SessionResponse> setRoute(RouteChoice route) async {
    await learningSnapshots.clear();
    return boundedNativeWrite(() => live.setRoute(route: route));
  }

  @override
  Future<bool> clearCache() async {
    await learningSnapshots.clear();
    return boundedNativeRead(() => live.clearCache());
  }

  @override
  Future<QueryDates> dates(String instant) =>
      boundedNativeRead(() => rust.loadQueryDates(instant: instant));
  @override
  Future<ClassroomResponse> classrooms(DemoScope scope, ClassroomQuery query) =>
      boundedNativeRead(
        () => live.loadClassrooms(
          scope: live.LiveScope(
            campus: scope.campus,
            date: scope.date,
            forceRefresh: scope.forceRefresh,
          ),
          query: query,
        ),
      );
  @override
  Future<RuleExamples> rules() =>
      boundedNativeRead(() => rust.loadRuleExamples());
  @override
  Future<ScheduleResponse> schedule({
    String? termId,
    int? week,
    bool forceRefresh = false,
  }) => boundedNativeRead(
    () => live.loadSchedule(
      termId: termId,
      week: week,
      forceRefresh: forceRefresh,
    ),
  );
  @override
  Future<GradeTermsResponse> gradeTerms() =>
      boundedNativeRead(() => live.loadGradeTerms());
  @override
  Future<GradeResponse> grades({String? termCode, bool forceRefresh = false}) =>
      boundedNativeRead(
        () => live.loadGrades(termCode: termCode, forceRefresh: forceRefresh),
      );
  @override
  Future<TodayResponse> today({bool forceRefresh = false}) =>
      boundedNativeRead(() => live.loadToday(forceRefresh: forceRefresh));
  @override
  Future<CheckInResponse> checkin({bool forceRefresh = false}) =>
      boundedNativeRead(
        () => live.loadCheckinToday(forceRefresh: forceRefresh),
      );
  @override
  Future<CheckInResponse> checkinOnDate(
    String date, {
    bool forceRefresh = false,
  }) => boundedNativeRead(
    () => live.loadCheckinOnDate(date: date, forceRefresh: forceRefresh),
  );
  @override
  Future<live.ReadOnlyResponse> libraryStats({bool forceRefresh = false}) =>
      boundedNativeRead(
        () => live.loadLibraryStats(forceRefresh: forceRefresh),
      );
  @override
  Future<live.ReadOnlyResponse> libraryBooks({
    required String query,
    required int page,
    String sort = 'relevance',
    bool descending = true,
  }) => boundedNativeRead(
    () => live.loadLibraryBooks(
      query: query,
      page: page,
      sort: sort,
      descending: descending,
    ),
  );
  @override
  Future<live.ReadOnlyResponse> shuttleTimetable() =>
      boundedNativeRead(() => live.loadShuttleTimetable());
  @override
  Future<live.ReadOnlyResponse> libraryHoldings(String bibId) =>
      boundedNativeRead(() => live.loadLibraryHoldings(bibId: bibId));
  @override
  Future<LibraryVenuesResponse> libraryVenues({bool forceRefresh = false}) =>
      boundedNativeRead(
        () => live.loadLibraryVenues(forceRefresh: forceRefresh),
      );
  @override
  Future<LibraryAreasResponse> libraryAreas(String libraryId) =>
      boundedNativeRead(() => live.loadLibraryAreas(libraryId: libraryId));
  @override
  Future<LibrarySlotsResponse> librarySlots(String areaId) =>
      boundedNativeRead(() => live.loadLibrarySlots(areaId: areaId));
  @override
  Future<LibrarySeatsResponse> librarySeats({
    required String areaId,
    required LibrarySlot slot,
  }) => boundedNativeRead(
    () => live.loadLibrarySeats(
      areaId: areaId,
      slotId: slot.id,
      day: slot.day,
      start: slot.start,
      end: slot.end,
    ),
  );
  @override
  Future<LibraryBookingsResponse> libraryBookings({
    bool forceRefresh = false,
  }) => boundedNativeRead(
    () => live.loadLibraryBookings(forceRefresh: forceRefresh),
  );
  @override
  Future<live.LibraryHistoryResponse> libraryHistory(
    int page, {
    bool forceRefresh = false,
  }) => boundedNativeRead(
    () => live.loadLibraryHistory(page: page, forceRefresh: forceRefresh),
  );
  @override
  Future<HomeworkResponse> homework({bool forceRefresh = false}) =>
      boundedNativeRead(() => live.loadHomework(forceRefresh: forceRefresh));
  @override
  Future<live.HomeworkDetailResponse> homeworkDetail(
    String assignmentId, {
    bool forceRefresh = false,
  }) => boundedNativeRead(
    () => live.loadHomeworkDetail(
      assignmentId: assignmentId,
      forceRefresh: forceRefresh,
    ),
  );
}
