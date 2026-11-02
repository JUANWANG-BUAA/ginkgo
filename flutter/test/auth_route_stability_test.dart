import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/features/auth/login_page.dart';
import 'package:ginkgo_mirror/features/settings/settings_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'session_widget_test.dart' show FakeService, signedOut, phone;

const routeFailure = SessionResponse(
  state: SessionState.signedOut,
  remembered: false,
  failure: FailureCode.credentialStore,
);

class StabilityService extends FakeService {
  StabilityService()
    : super(restoreResponse: signedOut, loginResponse: signedOut);
  int restores = 0;
  int logins = 0;
  @override
  Future<SessionResponse> setRoute(RouteChoice route) async => routeFailure;
  @override
  Future<SessionResponse> restoreSession() async {
    restores++;
    return signedOut;
  }

  @override
  Future<SessionResponse> login({
    required String account,
    required String password,
    String? captcha,
    required bool remember,
  }) async {
    logins++;
    return const SessionResponse(
      state: SessionState.signedOut,
      remembered: false,
      failure: FailureCode.invalidCredentials,
    );
  }
}

void main() {
  testWidgets('startup route failure must stop session restoration', (
    tester,
  ) async {
    final service = StabilityService();
    await phone(
      tester,
      GinkgoRoot(liveService: service, preferences: AppPreferences()),
    );
    expect(service.restores, 0);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(
      find.text(failureMessage(FailureCode.credentialStore)),
      findsOneWidget,
    );
  });

  testWidgets('settings route failure preserves choice and does not sign out', (
    tester,
  ) async {
    final service = StabilityService();
    final preferences = AppPreferences();
    var signouts = 0;
    await phone(
      tester,
      ginkgoApp(
        preferences: preferences,
        home: SettingsPage(
          service: service,
          route: RouteChoice.automatic,
          maintenance: null,
          onSignOut: () async {
            signouts++;
          },
        ),
      ),
    );
    final picker = tester.widget<ApplePickerTile<RouteChoice>>(
      find.byType(ApplePickerTile<RouteChoice>),
    );
    picker.onSelected(RouteChoice.webVpn);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '继续'));
    await tester.pumpAndSettle();
    expect(signouts, 0);
    expect(preferences.routeMode, 'automatic');
  });

  testWidgets('rejected password attempts pause only subsequent submits', (
    tester,
  ) async {
    final service = StabilityService();
    await phone(
      tester,
      CupertinoApp(
        home: LoginPage(service: service, onSignedIn: (_) {}, onDemo: () {}),
      ),
    );
    await tester.enterText(find.byKey(const Key('login-account')), 'sy2501001');
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'synthetic',
    );
    for (var attempt = 0; attempt < 3; attempt++) {
      await tester.ensureVisible(find.byKey(const Key('login-submit')));
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pump();
    }
    expect(service.logins, 3);
    expect(
      tester
          .widget<CupertinoButton>(find.byKey(const Key('login-submit')))
          .onPressed,
      isNull,
    );
    expect(find.textContaining('等待 60 秒'), findsOneWidget);
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(
      tester
          .widget<CupertinoButton>(find.byKey(const Key('login-submit')))
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
