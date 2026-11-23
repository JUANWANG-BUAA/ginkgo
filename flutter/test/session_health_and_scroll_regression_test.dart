import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/auth_challenge.dart';
import 'package:ginkgo_mirror/application/contracts.dart'
    show
        CheckInResponse,
        FailureCode,
        GradeResponse,
        HomeworkResponse,
        RouteChoice,
        SessionResponse,
        SessionState;
import 'package:ginkgo_mirror/application/saved_credential.dart';
import 'package:ginkgo_mirror/application/service_health.dart';
import 'package:ginkgo_mirror/features/auth/login_page.dart';
import 'package:ginkgo_mirror/features/grades/grades_page.dart';
import 'package:ginkgo_mirror/features/settings/network_diagnostics_page.dart';
import 'package:ginkgo_mirror/features/today/today_page.dart';
import 'package:ginkgo_mirror/infrastructure/native_command.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';
import 'package:ginkgo_mirror/shared/reminders.dart';

import 'mirror_widget_test.dart' show ControlledService;
import 'platform_actions_fake.dart';

// Minimal 1x1 transparent PNG for captcha rendering tests.
final _onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

class _StuckSignOutService extends ControlledService
    implements SavedCredentialGateway {
  final Completer<SessionResponse> signOutGate = Completer<SessionResponse>();
  SavedCredential? stored;
  final loginCalls = <(String, String, String?, bool)>[];
  final gradeForces = <bool>[];

  @override
  Future<GradeResponse> grades({
    String? termCode,
    bool forceRefresh = false,
  }) async {
    gradeForces.add(forceRefresh);
    return super.grades(termCode: termCode, forceRefresh: forceRefresh);
  }

  @override
  bool get isDemo => false;

  @override
  Future<SavedCredential?> savedCredential() async => stored;

  @override
  Future<SessionResponse> setRoute(RouteChoice route) async =>
      const SessionResponse(state: SessionState.signedOut, remembered: false);

  @override
  Future<SessionResponse> restoreSession() async => const SessionResponse(
    state: SessionState.signedIn,
    account: 'sy2501001',
    name: '李文',
    remembered: true,
    route: RouteChoice.webVpn,
  );

  @override
  Future<SessionResponse> signOut() => signOutGate.future;

  @override
  Future<SessionResponse> login({
    required String account,
    required String password,
    String? captcha,
    required bool remember,
  }) async {
    loginCalls.add((account, password, captcha, remember));
    return SessionResponse(
      state: SessionState.signedIn,
      account: account,
      name: '李文',
      remembered: remember,
      route: RouteChoice.webVpn,
    );
  }
}

class _StubChallengeGateway implements AuthChallengeGateway {
  @override
  Future<LoginChallenge> loginChallenge({
    String? expectedId,
    bool refresh = false,
  }) async => LoginChallenge(
    id: expectedId ?? 'cap-1',
    kind: 'image',
    textSupported: true,
    image: _onePixelPng,
  );
}

void main() {
  tearDown(() {
    ServiceHealthTracker.shared.clear();
  });

  testWidgets(
    'sign-out returns to login immediately even while native revocation waits on in-flight reads',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final prefs = AppPreferences();
      addTearDown(prefs.dispose);
      final service = _StuckSignOutService();

      await tester.pumpWidget(
        GinkgoRoot(liveService: service, preferences: prefs),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('today-scroll')), findsOneWidget);

      await tester.tap(find.text('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('more-account-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-sign-out')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('继续'));
      await tester.pumpAndSettle();

      // Even though signOutGate has NOT completed, UI is already back on Login!
      expect(service.signOutGate.isCompleted, isFalse);
      expect(prefs.explicitSignOut, isTrue);
      expect(find.text('统一身份认证'), findsOneWidget);
      expect(find.byKey(const Key('today-scroll')), findsNothing);

      service.signOutGate.complete(
        const SessionResponse(state: SessionState.signedOut, remembered: false),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved credential pre-fills login page without wiping an active captcha challenge',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final prefs = AppPreferences();
      addTearDown(prefs.dispose);
      final service = _StuckSignOutService()
        ..stored = const SavedCredential(
          account: 'sy2501001',
          password: 'synthetic-password',
        );
      SessionResponse? signedInResponse;

      await tester.pumpWidget(
        ginkgoApp(
          preferences: prefs,
          home: LoginPage(
            service: service,
            initialCaptcha: true,
            challengeGateway: _StubChallengeGateway(),
            onSignedIn: (res) => signedInResponse = res,
            onDemo: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('已从系统安全存储自动填充学号与密码'), findsOneWidget);
      // Captcha field remained intact despite account & password pre-fill!
      expect(find.byKey(const Key('login-captcha')), findsOneWidget);
      expect(prefs.rememberPassword, isTrue);

      await tester.enterText(find.byKey(const Key('login-captcha')), 'ABCD');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('login-submit')));
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();

      expect(service.loginCalls, [
        ('sy2501001', 'synthetic-password', 'ABCD', true),
      ]);
      expect(signedInResponse?.account, 'sy2501001');
    },
  );

  testWidgets(
    'today page scrolls cleanly to bottom with stable extent and opens live endpoint status',
    (tester) async {
      tester.view.physicalSize = const Size(430, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _StuckSignOutService();
      await ServiceHealthTracker.shared.observe(
        ServiceEndpointId.today,
        () async => 'ok',
      );
      await ServiceHealthTracker.shared.observe<String>(
        ServiceEndpointId.grades,
        () async => 'degraded',
        failureOf: (_) => FailureCode.serviceUnavailable,
      );

      await tester.pumpWidget(
        ginkgoApp(
          home: TodayPage(
            service: service,
            fileActions: platformActions,
            storageRoot: '/synthetic/tasks',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('1 项接口异常'), findsOneWidget);

      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const Key('today-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();
      final extentAtBottom = scrollable.position.maxScrollExtent;
      await tester.pump(const Duration(milliseconds: 250));
      expect(scrollable.position.maxScrollExtent, extentAtBottom);

      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('today-open-diagnostics')));
      await tester.pumpAndSettle();

      expect(find.byType(NetworkDiagnosticsPage), findsOneWidget);
      expect(find.byKey(const Key('live-health-summary')), findsOneWidget);
      expect(find.byKey(const Key('live-endpoint-today')), findsOneWidget);
      expect(find.byKey(const Key('live-endpoint-grades')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android scroll behavior enables CupertinoSliverRefreshControl pull-to-refresh across pages without SliverLayoutBuilder',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final service = _StuckSignOutService();
        await tester.pumpWidget(ginkgoApp(home: GradesPage(service: service)));
        await tester.pumpAndSettle();

        expect(find.byType(SliverLayoutBuilder), findsNothing);

        final before = service.gradeForces.length;
        await tester.drag(
          find.byKey(const Key('grades-scroll')),
          const Offset(0, 180),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(service.gradeForces.length, greaterThan(before));
        expect(service.gradeForces.last, isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'sessionExpired surfaces one-tap re-authentication that preserves saved credentials and skips signOut',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var signOutCalled = false;
      final prefs = AppPreferences();
      addTearDown(prefs.dispose);
      final service = _ReauthRecordingService(
        onSignOutCalled: () => signOutCalled = true,
      )..stored = const SavedCredential(
          account: 'sy2501001',
          password: 'synthetic-password',
        );

      await tester.pumpWidget(
        GinkgoRoot(liveService: service, preferences: prefs),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('today-scroll')), findsOneWidget);

      await ServiceHealthTracker.shared.observe<String>(
        ServiceEndpointId.homework,
        () async => 'expired',
        failureOf: (_) => FailureCode.sessionExpired,
      );
      await tester.pump();

      expect(find.text('学校会话已失效，点此重新登录'), findsOneWidget);
      await tester.tap(find.byKey(const Key('today-open-diagnostics')));
      await tester.pumpAndSettle();

      expect(signOutCalled, isFalse);
      expect(prefs.explicitSignOut, isFalse);
      expect(find.text('统一身份认证'), findsOneWidget);
      expect(find.text('已从系统安全存储自动填充学号与密码'), findsOneWidget);
    },
  );

  test(
    'disabled checkin and homework reminder toggles stop polling school endpoints',
    () async {
      final service = _CountingReminderService();
      final controller = ReminderController(
        service: service,
        account: 'sy2501001',
        visibility: null,
        persist: false,
        platform: _NoopReminderPlatform(),
      );
      addTearDown(controller.dispose);

      await controller.setEnabled('checkin', false);
      await controller.setEnabled('homework', false);
      await controller.refresh(includeHomework: true);

      expect(service.checkinCalls, 0);
      expect(service.homeworkCalls, 0);
    },
  );

  test(
    'coalescedNativeRead shares concurrent non-forced reads per account and isolates accounts',
    () async {
      addTearDown(clearInFlightNativeReads);
      var upstreamCalls = 0;
      final gate = Completer<String>();

      Future<String> run({
        required String account,
        required bool force,
      }) => coalescedNativeRead<String>(
        account: account,
        key: 'homework',
        forceRefresh: force,
        command: () {
          upstreamCalls++;
          return gate.future;
        },
      );

      final first = run(account: 'sy2501001', force: false);
      final second = run(account: 'sy2501001', force: false);
      final otherAccount = run(account: 'sy2501002', force: false);
      final forced = run(account: 'sy2501001', force: true);

      expect(upstreamCalls, 3);
      gate.complete('ok');
      expect(await Future.wait([first, second, otherAccount, forced]), [
        'ok',
        'ok',
        'ok',
        'ok',
      ]);
    },
  );
}

class _ReauthRecordingService extends _StuckSignOutService {
  _ReauthRecordingService({required this.onSignOutCalled});
  final VoidCallback onSignOutCalled;

  @override
  Future<SessionResponse> signOut() async {
    onSignOutCalled();
    return const SessionResponse(state: SessionState.signedOut, remembered: false);
  }
}

class _NoopReminderPlatform implements ReminderPlatform {
  @override
  Future<void> replace(List<Map<String, Object>> plans) async {}
}

class _CountingReminderService extends ControlledService {
  int checkinCalls = 0;
  int homeworkCalls = 0;

  @override
  bool get isDemo => false;

  @override
  Future<CheckInResponse> checkin({bool forceRefresh = false}) async {
    checkinCalls++;
    return super.checkin(forceRefresh: forceRefresh);
  }

  @override
  Future<HomeworkResponse> homework({bool forceRefresh = false}) async {
    homeworkCalls++;
    return super.homework(forceRefresh: forceRefresh);
  }
}
