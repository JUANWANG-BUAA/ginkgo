import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/features/settings/settings_page.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'mirror_widget_test.dart' show ControlledService;
import 'platform_actions_fake.dart';

class PendingClearService extends ControlledService {
  final pending = Completer<bool>();
  @override
  Future<bool> clearCache() => pending.future;
}

class RouteService extends ControlledService implements VerifiedRouteGateway {
  RouteChoice active = RouteChoice.direct;
  FailureCode? failure;
  @override
  Future<RouteChoice?> lastVerifiedRoute() async => active;
  @override
  Future<FailureCode?> switchVerifiedRoute(RouteChoice route) async {
    if (failure == null) active = route;
    return failure;
  }
}

void main() {
  testWidgets(
    'failed route change keeps identity and preference; success publishes verified route',
    (tester) async {
      final service = RouteService()..failure = FailureCode.moduleAuthRequired;
      final prefs = AppPreferences();
      addTearDown(prefs.dispose);
      var signOuts = 0;
      await tester.pumpWidget(
        ginkgoApp(
          preferences: prefs,
          home: SettingsPage(
            service: service,
            maintenance: null,
            onSignOut: () async {
              signOuts++;
            },
          ),
        ),
      );
      final picker = find.byType(ApplePickerTile<RouteChoice>);
      await tester.scrollUntilVisible(
        picker,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('最近确认：直连'), findsOneWidget);
      tester
          .widget<ApplePickerTile<RouteChoice>>(picker)
          .onSelected(RouteChoice.webVpn);
      await tester.pumpAndSettle();
      expect(prefs.routeMode, 'automatic');
      expect(find.text('最近确认：直连'), findsOneWidget);
      service.failure = null;
      tester
          .widget<ApplePickerTile<RouteChoice>>(picker)
          .onSelected(RouteChoice.webVpn);
      await tester.pumpAndSettle();
      expect(prefs.routeMode, 'webVpn');
      expect(find.text('最近确认：WebVPN'), findsOneWidget);
      expect(signOuts, 0);
    },
  );
  testWidgets(
    'desktop header names Ginkgo settings and busy clear uses the leaf',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = PendingClearService();
      await tester.pumpWidget(
        ginkgoApp(
          home: SettingsPage(
            maintenance: platformActions.maintenance,
            service: service,
            onSignOut: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final heading = find.byKey(const Key('desktop-page-heading'));
      expect(heading, findsOneWidget);
      expect(
        find.descendant(of: heading, matching: find.text('Ginkgo')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: heading, matching: find.text('管理账号、显示偏好与系统设置')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: heading,
          matching: find.byIcon(CupertinoIcons.gear_alt),
        ),
        findsOneWidget,
      );
      expect(find.byType(CupertinoActivityIndicator), findsNothing);

      await tester.scrollUntilVisible(
        find.text('清除查询快照'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('清除查询快照'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('继续'));
      await tester.pump();
      expect(
        tester.widget<GinkgoActivity>(find.byType(GinkgoActivity)).size,
        16,
      );
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      service.pending.complete(false);
      await tester.pumpAndSettle();
      expect(find.byType(GinkgoActivity), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
