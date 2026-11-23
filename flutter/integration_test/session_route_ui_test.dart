import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/features/checkin/checkin_page.dart';
import 'package:ginkgo_mirror/features/library/library_page.dart';
import 'package:ginkgo_mirror/features/settings/settings_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';
import 'package:ginkgo_mirror/widgets/apple_controls.dart';

import 'support.dart' show settle;

// This device test never constructs a native service or sends school requests.
class RouteUiService extends Fake
    implements MirrorService, VerifiedRouteGateway {
  RouteChoice verified = RouteChoice.direct;
  Completer<FailureCode?>? switchRequest;
  bool readFails = true;
  int signouts = 0;
  int checkinReads = 0;
  int bookingReads = 0;

  @override
  bool get isDemo => false;

  @override
  Future<RouteChoice?> lastVerifiedRoute() async => verified;

  @override
  Future<FailureCode?> switchVerifiedRoute(RouteChoice route) async {
    final request = Completer<FailureCode?>();
    switchRequest = request;
    final failure = await request.future;
    if (failure == null) verified = route;
    return failure;
  }

  @override
  Future<CheckInResponse> checkin({bool forceRefresh = false}) async {
    checkinReads++;
    return CheckInResponse(
      date: '2026-11-18',
      courses: const [],
      fromCache: false,
      stale: false,
      failure: readFails ? FailureCode.moduleAuthRequired : null,
    );
  }

  @override
  Future<LibraryBookingsResponse> libraryBookings({
    bool forceRefresh = false,
  }) async {
    bookingReads++;
    return LibraryBookingsResponse(
      bookings: const [],
      fromCache: false,
      stale: false,
      failure: readFails ? FailureCode.moduleAuthRequired : null,
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const captureEnabled = bool.fromEnvironment('GINKGO_VISUAL_CAPTURE');
  const scale = int.fromEnvironment(
    'GINKGO_VISUAL_SCALE_PERCENT',
    defaultValue: 100,
  );
  for (final brightness in Brightness.values) {
    testWidgets('route and local recovery UI ${brightness.name}', (
      tester,
    ) async {
      final service = RouteUiService();
      final preferences = AppPreferences()..textSize = scale / 100;
      addTearDown(preferences.dispose);
      final mode = '${brightness.name}-$scale';
      Future<void> capture(String id) async {
        await settle(tester, frames: 4);
        expect(tester.takeException(), isNull, reason: id);
        if (!captureEnabled) return;
        await tester.runAsync(() async {
          final socket = await Socket.connect('127.0.0.1', 18765);
          socket.add(
            'GET /route-$mode-$id.png HTTP/1.0\r\nHost: localhost\r\n\r\n'
                .codeUnits,
          );
          await socket.flush();
          await socket.drain<void>();
          socket.destroy();
        });
      }

      Future<void> showPage(Widget page) async {
        await tester.pumpWidget(
          ginkgoApp(
            brightness: brightness,
            preferences: preferences,
            home: KeyedSubtree(key: UniqueKey(), child: page),
          ),
        );
        await settle(tester);
      }

      final picker = find.byType(ApplePickerTile<RouteChoice>);
      Future<void> chooseWebVpn() async {
        await tester.ensureVisible(picker);
        await settle(tester, frames: 3);
        await tester.tap(picker);
        await settle(tester);
        await capture('picker');
        await tester.tap(find.text('仅 WebVPN'));
        await settle(tester, frames: 6);
      }

      await showPage(
        SettingsPage(
          service: service,
          maintenance: null,
          accountName: '合成验收账号',
          accountId: 'sy2501001',
          onSignOut: () async {
            service.signouts++;
          },
        ),
      );
      await capture('settings-top');
      await chooseWebVpn();
      expect(
        find.text('正在验证目标路线，当前登录会保留…').hitTestable(),
        findsOneWidget,
      );
      await capture('switch-pending');
      expect(
        tester.widget<ApplePickerTile<RouteChoice>>(picker).enabled,
        isFalse,
      );
      service.switchRequest!.complete(FailureCode.moduleAuthRequired);
      await settle(tester);
      expect(preferences.routeMode, 'automatic');
      expect(service.verified, RouteChoice.direct);
      expect(service.signouts, 0);
      expect(
        find.text('目标路线尚未验证，已保留当前路线和登录。').hitTestable(),
        findsOneWidget,
      );
      await capture('switch-failed');
      await chooseWebVpn();
      service.switchRequest!.complete(null);
      await settle(tester);
      expect(preferences.routeMode, 'webVpn');
      expect(find.text('最近确认：WebVPN'), findsOneWidget);
      await capture('switch-success');

      await showPage(CheckInPage(service: service));
      expect(find.text('今天没有课程'), findsNothing);
      await capture('checkin-failed');
      service.readFails = false;
      await tester.ensureVisible(find.text('重试'));
      await tester.tap(find.text('重试'));
      await settle(tester);
      expect(service.checkinReads, 2);
      expect(find.text('今天没有课程'), findsOneWidget);
      await capture('checkin-recovered');

      service.readFails = true;
      await showPage(LibraryPage(service: service));
      expect(find.text('当前没有进行中的预约'), findsNothing);
      final status = find.byKey(const Key('library-bookings-status'));
      await tester.ensureVisible(status);
      await settle(tester);
      await capture('library-failed');
      service.readFails = false;
      final retry = find.descendant(of: status, matching: find.text('重试'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await settle(tester);
      expect(service.bookingReads, 2);
      expect(find.text('当前没有进行中的预约'), findsOneWidget);
      await capture('library-recovered');
      expect(service.signouts, 0);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
