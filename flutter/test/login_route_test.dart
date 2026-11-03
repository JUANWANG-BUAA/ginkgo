import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/features/auth/login_page.dart';
import 'package:ginkgo_mirror/features/auth/login_route_selector.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';

import 'session_widget_test.dart' show FakeService, signedOut;

class RouteService extends FakeService {
  RouteService() : super(restoreResponse: signedOut, loginResponse: signedOut);
  final routes = <RouteChoice>[];
  Completer<SessionResponse>? pending;
  bool fail = false;
  @override
  Future<SessionResponse> setRoute(RouteChoice route) async {
    routes.add(route);
    if (fail) throw StateError('synthetic route failure');
    return pending == null ? signedOut : await pending!.future;
  }
}

void main() {
  testWidgets('login route restores, saves and locks while applying', (
    tester,
  ) async {
    Map<String, Object>? saved;
    final preferences = AppPreferences(writer: (value) async => saved = value);
    await preferences.setRouteMode('direct');
    final service = RouteService()..pending = Completer<SessionResponse>();
    await tester.pumpWidget(
      CupertinoApp(
        home: AppPreferencesScope(
          preferences: preferences,
          child: LoginPage(service: service, onSignedIn: (_) {}, onDemo: () {}),
        ),
      ),
    );
    expect(
      tester.widget<LoginRouteSelector>(find.byType(LoginRouteSelector)).route,
      RouteChoice.direct,
    );
    final selector = tester.widget<LoginRouteSelector>(
      find.byType(LoginRouteSelector),
    );
    selector.onChanged!(RouteChoice.webVpn);
    await tester.pump();
    expect(
      tester
          .widget<LoginRouteSelector>(find.byType(LoginRouteSelector))
          .onChanged,
      isNull,
    );
    expect(saved!['routeMode'], 'direct');
    service.pending!.complete(signedOut);
    await tester.pumpAndSettle();
    expect(saved!['routeMode'], 'webVpn');
    expect(service.routes, [RouteChoice.webVpn]);
    final restored = AppPreferences(reader: () async => saved);
    await restored.restore();
    expect(restored.routeMode, 'webVpn');
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed route change keeps previous route and reports error', (
    tester,
  ) async {
    final preferences = AppPreferences();
    final service = RouteService()..fail = true;
    await tester.pumpWidget(
      CupertinoApp(
        home: AppPreferencesScope(
          preferences: preferences,
          child: LoginPage(service: service, onSignedIn: (_) {}, onDemo: () {}),
        ),
      ),
    );
    tester
        .widget<LoginRouteSelector>(find.byType(LoginRouteSelector))
        .onChanged!(RouteChoice.webVpn);
    await tester.pumpAndSettle();
    expect(preferences.routeMode, 'automatic');
    expect(
      tester.widget<LoginRouteSelector>(find.byType(LoginRouteSelector)).route,
      RouteChoice.automatic,
    );
    expect(find.text('网络路线切换失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
