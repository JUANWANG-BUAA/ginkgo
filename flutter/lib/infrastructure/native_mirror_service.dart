import 'native_auth_challenge.dart';

import 'dart:convert';

import '../application/homework_files.dart';

import 'package:path_provider/path_provider.dart';

import '../application/contracts.dart';
import '../application/campus_activities.dart';
import '../application/cgyy_commands.dart';
import '../application/checkin_progress.dart';
import '../application/local_tasks_read.dart';
import '../application/notices.dart';
import '../application/saved_credential.dart';
import '../application/service_health.dart';
import '../application/shuttle.dart';
import '../application/mirror_service.dart';
import '../src/rust/api/live.dart' as live;
import '../src/rust/api/mirror.dart' as rust;

import 'package:ginkgo_mirror/infrastructure/native_learning.dart';
import 'package:ginkgo_mirror/infrastructure/native_homework_files.dart';
import 'package:ginkgo_mirror/infrastructure/native_saved_credential.dart';
import 'package:ginkgo_mirror/infrastructure/local_tasks_decode.dart';
import 'package:ginkgo_mirror/infrastructure/notices_decode.dart';
import 'package:ginkgo_mirror/infrastructure/shuttle_decode.dart';
import 'package:ginkgo_mirror/infrastructure/native_campus_activities.dart';
import 'package:ginkgo_mirror/infrastructure/native_career.dart';
import 'package:ginkgo_mirror/infrastructure/native_evaluation.dart';
import 'package:ginkgo_mirror/infrastructure/native_finance.dart';
import 'package:ginkgo_mirror/infrastructure/native_library.dart';
import 'package:ginkgo_mirror/infrastructure/native_library_loans.dart';
import 'package:ginkgo_mirror/infrastructure/native_network_account.dart';
import 'package:ginkgo_mirror/infrastructure/learning_snapshot_store.dart';
import 'package:ginkgo_mirror/infrastructure/native_reminder_planning.dart';
import 'package:ginkgo_mirror/infrastructure/graduate_credit_map_payload.dart';
import 'package:ginkgo_mirror/infrastructure/native_command.dart';
import 'package:ginkgo_mirror/infrastructure/graduate_decode.dart';
import 'package:ginkgo_mirror/infrastructure/bykc_decode.dart';
import 'package:ginkgo_mirror/infrastructure/cgyy_decode.dart';

import '../application/cgyy_models.dart';
import '../application/bykc.dart';
import '../application/graduate.dart';

final class NativeMirrorService
    with
        NativeLearning,
        NativeHomeworkFiles,
        NativeSavedCredential,
        NativeCareer,
        NativeCampusActivities,
        NativeReminderPlanning,
        NativeLibrary,
        NativeLibraryLoans,
        NativeFinance,
        NativeNetworkAccount,
        NativeEvaluation,
        NativeLearningSnapshots,
        NativeGatewayVerification
    implements
        MirrorService,
        VerifiedRouteGateway,
        SavedCredentialGateway,
        CgyyBookingGateway,
        CampusCardGateway,
        StudentServiceLinksGateway,
        HomeworkFilesGateway,
        CareerEventsGateway,
        CampusActivitiesGateway,
        GraduateCreditMapGateway {
  const NativeMirrorService({this.expectedAccount});

  @override
  Future<RouteChoice?> lastVerifiedRoute() =>
      boundedNativeRead(live.lastVerifiedRoute);

  @override
  Future<FailureCode?> switchVerifiedRoute(RouteChoice route) {
    final owner = expectedAccount;
    if (owner == null || owner.isEmpty) {
      return Future.value(FailureCode.sessionExpired);
    }
    return boundedNativeWrite(
      () => live.switchVerifiedRoute(expectedAccount: owner, route: route),
    );
  }

  @override
  String? studentServiceUrl(String id) => live.studentServiceUrl(id: id);

  @override
  final String? expectedAccount;

  @override
  Future<live.CampusCardBalanceResponse> campusCardBalance() =>
      ServiceHealthTracker.shared.observe(
        ServiceEndpointId.campusCard,
        () => boundedNativeRead(() => live.loadCampusCardBalance()),
        failureOf: (r) => r.failure,
      );

  @override
  Future<GraduateCreditMapRead> graduateCreditMap({
    bool forceRefresh = false,
  }) async {
    final owner = expectedAccount;
    if (owner == null || owner.isEmpty) {
      throw StateError('账号未绑定');
    }
    return decodeGraduateCreditMapRead(
      await ServiceHealthTracker.shared.observe(
        ServiceEndpointId.graduate,
        () => boundedNativeRead(
          () => live.loadGraduateCreditMap(
            expectedAccount: owner,
            forceRefresh: forceRefresh,
          ),
        ),
        failureOf: (r) => r.failure,
        staleOf: (r) => r.failure != null && r.data != null,
      ),
    );
  }

  @override
  Future<CgyyActionResult> executeCgyy(CgyyCommand command) async {
    if (expectedAccount?.isNotEmpty != true) {
      throw StateError('CGYY requires an account-bound workspace');
    }
    final root = await getApplicationSupportDirectory();
    final r = await boundedNativeWrite(
      () => live.executeCgyy(
        command: jsonEncode({
          ...command.toPayload(),
          'storage_root': root.path,
          'expected_account': expectedAccount,
        }),
      ),
    );
    if (r.failure != null || r.data == null) {
      throw StateError('CGYY write failed; the pending marker survives');
    }
    return decodeCgyyAction(r);
  }

  @override
  Future<CheckinProgressRead> checkinProgress() async {
    final response = await boundedNativeRead(() => live.checkinLoadProgress());
    final data = response.data;
    return CheckinProgressRead(
      data: data == null
          ? null
          : CheckinProgressTelemetry(
              phase: data.phase,
              elapsedSeconds: ((data.elapsedMs ?? 0) / 1000).floor(),
            ),
      failure: response.failure,
    );
  }

  @override
  Future<BykcPartRead> bykcPart(BykcPart part, {bool forceRefresh = false}) =>
      ServiceHealthTracker.shared.observe(
        ServiceEndpointId.bykc,
        () async => switch (part) {
          BykcPart.catalog => decodeBykcCatalog(
            await boundedNativeRead(
              () => live.loadBykc(forceRefresh: forceRefresh),
            ),
          ),
          BykcPart.chosen => decodeBykcChosen(
            await boundedNativeRead(
              () => live.loadBykcChosen(forceRefresh: forceRefresh),
            ),
          ),
          BykcPart.statistics => decodeBykcStatistics(
            await boundedNativeRead(
              () => live.loadBykcStatistics(forceRefresh: forceRefresh),
            ),
          ),
        },
        failureOf: (r) => r.failure,
        staleOf: (r) =>
            r.failure != null &&
            switch (r) {
              BykcCatalogRead(:final data) => data != null,
              BykcChosenRead(:final data) => data != null,
              BykcStatisticsRead(:final data) => data != null,
            },
      );

  @override
  Future<GraduateRead> graduatePart({
    required bool report,
    required bool forceRefresh,
  }) => ServiceHealthTracker.shared.observe(
    ServiceEndpointId.graduate,
    () async => decodeGraduate(
      await boundedNativeRead(
        () => live.loadGraduatePart(report: report, forceRefresh: forceRefresh),
      ),
    ),
    failureOf: (r) => r.failure,
    staleOf: (r) => r.failure != null && r.data != null,
  );

  @override
  Future<NoticesRead> notices({bool forceRefresh = false}) =>
      ServiceHealthTracker.shared.observe(
        ServiceEndpointId.notices,
        () async => decodeNotices(
          await boundedNativeRead(
            () => live.loadNotices(forceRefresh: forceRefresh),
          ),
        ),
        failureOf: (r) => r.failure,
        staleOf: (r) => r.failure != null && r.data != null,
      );

  @override
  Future<CgyyLoadRead> cgyy({
    required String kind,
    required int siteId,
    required String date,
    required bool forceRefresh,
  }) => ServiceHealthTracker.shared.observe(
    ServiceEndpointId.cgyy,
    () async => decodeCgyyLoad(
      await boundedNativeRead(
        () => live.loadCgyy(
          kind: kind,
          siteId: siteId,
          date: date,
          forceRefresh: forceRefresh,
        ),
      ),
    ),
    failureOf: (r) => r.failure,
    staleOf: (r) =>
        r.failure != null &&
        (r.sites != null ||
            r.day != null ||
            r.orders != null ||
            r.order != null ||
            r.lockCode != null),
  );

  @override
  Future<LocalTasksRead> editTasks({
    required String root,
    required String action,
    String? id,
    String? title,
    String? due,
    bool? completed,
  }) async => decodeLocalTasks(
    await boundedNativeRead(
      () => live.editTasks(
        root: root,
        demo: false,
        action: action,
        id: id,
        title: title,
        due: due,
        completed: completed,
      ),
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
  Future<CheckInQrResponse> prepareCheckinQr(
    String courseId, {
    bool revalidateCourse = true,
    int offsetMs = 0,
  }) => ServiceHealthTracker.shared.observe(
    ServiceEndpointId.checkin,
    () => boundedNativeRead(
      () => live.prepareCheckinQr(
        courseId: courseId,
        revalidateCourse: revalidateCourse,
        offsetMs: offsetMs,
      ),
    ),
    failureOf: (r) => r.failure,
  );

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
    clearInFlightNativeReads();
    try {
      await learningSnapshots.clear();
    } catch (_) {
      /* Storage is fail-closed; authentication must still be revoked. */
    }
    return boundedNativeWrite(() => live.signOut());
  }

  @override
  Future<SessionResponse> setRoute(RouteChoice route) async {
    clearInFlightNativeReads();
    try {
      await learningSnapshots.clear();
    } catch (_) {
      /* Never block route setup or startup restore on optional snapshot IO. */
    }
    return boundedNativeWrite(() => live.setRoute(route: route));
  }

  @override
  Future<bool> clearCache() async {
    clearInFlightNativeReads();
    await learningSnapshots.clear();
    return boundedNativeRead(() => live.clearCache());
  }

  @override
  Future<QueryDates> dates(String instant) =>
      boundedNativeRead(() => rust.loadQueryDates(instant: instant));

  @override
  Future<ClassroomResponse> classrooms(DemoScope scope, ClassroomQuery query) =>
      ServiceHealthTracker.shared.observe(
        ServiceEndpointId.classroom,
        () => boundedNativeRead(
          () => live.loadClassrooms(
            scope: live.LiveScope(
              campus: scope.campus,
              date: scope.date,
              forceRefresh: scope.forceRefresh,
            ),
            query: query,
          ),
        ),
        failureOf: (r) => r.failure,
        staleOf: (r) => r.failure != null && r.fetchedAt != null,
        cachedOf: (r) => r.fromCache,
      );

  @override
  Future<RuleExamples> rules() =>
      boundedNativeRead(() => rust.loadRuleExamples());

  @override
  Future<ScheduleResponse> schedule({
    String? termId,
    int? week,
    bool forceRefresh = false,
  }) => coalescedNativeRead(
    account: expectedAccount,
    key: 'schedule:${termId ?? ''}:${week ?? ''}',
    forceRefresh: forceRefresh,
    command: () => ServiceHealthTracker.shared.observe(
      ServiceEndpointId.schedule,
      () => boundedNativeRead(
        () => live.loadSchedule(
          termId: termId,
          week: week,
          forceRefresh: forceRefresh,
        ),
      ),
      failureOf: (r) => r.failure,
      staleOf: (r) => r.failure != null && r.fetchedAt != null,
    ),
  );

  @override
  Future<GradeTermsResponse> gradeTerms() =>
      boundedNativeRead(() => live.loadGradeTerms());

  @override
  Future<GradeResponse> grades({String? termCode, bool forceRefresh = false}) =>
      ServiceHealthTracker.shared.observe(
        ServiceEndpointId.grades,
        () => boundedNativeRead(
          () => live.loadGrades(termCode: termCode, forceRefresh: forceRefresh),
        ),
        failureOf: (r) => r.failure,
        staleOf: (r) => r.failure != null && r.fetchedAt != null,
      );

  @override
  Future<TodayResponse> today({bool forceRefresh = false}) =>
      coalescedNativeRead(
        account: expectedAccount,
        key: 'today',
        forceRefresh: forceRefresh,
        command: () => ServiceHealthTracker.shared.observe(
          ServiceEndpointId.today,
          () => boundedNativeRead(
            () => live.loadToday(forceRefresh: forceRefresh),
          ),
          failureOf: (r) => r.failure,
          staleOf: (r) => r.failure != null && r.fetchedAt != null,
        ),
      );

  @override
  Future<CheckInResponse> checkin({bool forceRefresh = false}) =>
      coalescedNativeRead(
        account: expectedAccount,
        key: 'checkin:today',
        forceRefresh: forceRefresh,
        command: () => ServiceHealthTracker.shared.observe(
          ServiceEndpointId.checkin,
          () => boundedNativeRead(
            () => live.loadCheckinToday(forceRefresh: forceRefresh),
          ),
          failureOf: (r) => r.failure,
          staleOf: (r) => r.stale,
          cachedOf: (r) => r.fromCache,
        ),
      );

  @override
  Future<CheckInResponse> checkinOnDate(
    String date, {
    bool forceRefresh = false,
  }) => ServiceHealthTracker.shared.observe(
    ServiceEndpointId.checkin,
    () => boundedNativeRead(
      () => live.loadCheckinOnDate(date: date, forceRefresh: forceRefresh),
    ),
    failureOf: (r) => r.failure,
    staleOf: (r) => r.stale,
    cachedOf: (r) => r.fromCache,
  );

  @override
  Future<ShuttleTimetableRead> shuttleTimetable() =>
      ServiceHealthTracker.shared.observe(
        ServiceEndpointId.shuttle,
        () async => decodeShuttleTimetable(
          await boundedNativeRead(() => live.loadShuttleTimetable()),
        ),
        failureOf: (r) => r.failure,
        staleOf: (r) => r.failure != null && r.data != null,
      );
}
