import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/app_preferences.dart';
import 'package:ginkgo_mirror/loading_widgets.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/preferences_pages.dart';
import 'package:ginkgo_mirror/system_settings_service.dart';

class TestSystemSettings implements SystemSettingsService {
  String permission = 'notRequested';
  int requests = 0, opens = 0, shares = 0;
  @override
  bool get isAndroid => true;
  @override
  Future<String> notificationPermission() async => permission;
  @override
  Future<String> requestNotifications() async {
    requests++;
    return permission = 'denied';
  }

  @override
  Future<bool> openNotifications() async {
    opens++;
    return true;
  }

  @override
  Future<bool> openAppSettings() async {
    opens++;
    return true;
  }

  @override
  Future<bool> shareProject() async {
    shares++;
    return true;
  }
}

class PendingSystemSettings extends TestSystemSettings {
  final pending = Completer<String>();
  @override
  Future<String> requestNotifications() {
    requests++;
    return pending.future;
  }
}

void main() {
  testWidgets(
    'appearance applies immediately, preserves route and serializes storage',
    (tester) async {
      final writes = <Map<String, Object>>[];
      final preferences = AppPreferences(
        writer: (value) async => writes.add(value),
      );
      await tester.pumpWidget(
        ginkgoApp(
          preferences: preferences,
          home: Builder(
            builder: (context) => CupertinoPageScaffold(
              child: CupertinoButton(
                child: const Text('打开外观'),
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => const AppearancePage(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开外观'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('appearance-dark')));
      await tester.pumpAndSettle();
      expect(find.text('显示与阅读'), findsWidgets);
      expect(
        CupertinoTheme.brightnessOf(tester.element(find.text('深色'))),
        Brightness.dark,
      );
      await preferences.update(
        textSize: 1.3,
        compactLists: true,
        reduceMotion: true,
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.text('深色'));
      expect(MediaQuery.disableAnimationsOf(context), isTrue);
      expect(MediaQuery.textScalerOf(context).scale(20), 26);
      expect(writes.last['appearance'], 'dark');
      expect(writes.last['compactLists'], true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'system permission is explicit and denial offers system settings',
    (tester) async {
      final service = TestSystemSettings();
      await tester.pumpWidget(
        ginkgoApp(home: SystemPreferencesPage(service: service)),
      );
      await tester.pumpAndSettle();
      expect(service.requests, 0);
      await tester.tap(find.text('请求通知权限'));
      await tester.pumpAndSettle();
      expect(service.requests, 1);
      expect(find.text('未允许，请到系统设置开启'), findsOneWidget);
      await tester.tap(find.text('打开系统通知设置'));
      await tester.pumpAndSettle();
      expect(service.opens, 1);
      expect(find.textContaining('非精确定时'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'about keeps UBAA acknowledgment and allows explicit project sharing',
    (tester) async {
      final service = TestSystemSettings();
      await tester.pumpWidget(ginkgoApp(home: AboutPage(system: service)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('分享 Ginkgo'));
      await tester.tap(find.text('分享 Ginkgo'));
      await tester.pumpAndSettle();
      expect(service.shares, 1);
      await tester.ensureVisible(find.text('访问 UBAA 开源项目'));
      expect(find.text('BUAASubnet / UBAA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'settings pages name their identity and busy requests use the brand leaf',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = PendingSystemSettings();
      await tester.pumpWidget(
        ginkgoApp(home: SystemPreferencesPage(service: service)),
      );
      await tester.pumpAndSettle();
      final heading = find.byKey(const Key('desktop-page-heading'));
      expect(
        find.descendant(of: heading, matching: find.text('设置')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: heading, matching: find.text('通知权限、系统启动与电池管理')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: heading,
          matching: find.byIcon(CupertinoIcons.bell),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('请求通知权限'));
      await tester.pump();
      expect(
        tester.widget<GinkgoActivity>(find.byType(GinkgoActivity)).size,
        16,
      );
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      service.pending.complete('granted');
      await tester.pumpAndSettle();
      expect(find.text('已允许'), findsOneWidget);
      expect(find.byType(GinkgoActivity), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop tool pages pass an explicit header identity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cases = <(Widget, String, String, IconData)>[
      (const AppearancePage(), '设置', '外观、强调色与文字大小', CupertinoIcons.paintbrush),
      (const PrivacyPage(), '设置', '自动登录、本机数据与请求去向', CupertinoIcons.lock_shield),
      (const AboutPage(), 'Ginkgo', '开源许可、项目主页与致谢', CupertinoIcons.info_circle),
    ];
    for (final (page, section, subtitle, icon) in cases) {
      await tester.pumpWidget(ginkgoApp(home: page));
      await tester.pumpAndSettle();
      final heading = find.byKey(const Key('desktop-page-heading'));
      expect(
        find.descendant(of: heading, matching: find.text(section)),
        findsOneWidget,
        reason: subtitle,
      );
      expect(
        find.descendant(of: heading, matching: find.text(subtitle)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: heading, matching: find.byIcon(icon)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
