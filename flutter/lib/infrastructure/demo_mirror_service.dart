import '../application/contracts.dart';
import '../application/career.dart';
import '../application/checkin_progress.dart';
import '../application/library_holdings.dart';
import '../application/local_tasks_read.dart';
import '../application/campus_activities.dart';
import '../application/notices.dart';
import '../application/shuttle.dart';
import '../application/homework_files.dart';

import 'package:ginkgo_mirror/infrastructure/demo_homework_files.dart';
import 'package:ginkgo_mirror/infrastructure/demo_learning.dart';
import 'package:ginkgo_mirror/infrastructure/demo_library_loans.dart';
import 'package:ginkgo_mirror/infrastructure/local_tasks_decode.dart';
import 'package:ginkgo_mirror/infrastructure/notices_decode.dart';
import 'package:ginkgo_mirror/infrastructure/demo_graduate_credit_map.dart';
import 'package:ginkgo_mirror/infrastructure/library_stats_decode.dart';
import 'package:ginkgo_mirror/infrastructure/graduate_decode.dart';
import 'package:ginkgo_mirror/infrastructure/bykc_decode.dart';
import 'package:ginkgo_mirror/infrastructure/cgyy_decode.dart';

import '../features/cgyy/cgyy_models.dart';
import '../application/bykc.dart';
import '../application/graduate.dart';
import '../application/library_books.dart';
import '../application/library_stats.dart';

import 'dart:typed_data';

import '../application/mirror_service.dart';
import '../src/rust/api/live.dart' as live;
import '../src/rust/api/mirror.dart' as rust;

final class DemoMirrorService
    with DemoLearning, DemoGraduateCreditMap, DemoLibraryLoans
    implements
        MirrorService,
        CampusCardGateway,
        HomeworkFilesGateway,
        StudentServiceLinksGateway,
        CareerEventsGateway,
        CampusActivitiesGateway {
  // Demo uses the same public gateway contract; school data is synthetic.
  static final _files = Expando<DemoHomeworkFiles>();
  DemoHomeworkFiles get _homeworkFiles => _files[this] ??= DemoHomeworkFiles();
  const DemoMirrorService();
  @override
  String? studentServiceUrl(String id) => live.studentServiceUrl(id: id);
  @override
  Future<HomeworkFileWorkspace> homeworkFiles(String id) =>
      _homeworkFiles.homeworkFiles(id);
  @override
  Future<HomeworkFileReceipt> uploadHomeworkFile(
    String id,
    String name,
    Uint8List bytes,
  ) => _homeworkFiles.uploadHomeworkFile(id, name, bytes);
  @override
  Future<MutationResponse> submitHomeworkFile(String handle) =>
      _homeworkFiles.submitHomeworkFile(handle);
  @override
  Future<MutationResponse> reconcileHomeworkFile(String handle) =>
      _homeworkFiles.reconcileHomeworkFile(handle);
  @override
  Future<HomeworkFileDownload> downloadHomeworkFile(
    String id,
    String attachment,
  ) => _homeworkFiles.downloadHomeworkFile(id, attachment);
  @override
  Future<List<HomeworkPendingSubmission>> pendingHomeworkSubmissions({
    String? assignmentId,
  }) => _homeworkFiles.pendingHomeworkSubmissions(assignmentId: assignmentId);
  @override
  Future<List<HomeworkCapabilityEvidence>> homeworkCapabilities(
    String assignmentId,
  ) => _homeworkFiles.homeworkCapabilities(assignmentId);
  @override
  Future<CheckinProgressRead> checkinProgress() async =>
      const CheckinProgressRead();
  @override
  Future<live.CampusCardBalanceResponse> campusCardBalance() =>
      live.loadDemoCampusCardBalance();

  @override
  Future<CareerEventsRead> careerEvents({
    required String month,
    bool forceRefresh = false,
  }) async => const CareerEventsRead(
    data: CareerEvents(
      month: '2026-10',
      fetchedAt: '2026-10-28T10:00:00+08:00',
      events: [
        CareerEvent(
          id: 'demo-career-1',
          title: '合成专场宣讲会',
          campus: '学院路校区',
          place: '合成教学楼 201',
          beginsAt: '2026-10-28 14:00:00',
          endsAt: '2026-10-28 15:30:00',
          fairType: '线下宣讲会',
          status: '1',
          url: 'https://career.buaa.edu.cn/frontpage/buaa/html/index.html',
        ),
      ],
    ),
  );

  @override
  Future<CampusActivitiesRead> campusActivities({
    int page = 1,
    bool forceRefresh = false,
  }) async => const CampusActivitiesRead(
    data: CampusActivities(
      page: 1,
      fetchedAt: '2026-10-28T10:00:00+08:00',
      activities: [
        CampusActivity(
          id: 'demo-activity-1',
          title: '合成学术讲座',
          category: '讲座',
          publishedAt: '2026年10月28日',
          activityTime: '10月30日',
          place: '合成报告厅',
          url: 'https://www.buaa.edu.cn/index/xswh1.htm',
        ),
      ],
    ),
  );
  @override
  Future<BykcPartRead> bykcPart(
    BykcPart part, {
    bool forceRefresh = false,
  }) async => switch (part) {
    BykcPart.catalog => decodeBykcCatalog(await live.loadDemoBykc()),
    BykcPart.chosen => decodeBykcChosen(await live.loadDemoBykcChosen()),
    BykcPart.statistics => decodeBykcStatistics(
      await live.loadDemoBykcStatistics(),
    ),
  };
  @override
  Future<GraduateRead> graduatePart({
    required bool report,
    required bool forceRefresh,
  }) async => decodeGraduate(
    await (report ? live.loadDemoGraduate() : live.loadDemoGraduateStatus()),
  );
  @override
  Future<NoticesRead> notices({bool forceRefresh = false}) async =>
      decodeNotices(await live.loadDemoNotices());
  @override
  Future<CgyyLoadRead> cgyy({
    required String kind,
    required int siteId,
    required String date,
    required bool forceRefresh,
  }) async => decodeCgyyLoad(await live.loadDemoCgyy(kind: kind));
  @override
  Future<LocalTasksRead> editTasks({
    required String root,
    required String action,
    String? id,
    String? title,
    String? due,
    bool? completed,
  }) async => decodeLocalTasks(
    await live.editTasks(
      root: root,
      demo: true,
      action: action,
      id: id,
      title: title,
      due: due,
      completed: completed,
    ),
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
  Future<LibraryStatsRead> libraryStats({bool forceRefresh = false}) async =>
      decodeLibraryStats(await live.loadDemoLibraryStats());
  @override
  Future<BookPageRead> libraryBooks({
    required String query,
    required int page,
    String sort = 'relevance',
    bool descending = true,
  }) async => const BookPageRead(
    data: BookPage(
      page: 1,
      pageSize: 20,
      total: 0,
      actualTotal: 0,
      items: [],
      hasMore: false,
    ),
  );
  @override
  Future<BookHoldingsRead> libraryHoldings(String bibId) async =>
      const BookHoldingsRead(data: []);
  @override
  Future<ShuttleTimetableRead> shuttleTimetable() async =>
      const ShuttleTimetableRead(
        data: ShuttleTimetable(
          source: 'https://www.buaa.edu.cn/info/1065/1762.htm',
          liveSource: 'https://zhihuixiaoche.buaa.edu.cn/wechat/CASLogin',
          tables: [
            ShuttleTable(
              left: '合成去程：学院路→沙河',
              right: '合成返程：沙河→学院路',
              sections: [
                ShuttleSection(
                  label: '星期一至星期五',
                  left: [
                    ShuttleRun(index: '1', time: '08:30', capacity: '45'),
                    ShuttleRun(index: '2', time: '10:00', capacity: '45'),
                    ShuttleRun(index: '3', time: '14:00', capacity: '45'),
                  ],
                  right: [
                    ShuttleRun(index: '1', time: '09:00', capacity: '45'),
                    ShuttleRun(index: '2', time: '11:30', capacity: '45'),
                    ShuttleRun(index: '3', time: '17:00', capacity: '45'),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
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
