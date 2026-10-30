import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/features/settings/settings_page.dart';

import 'mirror_widget_test.dart' show ControlledService;
import 'platform_actions_fake.dart';

class PendingClearService extends ControlledService {
  final pending = Completer<bool>();
  @override
  Future<bool> clearCache() => pending.future;
}

void main() {
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
          home: SettingsPage(maintenance: platformActions.maintenance,service: service, onSignOut: () async {}),
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
