import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_booking_page.dart';
import 'package:ginkgo_mirror/features/checkin/checkin_page.dart';
import 'package:ginkgo_mirror/workspace/workspace_shell.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import '../test/cgyy_booking_widget_test.dart' show BookingGateway;
import '../test/write_actions_widget_test.dart' show WriteService;
import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());
  testWidgets(
    'native engine: iOS grouped booking, stepper, validation, dark mode and check-in window',
    (tester) async {
      final gateway = BookingGateway();
      await tester.pumpWidget(
        ginkgoApp(
          brightness: Brightness.dark,
          home: CgyyBookingPage(
            gateway: gateway,
            siteId: 1,
            siteName: '合成场馆',
            date: '2026-10-25',
          ),
        ),
      );
      await settle(tester);
      expect(find.text('场地与日期'), findsOneWidget);
      expect(find.text('选择空间与时段'), findsOneWidget);
      expect(find.text('08:00–09:00'), findsOneWidget);
      await tester.tap(find.text('08:00–09:00'));
      await settle(tester);
      expect(find.text('已选'), findsOneWidget);
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.bySemanticsLabel('增加参与人数'),
        200,
        scrollable: list,
      );
      await tester.tap(find.bySemanticsLabel('增加参与人数'));
      await settle(tester);
      expect(find.text('参与人数：2 人'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('确认信息并验证'),
        200,
        scrollable: list,
      );
      await tester.tap(find.text('确认信息并验证'));
      await settle(tester);
      expect(
        gateway.commands.length,
        1,
      ); // no draft / school write with incomplete form.
      final service = WriteService();
      await tester.pumpWidget(
        ginkgoApp(
          home: CheckInPage(
            key: const Key('early'),
            service: service,
            clock: () => DateTime.parse('2026-10-20T07:49:59+08:00'),
          ),
        ),
      );
      await settle(tester);
      final button = find.byKey(const Key('checkin-submit-501'));
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<CupertinoButton>(button).onPressed, isNull);
      await tester.pumpWidget(
        ginkgoApp(
          home: CheckInPage(
            key: const Key('open'),
            service: service,
            clock: () => DateTime.parse('2026-10-20T07:50:00+08:00'),
          ),
        ),
      );
      await settle(tester);
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<CupertinoButton>(button).onPressed, isNotNull);
      expect(service.writes, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  if (Platform.isAndroid) {
    testWidgets(
      'Android OS alarm delivers a generic notification once and cancels on removal',
      (tester) async {
        const channel = MethodChannel('cn.edu.buaa.ginkgo/reminders');
        final now = DateTime.now();
        final plan = [
          {
            'key': now.microsecondsSinceEpoch
                .toRadixString(16)
                .padLeft(64, '0'),
            'group': 'homework',
            'at': now.add(const Duration(seconds: 2)).millisecondsSinceEpoch,
            'expires': now
                .add(const Duration(minutes: 2))
                .millisecondsSinceEpoch,
          },
        ];
        await channel.invokeMethod<void>('replace', plan);
        try {
          Map<dynamic, dynamic>? summary;
          for (var i = 0; i < 40; i++) {
            await Future<void>.delayed(const Duration(seconds: 1));
            summary = await channel.invokeMapMethod('summary');
            if (summary?['visible'] == 1) break;
          }
          expect(summary?['visible'], 1);
          await channel.invokeMethod<void>('replace', plan);
          await Future<void>.delayed(const Duration(seconds: 3));
          summary = await channel.invokeMapMethod('summary');
          expect(summary?['visible'], 1);
        } finally {
          await channel.invokeMethod<void>('replace', []);
        }
        expect((await channel.invokeMapMethod('summary'))?['visible'], 0);
      },
    );
  }
}
