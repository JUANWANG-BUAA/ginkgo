import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/features/auth/login_page.dart';
import 'package:ginkgo_mirror/features/auth/login_route_selector.dart';
import 'package:ginkgo_mirror/features/settings/preferences_pages.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';

import 'session_widget_test.dart' show FakeService, signedOut, phone;

class PreferenceRecoveryService extends FakeService {
  PreferenceRecoveryService()
    : super(restoreResponse: signedOut, loginResponse: signedOut);
  final routes = <RouteChoice>[];
  int restores = 0;
  @override
  Future<SessionResponse> setRoute(RouteChoice route) async {
    routes.add(route);
    return signedOut;
  }

  @override
  Future<SessionResponse> restoreSession() async {
    restores++;
    return signedOut;
  }
}

void main() {
  for (final (field, value) in [
    ('explicitSignOut', 'true'),
    ('routeMode', 7),
    ('routeMode', 'unknown-route'),
  ]) {
    testWidgets(
      'invalid critical preference $field=$value does not auto-restore',
      (tester) async {
        final preferences = AppPreferences(reader: () async => {field: value});
        addTearDown(preferences.dispose);
        await preferences.restore();
        final service = PreferenceRecoveryService();
        await phone(
          tester,
          GinkgoRoot(liveService: service, preferences: preferences),
        );
        expect(service.routes, isEmpty);
        expect(service.restores, 0);
        expect(find.text('重新读取本机设置'), findsOneWidget);
      },
    );
  }
  testWidgets('late signout marker failure is visible and retryable on login', (
    tester,
  ) async {
    final gate = Completer<void>();
    final values = <Map<String, Object>>[];
    final preferences = AppPreferences(
      writer: (value) {
        values.add(value);
        return values.length == 1 ? gate.future : Future.value();
      },
    );
    addTearDown(preferences.dispose);
    await phone(
      tester,
      ginkgoApp(
        preferences: preferences,
        home: LoginPage(
          service: PreferenceRecoveryService(),
          onSignedIn: (_) {},
          onDemo: () {},
        ),
      ),
    );
    final pending = preferences.setExplicitSignOut(true);
    await tester.pump();
    gate.completeError(StateError('synthetic signout marker failure'));
    await pending;
    await tester.pumpAndSettle();
    expect(find.textContaining('退出标记保存失败'), findsOneWidget);
    await tester.ensureVisible(find.text('重试保存设置'));
    await tester.tap(find.text('重试保存设置'));
    await tester.pumpAndSettle();
    expect(values.last['explicitSignOut'], true);
    expect(preferences.saveError, isNull);
    expect(find.textContaining('退出标记保存失败'), findsNothing);
  });
  testWidgets(
    'login route save failure clears after retry without another route change',
    (tester) async {
      var unavailable = true;
      final values = <Map<String, Object>>[];
      final preferences = AppPreferences(
        writer: (value) async {
          values.add(value);
          if (unavailable) throw StateError('synthetic route save failure');
        },
      );
      addTearDown(preferences.dispose);
      final service = PreferenceRecoveryService();
      await phone(
        tester,
        ginkgoApp(
          preferences: preferences,
          home: LoginPage(service: service, onSignedIn: (_) {}, onDemo: () {}),
        ),
      );
      tester
          .widget<LoginRouteSelector>(find.byType(LoginRouteSelector))
          .onChanged!(RouteChoice.webVpn);
      await tester.pumpAndSettle();
      expect(find.textContaining('本机保存失败'), findsOneWidget);
      unavailable = false;
      await tester.ensureVisible(find.text('重试保存设置'));
      await tester.tap(find.text('重试保存设置'));
      await tester.pumpAndSettle();
      expect(service.routes, [RouteChoice.webVpn]);
      expect(values.last['routeMode'], 'webVpn');
      expect(find.textContaining('本机保存失败'), findsNothing);
    },
  );
  testWidgets('save retry persists current settings without changing them', (
    tester,
  ) async {
    var unavailable = true;
    final values = <Map<String, Object>>[];
    final preferences = AppPreferences(
      writer: (value) async {
        values.add(value);
        if (unavailable) throw StateError('synthetic save failure');
      },
    );
    addTearDown(preferences.dispose);
    await preferences.setRouteMode('webVpn');
    await preferences.setExplicitSignOut(true);
    await preferences.update(appearance: AppAppearance.dark);
    await tester.pumpWidget(
      ginkgoApp(preferences: preferences, home: const AppearancePage()),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('重试保存'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    unavailable = false;
    await tester.tap(find.text('重试保存'));
    await tester.pumpAndSettle();
    expect(preferences.saveError, isNull);
    expect(find.text('重试保存'), findsNothing);
    expect(values.last['routeMode'], 'webVpn');
    expect(values.last['explicitSignOut'], true);
    expect(values.last['appearance'], 'dark');
  });
  test('queued saves capture each requested snapshot', () async {
    final values = <Map<String, Object>>[];
    final preferences = AppPreferences(
      writer: (value) async => values.add(value),
    );
    addTearDown(preferences.dispose);
    final first = preferences.update(appearance: AppAppearance.dark);
    final second = preferences.update(appearance: AppAppearance.light);
    await Future.wait([first, second]);
    expect(values.map((value) => value['appearance']), ['dark', 'light']);
  });
  test(
    'older failed save cannot leave an error after latest save succeeds',
    () async {
      final gate = Completer<void>();
      var writes = 0;
      final preferences = AppPreferences(
        writer: (_) {
          writes++;
          return writes == 1 ? gate.future : Future.value();
        },
      );
      addTearDown(preferences.dispose);
      final first = preferences.setRouteMode('webVpn');
      await Future<void>.delayed(Duration.zero);
      final second = preferences.update(appearance: AppAppearance.dark);
      gate.completeError(StateError('synthetic first save failure'));
      await Future.wait([first, second]);
      expect(writes, 2);
      expect(preferences.saveError, isNull);
    },
  );
  test(
    'pending save settles after disposal without notifying dead listeners',
    () async {
      final gate = Completer<void>();
      final preferences = AppPreferences(writer: (_) => gate.future);
      final pending = preferences.update(appearance: AppAppearance.dark);
      await Future<void>.delayed(Duration.zero);
      preferences.dispose();
      final checked = expectLater(pending, completes);
      gate.completeError(StateError('synthetic failure after disposal'));
      await checked;
    },
  );
  for (final explicitSignOut in [true, false]) {
    testWidgets(
      'failed preference read blocks restore; retry honors signout=$explicitSignOut',
      (tester) async {
        var unavailable = true;
        final preferences = AppPreferences(
          reader: () async {
            if (unavailable) throw StateError('synthetic read failure');
            return {'routeMode': 'webVpn', 'explicitSignOut': explicitSignOut};
          },
        );
        addTearDown(preferences.dispose);
        await preferences.restore();
        final service = PreferenceRecoveryService();
        await phone(
          tester,
          GinkgoRoot(liveService: service, preferences: preferences),
        );
        expect(service.routes, isEmpty);
        expect(service.restores, 0);
        expect(find.textContaining('自动恢复'), findsOneWidget);
        unavailable = false;
        await tester.ensureVisible(find.text('重新读取本机设置'));
        await tester.tap(find.text('重新读取本机设置'));
        await tester.pumpAndSettle();
        expect(service.routes, [RouteChoice.webVpn]);
        expect(service.restores, explicitSignOut ? 0 : 1);
        expect(preferences.saveError, isNull);
        expect(find.text('重新读取本机设置'), findsNothing);
      },
    );
  }
}
