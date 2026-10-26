import 'package:ginkgo_mirror/src/rust/api/live.dart' show MutationResponse;
import 'package:ginkgo_mirror/src/rust/api/live.dart' show ReadOnlyResponse;
import 'package:ginkgo_mirror/src/rust/api/live.dart'
    show LibraryHistoryResponse;

import 'dart:typed_data';
import 'dart:convert';

import 'package:ginkgo_mirror/application/auth_challenge.dart';

import 'package:flutter/cupertino.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart'
    show HomeworkDetailResponse;
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/app_preferences.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart'
    show GradeTermsResponse, RouteChoice, SessionResponse, SessionState;
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

import 'mirror_widget_test.dart' show mockLocalTaskSupportDirectory;

class SyntheticAuthChallengeGateway implements AuthChallengeGateway {
  @override
  Future<LoginChallenge> loginChallenge({
    String? expectedId,
    bool refresh = false,
  }) async => LoginChallenge(
    id: 'cap-1',
    kind: 'local',
    textSupported: true,
    image: base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j8WQAAAAASUVORK5CYII=',
    ),
  );
}

const signedOut = SessionResponse(
  state: SessionState.signedOut,
  remembered: false,
);
const signedIn = SessionResponse(
  state: SessionState.signedIn,
  account: 'sy2501001',
  name: '测试同学',
  remembered: true,
);
const captcha = SessionResponse(
  state: SessionState.captchaRequired,
  remembered: false,
  captchaId: 'cap-1',
);

const emptyClassrooms = ClassroomResponse(
  buildings: [],
  roomCount: 0,
  buildingCount: 0,
  freeSlotCount: 0,
  fromCache: false,
);
final staleClassrooms = ClassroomResponse(
  buildings: [
    ClassroomBuilding(
      name: '主楼',
      rooms: [
        ClassroomRow(
          id: 'A101',
          name: '101',
          floor: '1',
          sections: Int32List.fromList([1]),
          longestRun: 1,
          sectionStates: const [SectionState(number: 1, available: true)],
        ),
      ],
    ),
  ],
  roomCount: 1,
  buildingCount: 1,
  freeSlotCount: 1,
  fetchedAt: '2026-10-20T10:00:00+08:00',
  fromCache: true,
  failure: FailureCode.serviceUnavailable,
);

class FakeService extends Fake implements MirrorService {
  @override
  Future<ReadOnlyResponse> editTasks({
    required String root,
    required String action,
    String? id,
    String? title,
    String? due,
    bool? completed,
  }) async {
    if (action != 'load') {
      throw UnimplementedError('Unexpected task write: $action');
    }
    return const ReadOnlyResponse(stale: false, payload: '[]');
  }

  FakeService({
    required this.restoreResponse,
    required this.loginResponse,
    this.classroomResponse = emptyClassrooms,
    this.demo = false,
  });
  final SessionResponse restoreResponse;
  final SessionResponse loginResponse;
  final ClassroomResponse classroomResponse;
  final bool demo;
  @override
  Future<MutationResponse> reserveLibrarySeat({
    required String areaId,
    required String seatId,
    required LibrarySlot slot,
  }) async => const MutationResponse(state: 'notSubmitted', message: '合成测试未提交');
  @override
  Future<MutationResponse> performLibraryAction(
    String bookingId,
    String action,
  ) async => const MutationResponse(state: 'notSubmitted', message: '合成测试未提交');
  @override
  Future<MutationResponse> submitCheckin(String courseId) async =>
      const MutationResponse(state: 'notSubmitted', message: '合成测试未提交');
  @override
  bool get isDemo => demo;
  @override
  Future<SessionResponse> restoreSession() async => restoreResponse;
  @override
  Future<SessionResponse> login({
    required String account,
    required String password,
    String? captcha,
    required bool remember,
  }) async => loginResponse;
  @override
  Future<SessionResponse> setRoute(RouteChoice route) async =>
      const SessionResponse(state: SessionState.signedOut, remembered: false);
  @override
  Future<bool> clearCache() async => true;
  @override
  Future<SessionResponse> signOut() async => signedOut;
  @override
  Future<QueryDates> dates(String instant) async =>
      const QueryDates(today: '2026-10-20', tomorrow: '2026-10-21');
  @override
  Future<ClassroomResponse> classrooms(
    DemoScope scope,
    ClassroomQuery query,
  ) async => classroomResponse;
  @override
  Future<RuleExamples> rules() async => RuleExamples(
    localDate: '2026-10-20',
    minutesSinceMidnight: 0,
    timeZone: 'Asia/Shanghai',
    cachedWeeks: Int32List.fromList([]),
    selectedWeek: 1,
    courseNames: [],
  );
  @override
  Future<ScheduleResponse> schedule({
    String? termId,
    int? week,
    bool forceRefresh = false,
  }) async => const ScheduleResponse(
    terms: [],
    weeks: [],
    termId: '',
    weekNumber: 0,
    courses: [],
    exams: [],
  );
  @override
  Future<GradeTermsResponse> gradeTerms() async =>
      const GradeTermsResponse(terms: []);
  @override
  Future<GradeResponse> grades({
    String? termCode,
    bool forceRefresh = false,
  }) async => const GradeResponse(
    termId: '',
    courses: [],
    summary: GradeSummary(courseCount: 0, creditTotal: 0),
  );
  @override
  Future<TodayResponse> today({bool forceRefresh = false}) async =>
      const TodayResponse(date: '2026-10-20', courses: []);
  @override
  Future<CheckInResponse> checkin({bool forceRefresh = false}) async =>
      const CheckInResponse(
        date: '2026-10-20',
        courses: [],
        fromCache: false,
        stale: false,
      );
  @override
  Future<CheckInResponse> checkinOnDate(
    String date, {
    bool forceRefresh = false,
  }) => checkin(forceRefresh: forceRefresh);
  @override
  Future<LibraryVenuesResponse> libraryVenues({
    bool forceRefresh = false,
  }) async =>
      const LibraryVenuesResponse(venues: [], fromCache: false, stale: false);
  @override
  Future<LibraryAreasResponse> libraryAreas(String libraryId) async =>
      const LibraryAreasResponse(areas: []);
  @override
  Future<LibrarySlotsResponse> librarySlots(String areaId) async =>
      const LibrarySlotsResponse(slots: []);
  @override
  Future<LibrarySeatsResponse> librarySeats({
    required String areaId,
    required LibrarySlot slot,
  }) async => const LibrarySeatsResponse(seats: []);
  @override
  Future<LibraryBookingsResponse> libraryBookings({
    bool forceRefresh = false,
  }) async => const LibraryBookingsResponse(
    bookings: [],
    fromCache: false,
    stale: false,
  );
  @override
  Future<HomeworkDetailResponse> homeworkDetail(
    String assignmentId, {
    bool forceRefresh = false,
  }) async => const HomeworkDetailResponse(
    content: '合成作业说明',
    status: '已提交',
    stale: false,
  );
  @override
  Future<ReadOnlyResponse> libraryStats({bool forceRefresh = false}) async =>
      const ReadOnlyResponse(stale: false);
  @override
  Future<LibraryHistoryResponse> libraryHistory(
    int page, {
    bool forceRefresh = false,
  }) async => LibraryHistoryResponse(
    bookings: [],
    page: page,
    pageSize: 40,
    hasNext: false,
    fromCache: false,
    stale: false,
  );
  @override
  Future<HomeworkResponse> homework({bool forceRefresh = false}) async =>
      const HomeworkResponse(termName: '', termCode: '', items: []);
}

Future<void> phone(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(430, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(app);
  // Cap the settle window: an unbounded search for a stable frame hides a
  // genuinely stuck page behind a ten-minute wait.
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 30),
  );
}

void main() {
  setUp(mockLocalTaskSupportDirectory);
  tearDown(() async {
    // Clear the marker in memory only. A save started inside the fake-async
    // test body leaves AppPreferences' serialized write chain attached to a
    // zone that is already gone, and awaiting another save here would then
    // never complete.
    AppPreferences.shared.explicitSignOut = false;
  });

  testWidgets('an explicit sign-out shows the login page on the next start', (
    tester,
  ) async {
    // Preferences persist through a real platform channel, which never
    // completes inside the fake-async test body unless it runs for real.
    await tester.runAsync(() => AppPreferences.shared.setExplicitSignOut(true));
    await phone(
      tester,
      GinkgoRoot(
        liveService: FakeService(
          restoreResponse: signedIn,
          loginResponse: signedIn,
        ),
        demoService: FakeService(
          restoreResponse: signedOut,
          loginResponse: signedIn,
          demo: true,
        ),
      ),
    );
    // The fake service would restore a saved session, but the recorded
    // sign-out must win: no automatic sign-in after the user chose to leave.
    expect(find.text('统一身份认证'), findsOneWidget);
    expect(find.byKey(const Key('today-scroll')), findsNothing);
  });

  testWidgets('signing in again clears the explicit sign-out marker', (
    tester,
  ) async {
    await tester.runAsync(() => AppPreferences.shared.setExplicitSignOut(true));
    await phone(
      tester,
      GinkgoRoot(
        liveService: FakeService(
          restoreResponse: signedOut,
          loginResponse: signedIn,
        ),
        demoService: FakeService(
          restoreResponse: signedOut,
          loginResponse: signedIn,
          demo: true,
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('login-account')), 'sy2501001');
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'fixture-password',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today-scroll')), findsOneWidget);
    expect(AppPreferences.shared.explicitSignOut, isFalse);
  });

  testWidgets('signed-out restore shows login and signs in', (tester) async {
    final service = FakeService(
      restoreResponse: signedOut,
      loginResponse: signedIn,
    );
    await phone(
      tester,
      GinkgoRoot(
        liveService: service,
        demoService: FakeService(
          restoreResponse: signedOut,
          loginResponse: signedIn,
          demo: true,
        ),
      ),
    );
    expect(find.text('统一身份认证'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('login-account')), 'sy2501001');
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'fixture-password',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today-scroll')), findsOneWidget);
  });

  testWidgets('saved session opens the workspace without login', (
    tester,
  ) async {
    await phone(
      tester,
      GinkgoRoot(
        liveService: FakeService(
          restoreResponse: signedIn,
          loginResponse: signedIn,
        ),
        demoService: FakeService(
          restoreResponse: signedOut,
          loginResponse: signedIn,
          demo: true,
        ),
      ),
    );
    expect(find.text('统一身份认证'), findsNothing);
    expect(find.byKey(const Key('today-scroll')), findsOneWidget);
  });

  testWidgets('failed remember explains the storage result before continuing', (
    tester,
  ) async {
    await phone(
      tester,
      GinkgoRoot(
        liveService: FakeService(
          restoreResponse: signedOut,
          loginResponse: const SessionResponse(
            state: SessionState.signedIn,
            account: 'synthetic-account',
            remembered: false,
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('login-account')),
      'synthetic-account',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'fixture-secret',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('已登录，密码未保存'), findsOneWidget);
    expect(find.byKey(const Key('today-scroll')), findsNothing);
    await tester.tap(find.text('继续使用'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('captcha requirement remains actionable on the login page', (
    tester,
  ) async {
    await phone(
      tester,
      GinkgoRoot(
        challengeGateway: SyntheticAuthChallengeGateway(),
        liveService: FakeService(
          restoreResponse: signedOut,
          loginResponse: captcha,
        ),
        demoService: FakeService(
          restoreResponse: signedOut,
          loginResponse: signedIn,
          demo: true,
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('login-account')), 'sy2501001');
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'fixture-password',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('验证码'), findsWidgets);
    expect(find.byKey(const Key('login-captcha')), findsOneWidget);
  });

  testWidgets('restore captcha opens login with the captcha field', (
    tester,
  ) async {
    await phone(
      tester,
      GinkgoRoot(
        challengeGateway: SyntheticAuthChallengeGateway(),
        liveService: FakeService(
          restoreResponse: captcha,
          loginResponse: signedIn,
        ),
        demoService: FakeService(
          restoreResponse: signedOut,
          loginResponse: signedIn,
          demo: true,
        ),
      ),
    );
    expect(find.byKey(const Key('login-captcha')), findsOneWidget);
    expect(find.textContaining('验证码'), findsWidgets);
  });

  testWidgets('offline demo remains reachable without a school account', (
    tester,
  ) async {
    await phone(
      tester,
      GinkgoRoot(
        liveService: FakeService(
          restoreResponse: signedOut,
          loginResponse: signedIn,
        ),
        demoService: FakeService(
          restoreResponse: signedOut,
          loginResponse: signedIn,
          demo: true,
        ),
      ),
    );
    await tester.tap(find.text('先看看离线演示'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today-scroll')), findsOneWidget);
  });

  testWidgets('stale classroom snapshot stays visible with a notice', (
    tester,
  ) async {
    await phone(
      tester,
      GinkgoApp(
        service: FakeService(
          restoreResponse: signedIn,
          loginResponse: signedIn,
          classroomResponse: staleClassrooms,
        ),
      ),
    );
    await tester.tap(find.text('预约'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('空教室'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查询空教室'));
    await tester.pumpAndSettle();
    expect(find.text('101'), findsOneWidget);
    expect(find.byKey(const Key('classroom-stale-notice')), findsOneWidget);
    expect(find.textContaining('正在显示上次结果'), findsOneWidget);
  });
}
