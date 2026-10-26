import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_booking_page.dart';
import 'package:ginkgo_mirror/workspace/workspace_shell.dart';

class BookingGateway implements CgyyBookingGateway {
  final commands = <Map<String, Object?>>[];
  @override
  Future<ReadOnlyResponse> executeCgyy(Map<String, Object?> command) async {
    commands.add(command);
    return ReadOnlyResponse(
      stale: false,
      payload: jsonEncode(
        command['action'] == 'options'
            ? {
                'state': 'options',
                'message': '选择时段',
                'options': {
                  'choices': [
                    {
                      'space_id': 1,
                      'space_name': '研讨室 A101',
                      'time_id': 1,
                      'time': '08:00–09:00',
                    },
                    {
                      'space_id': 1,
                      'space_name': '研讨室 A101',
                      'time_id': 2,
                      'time': '09:00–10:00',
                    },
                  ],
                  'purposes': [
                    {'id': 1, 'name': '学习研讨类'},
                  ],
                },
              }
            : {'state': 'uncertain', 'message': '结果待核实，请先到我的预约回查，勿重复提交'},
      ),
    );
  }
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    for (final (family, asset) in [
      ('Ginkgo Sans', 'Inter.ttf'),
      ('Ginkgo Han', 'NotoSansSC.ttf'),
    ]) {
      final font = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$asset'));
      await font.load();
    }
    final icons = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      );
    await icons.load();
  });
  for (final brightness in Brightness.values) {
    for (final width in [320.0, 430.0, 900.0]) {
      testWidgets(
        'native grouped booking form: ${brightness.name} / $width / large type',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final gateway = BookingGateway();
          final boundary = GlobalKey();
          await tester.pumpWidget(
            ginkgoApp(
              brightness: brightness,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 900),
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: RepaintBoundary(
                  key: boundary,
                  child: CgyyBookingPage(
                    gateway: gateway,
                    siteId: 1,
                    siteName: '沙河教学楼',
                    date: '2026-10-25',
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(gateway.commands.single['action'], 'options');
          expect(find.byType(ApplePageHeader), findsOneWidget);
          expect(find.byType(CupertinoTextFormFieldRow), findsWidgets);
          expect(find.byType(CupertinoSwitch), findsNWidgets(2));
          expect(tester.takeException(), isNull);
          final directory = Platform.environment['GINKGO_RENDER_DIR'];
          if (directory != null) {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(directory).create(recursive: true);
              await File(
                '$directory/cgyy-${brightness.name}-${width.toInt()}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await scrollTo(tester, find.text('确认信息并验证'));
          await tester.tap(find.text('确认信息并验证'));
          await tester.pumpAndSettle();
          expect(
            gateway.commands.length,
            1,
          ); // Incomplete form cannot create draft.
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'booking write requires confirmation; uncertainty disables retries',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = BookingGateway();
      await tester.pumpWidget(
        ginkgoApp(
          home: CgyyBookingPage(
            gateway: gateway,
            siteId: 1,
            siteName: '合成场馆',
            date: '2026-10-25',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('08:00–09:00'));
      final fields = find.byType(CupertinoTextFormFieldRow);
      for (final (i, value) in [
        (0, '13800000000'),
        (1, '合成主题'),
        (2, '合成内容'),
        (3, '合成人员'),
      ]) {
        await tester.enterText(fields.at(i), value);
      }
      await scrollTo(tester, find.text('确认信息并验证'));
      await tester.tap(find.text('确认信息并验证'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(gateway.commands.length, 1);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(gateway.commands.length, 1);
      await tester.tap(find.text('确认信息并验证'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('继续验证'));
      await tester.pumpAndSettle();
      expect(gateway.commands.where((c) => c['action'] == 'prepare').length, 1);
      final button = tester.widget<CupertinoButton>(
        find.widgetWithText(CupertinoButton, '确认信息并验证'),
      );
      expect(button.onPressed, isNull);
      expect(find.textContaining('结果待核实'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
