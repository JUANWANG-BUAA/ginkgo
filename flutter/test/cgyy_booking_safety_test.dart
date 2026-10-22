import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/cgyy_booking_page.dart';
import 'package:ginkgo_mirror/workspace_shell.dart';

class SafetyGateway implements CgyyBookingGateway {
  final commands = <Map<String, Object?>>[];
  int slots = 2;
  Map<String, dynamic> prepared = {
    'state': 'not_submitted',
    'message': '未提交，可修改',
  };
  Map<String, dynamic> submitted = {
    'state': 'accepted',
    'message': '已查回预约，审批状态请以学校为准',
  };
  Completer<ReadOnlyResponse>? optionsWait, prepareWait, submitWait;
  bool throwPrepare = false, throwSubmit = false;
  int calls(String action) =>
      commands.where((c) => c['action'] == action).length;
  ReadOnlyResponse response(Map<String, dynamic> value) =>
      ReadOnlyResponse(stale: false, payload: jsonEncode(value));
  @override
  Future<ReadOnlyResponse> executeCgyy(Map<String, Object?> command) async {
    commands.add(command);
    switch (command['action']) {
      case 'options':
        if (optionsWait != null) return optionsWait!.future;
        return response({
          'state': 'options',
          'options': {
            'choices': [
              for (var i = 1; i <= slots; i++)
                {
                  'space_id': 1,
                  'space_name': '合成空间',
                  'time_id': i,
                  'time': '时段 $i',
                },
            ],
            'purposes': [
              {'id': 1, 'name': '学习研讨类'},
            ],
          },
        });
      case 'prepare':
        if (throwPrepare) throw StateError('synthetic transport');
        return prepareWait?.future ?? response(prepared);
      case 'submit':
        if (throwSubmit) throw StateError('synthetic pre-check failure');
        return submitWait?.future ?? response(submitted);
    }
    throw StateError('Unexpected synthetic command');
  }
}

Future<String> png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xff55aa88),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return base64Encode(data!.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Finder button(String text) => find.widgetWithText(CupertinoButton, text);
CupertinoButton control(WidgetTester tester, String text) =>
    tester.widget<CupertinoButton>(button(text));
Future<void> reach(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    220,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> open(
  WidgetTester tester,
  SafetyGateway gateway, {
  Brightness brightness = Brightness.light,
  double width = 430,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 1500);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ginkgoApp(
      brightness: brightness,
      home: Builder(
        builder: (context) => CupertinoButton(
          child: const Text('打开合成预约'),
          onPressed: () => Navigator.of(context).push(
            CupertinoPageRoute<Map<String, dynamic>>(
              builder: (_) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: CgyyBookingPage(
                  gateway: gateway,
                  siteId: 1,
                  siteName: '合成场馆',
                  date: '2026-10-25',
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开合成预约'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  if (gateway.optionsWait == null) await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester) async {
  await reach(tester, find.text('时段 1'));
  await tester.tap(find.text('时段 1'));
  for (final (label, value) in [
    ('手机号（11 位）', '13800000000'),
    ('活动主题', '合成主题'),
    ('活动内容', '合成内容'),
    ('参与人说明', '合成人员'),
  ]) {
    final field = find.byWidgetPredicate(
      (w) => w is CupertinoTextField && w.placeholder == label,
    );
    await reach(tester, field);
    await tester.enterText(field, value);
  }
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  await reach(tester, find.text('确认信息并验证'));
}

Future<void> prepare(WidgetTester tester) async {
  await tester.tap(find.text('确认信息并验证'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('继续验证'));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> decodeReady(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pumpAndSettle();
}

Future<void> drag(WidgetTester tester) async {
  await reach(tester, find.byType(CupertinoSlider));
  final rect = tester.getRect(find.byType(CupertinoSlider));
  await tester.dragFrom(
    Offset(rect.left + 16, rect.center.dy),
    const Offset(90, 0),
  );
  await tester.pumpAndSettle();
  await reach(tester, find.text('验证并提交一次'));
}

void expectSummary() {
  for (final text in [
    '场馆：合成场馆',
    '日期：2026-10-25',
    '空间：合成空间',
    '时段：时段 1',
    '人数：1 人',
    '用途：学习研讨类',
    '手机：13800000000',
    '主题：合成主题',
    '内容：合成内容',
    '参与人：合成人员',
    '哲学社会科学类：否',
    '含校外参与人：否',
  ]) {
    expect(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.textContaining(text),
      ),
      findsOneWidget,
    );
  }
}

void main() {
  late String background, jigsaw;
  setUpAll(() async {
    background = await png(310, 155);
    jigsaw = await png(60, 155);
  });
  SafetyGateway challenge() => SafetyGateway()
    ..prepared = {
      'state': 'challenge',
      'challenge': {
        'id': 'synthetic-challenge',
        'background': background,
        'jigsaw': jigsaw,
      },
    };
  testWidgets(
    'prepare summary and same-frame double tap; cancel does not write',
    (tester) async {
      final gateway = SafetyGateway();
      await open(tester, gateway);
      await fill(tester);
      final callback = control(tester, '确认信息并验证').onPressed!;
      callback();
      callback();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expectSummary();
      expect(gateway.calls('prepare'), 0);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(gateway.calls('prepare'), 0);
      expect(control(tester, '确认信息并验证').onPressed, isNotNull);
    },
  );
  testWidgets('required validation before any dialog or write', (tester) async {
    final gateway = SafetyGateway();
    await open(tester, gateway);
    await reach(tester, find.text('确认信息并验证'));
    await tester.tap(find.text('确认信息并验证'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(gateway.calls('prepare'), 0);
  });
  testWidgets('only twelve slots can be selected and sent', (tester) async {
    final gateway = SafetyGateway()..slots = 13;
    await open(tester, gateway);
    await fill(tester);
    for (var i = 2; i <= 13; i++) {
      await reach(tester, find.text('时段 $i'));
      await tester.tap(find.text('时段 $i'));
      await tester.pump();
    }
    await reach(tester, find.text('确认信息并验证'));
    await prepare(tester);
    await tester.pumpAndSettle();
    final booking =
        gateway.commands.singleWhere((c) => c['action'] == 'prepare')['booking']
            as Map;
    expect(booking['time_ids'], List.generate(12, (i) => i + 1));
  });
  testWidgets(
    'options read allows return and late completion is mounted-safe',
    (tester) async {
      final gateway = SafetyGateway()
        ..optionsWait = Completer<ReadOnlyResponse>();
      await open(tester, gateway);
      await tester.tap(find.byKey(const Key('booking-back')));
      await tester.pumpAndSettle();
      expect(find.text('打开合成预约'), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      gateway.optionsWait!.complete(
        gateway.response({
          'state': 'options',
          'options': {'choices': [], 'purposes': []},
        }),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('dirty system and button return require discard confirmation', (
    tester,
  ) async {
    final gateway = SafetyGateway();
    await open(tester, gateway);
    await fill(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的预约？'), findsOneWidget);
    await tester.tap(find.text('继续填写'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃并返回'));
    await tester.pumpAndSettle();
    expect(find.text('打开合成预约'), findsOneWidget);
    expect(gateway.calls('prepare'), 0);
  });
  testWidgets('delayed prepare blocks returns until explicit not_submitted', (
    tester,
  ) async {
    final gateway = SafetyGateway()
      ..prepareWait = Completer<ReadOnlyResponse>();
    await open(tester, gateway);
    await fill(tester);
    await prepare(tester);
    expect(
      tester
          .widget<CupertinoButton>(find.byKey(const Key('booking-back')))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CgyyBookingPage), findsOneWidget);
    expect(gateway.calls('prepare'), 1);
    gateway.prepareWait!.complete(
      gateway.response({'state': 'notSubmitted', 'message': '尚未提交，可修改'}),
    );
    await tester.pumpAndSettle();
    expect(control(tester, '确认信息并验证').onPressed, isNotNull);
  });
  for (final throws in [false, true]) {
    testWidgets('unknown prepare locks; throws=$throws', (tester) async {
      final gateway = SafetyGateway()
        ..throwPrepare = throws
        ..prepared = {'state': 'mystery', 'message': 'not trusted'};
      await open(tester, gateway);
      await fill(tester);
      await prepare(tester);
      await tester.pumpAndSettle();
      expect(control(tester, '确认信息并验证').onPressed, isNull);
      expect(gateway.calls('prepare'), 1);
      expect(find.textContaining('成功'), findsNothing);
    });
  }
  testWidgets('bad captcha image cannot submit', (tester) async {
    final gateway = challenge();
    (gateway.prepared['challenge'] as Map)['jigsaw'] = 'invalid';
    await open(tester, gateway);
    await fill(tester);
    await prepare(tester);
    await decodeReady(tester);
    expect(find.textContaining('验证图片无法显示'), findsOneWidget);
    expect(control(tester, '验证并提交一次').onPressed, isNull);
    expect(gateway.calls('submit'), 0);
  });
  testWidgets(
    'PNG needs manual drag; final confirmation cancel does not submit',
    (tester) async {
      final gateway = challenge();
      await open(tester, gateway);
      await fill(tester);
      await prepare(tester);
      await decodeReady(tester);
      expect(control(tester, '验证并提交一次').onPressed, isNull);
      final slider = tester.widget<CupertinoSlider>(
        find.byType(CupertinoSlider),
      );
      slider.onChanged!(0);
      slider.onChangeEnd!(0);
      await tester.pump();
      expect(control(tester, '验证并提交一次').onPressed, isNull);
      await drag(tester);
      final callback = control(tester, '验证并提交一次').onPressed!;
      callback();
      callback();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expectSummary();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(gateway.calls('submit'), 0);
      expect(control(tester, '验证并提交一次').onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('captcha-back')));
      await tester.pumpAndSettle();
      expect(find.byType(CgyyBookingPage), findsOneWidget);
      expect(gateway.calls('submit'), 0);
    },
  );
  for (final state in [
    'accepted',
    'uncertain',
    'rejected',
    'mystery',
    'throw',
  ]) {
    testWidgets('single-use challenge terminal state $state', (tester) async {
      final gateway = challenge()
        ..submitted = {'state': state, 'message': '合成终态 $state'}
        ..throwSubmit = state == 'throw';
      await open(tester, gateway);
      await fill(tester);
      await prepare(tester);
      await decodeReady(tester);
      await drag(tester);
      final callback = control(tester, '验证并提交一次').onPressed!;
      callback();
      callback();
      await tester.pumpAndSettle();
      final confirm = tester
          .widget<CupertinoDialogAction>(
            find.widgetWithText(CupertinoDialogAction, '提交一次'),
          )
          .onPressed!;
      confirm();
      confirm();
      await tester.pumpAndSettle();
      expect(gateway.calls('submit'), 1);
      expect(find.text('学校拼图验证'), findsNothing);
      final command = gateway.commands.singleWhere(
        (c) => c['action'] == 'submit',
      );
      expect(command['challenge_id'], 'synthetic-challenge');
      expect(command['x'], greaterThan(0));
      expect(
        control(tester, '确认信息并验证').onPressed,
        state == 'rejected' ? isNotNull : isNull,
      );
      if (state == 'mystery' || state == 'throw') {
        expect(find.textContaining('结果待核实'), findsOneWidget);
      }
      if (state == 'rejected') {
        await reach(tester, find.text('时段 1'));
        await tester.tap(find.text('时段 1'));
        await reach(tester, find.text('确认信息并验证'));
        await prepare(tester);
        await decodeReady(tester);
        expect(find.textContaining('此验证已使用'), findsOneWidget);
        expect(control(tester, '验证并提交一次').onPressed, isNull);
        control(tester, '验证并提交一次').onPressed?.call();
        await tester.pumpAndSettle();
        expect(gateway.calls('submit'), 1);
        expect(find.byType(CupertinoAlertDialog), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('delayed submit disables returns and preserves one call', (
    tester,
  ) async {
    final gateway = challenge()..submitWait = Completer<ReadOnlyResponse>();
    await open(tester, gateway);
    await fill(tester);
    await prepare(tester);
    await decodeReady(tester);
    await drag(tester);
    final callback = control(tester, '验证并提交一次').onPressed!;
    callback();
    callback();
    await tester.pumpAndSettle();
    await tester.tap(find.text('提交一次'));
    await tester.pumpAndSettle();
    expect(gateway.calls('submit'), 1);
    expect(
      tester
          .widget<CupertinoButton>(find.byKey(const Key('captcha-back')))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('学校拼图验证'), findsOneWidget);
    gateway.submitWait!.complete(
      gateway.response({'state': 'uncertain', 'message': '结果待核实'}),
    );
    await tester.pumpAndSettle();
    expect(gateway.calls('submit'), 1);
    expect(control(tester, '确认信息并验证').onPressed, isNull);
  });
  for (final action in ['prepare', 'submit']) {
    testWidgets('late $action response after disposal is ignored safely', (
      tester,
    ) async {
      final gateway = challenge();
      final completer = Completer<ReadOnlyResponse>();
      if (action == 'prepare') {
        gateway.prepareWait = completer;
      } else {
        gateway.submitWait = completer;
      }
      await open(tester, gateway);
      await fill(tester);
      await prepare(tester);
      if (action == 'submit') {
        await decodeReady(tester);
        await drag(tester);
        await tester.tap(find.text('验证并提交一次'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('提交一次'));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      completer.complete(
        gateway.response({'state': 'uncertain', 'message': '结果待核实'}),
      );
      await tester.pumpAndSettle();
      expect(gateway.calls(action), 1);
      expect(tester.takeException(), isNull);
    });
  }
  for (final brightness in Brightness.values) {
    testWidgets('320dp 2x ${brightness.name} full form and manual challenge', (
      tester,
    ) async {
      final gateway = challenge();
      await open(tester, gateway, width: 320, scale: 2, brightness: brightness);
      await fill(tester);
      await tester.tap(find.text('确认信息并验证'));
      await tester.pumpAndSettle();
      expectSummary();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('继续验证'));
      await tester.pump(const Duration(milliseconds: 500));
      await decodeReady(tester);
      await drag(tester);
      await tester.tap(find.text('验证并提交一次'));
      await tester.pumpAndSettle();
      expectSummary();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(gateway.calls('submit'), 0);
    });
  }
}
