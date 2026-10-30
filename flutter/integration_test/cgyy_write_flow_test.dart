import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/application/cgyy_commands.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_models.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_page.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_review_page.dart';
import 'package:ginkgo_mirror/workspace/workspace_shell.dart';

import '../test/cgyy_management_test.dart' show ManagementService, currentOrder;
import '../test/cgyy_booking_safety_test.dart' show SafetyGateway, png;
import 'support.dart' show settle;

/// Synthetic only: no native runtime, credentials or school network are used.
class DeviceBookingService extends ManagementService {
  final form = SafetyGateway();
  @override
  Future<CgyyActionResult> executeCgyy(CgyyCommand command) async {
    final action = command.toPayload()['action'];
    if (['options', 'prepare', 'submit'].contains(action)) {
      if (action == 'submit') pending = true;
      return form.executeCgyy(command);
    }
    return super.executeCgyy(command);
  }
}

Future<void> reach(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    220,
    scrollable: find.byType(Scrollable).last,
    maxScrolls: 40,
  );
  await settle(tester, frames: 4);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  var converted = false;
  Future<void> capture(WidgetTester tester, String name) async {
    await settle(tester, frames: 3);
    expect(tester.takeException(), isNull);
    if (!converted) {
      await binding.convertFlutterSurfaceToImage();
      converted = true;
    }
    await binding.takeScreenshot(name);
  }

  testWidgets(
    'synthetic room form captcha unknown review and cancellation closure',
    (tester) async {
      final service = DeviceBookingService();
      service.form.prepared = CgyyActionResult.of(
        state: 'challenge',
        challenge: CgyyChallenge(
          id: 'device-fixture',
          background: await png(310, 155),
          jigsaw: await png(60, 155),
        ),
      );
      service.form.submitted = CgyyActionResult.fromState(
        'uncertain',
        '合成：提交结果待核实，请查订单',
      );
      await tester.pumpWidget(
        ginkgoApp(home: CgyyPage(service: service, bookingGateway: service)),
      );
      await settle(tester);
      await tester.tap(find.byKey(const Key('cgyy-site-1')));
      await settle(tester);
      await reach(tester, find.byKey(const Key('cgyy-open-booking')));
      await tester.tap(find.byKey(const Key('cgyy-open-booking')));
      await settle(tester);
      await reach(tester, find.text('时段 1'));
      await tester.tap(find.text('时段 1'));
      for (final (label, value) in [
        ('手机号（11 位）', '13800000000'),
        ('活动主题', '合成课程讨论'),
        ('活动内容', '合成测试，不会发送学校请求'),
        ('参与人说明', '合成人员'),
      ]) {
        final field = find.byWidgetPredicate(
          (w) => w is CupertinoTextField && w.placeholder == label,
        );
        await reach(tester, field);
        await tester.enterText(field, value);
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester, frames: 5);
      await reach(tester, find.text('确认信息并验证'));
      await tester.tap(find.text('确认信息并验证'));
      await settle(tester);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.textContaining('手机：13800000000'), findsOneWidget);
      await capture(tester, 'cgyy-write-summary');
      await tester.tap(find.text('继续验证'));
      await settle(tester);
      await reach(tester, find.byType(CupertinoSlider));
      await capture(tester, 'cgyy-manual-captcha');
      final rect = tester.getRect(find.byType(CupertinoSlider));
      await tester.dragFrom(
        Offset(rect.left + 16, rect.center.dy),
        const Offset(90, 0),
      );
      await settle(tester, frames: 3);
      await reach(tester, find.text('验证并提交一次'));
      await tester.tap(find.text('验证并提交一次'));
      await settle(tester);
      await tester.tap(find.text('提交一次'));
      await settle(tester);
      await reach(tester, find.text('返回并核对我的预约'));
      await tester.tap(find.text('返回并核对我的预约'));
      await settle(tester);
      expect(find.text('预约记录'), findsOneWidget);
      expect(service.form.calls('prepare'), 1);
      expect(service.form.calls('submit'), 1);
      await tester.tap(find.byKey(const Key('cgyy-open-review')));
      await settle(tester);
      expect(find.byType(CgyyReviewPage), findsOneWidget);
      expect(find.textContaining('订单 42'), findsOneWidget);
      await capture(tester, 'cgyy-fresh-review');
      await reach(tester, find.byKey(const Key('cgyy-review-checked')));
      await tester.tap(find.byKey(const Key('cgyy-review-checked')));
      await settle(tester, frames: 3);
      await reach(tester, find.byKey(const Key('cgyy-review-acknowledge')));
      await tester.tap(find.byKey(const Key('cgyy-review-acknowledge')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('cgyy-review-confirm')));
      await settle(tester);
      expect(service.pending, false);
      await reach(tester, find.byKey(const Key('cgyy-cancel-42')));
      await tester.tap(find.byKey(const Key('cgyy-cancel-42')));
      await settle(tester);
      expect(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.textContaining('订单 42'),
        ),
        findsOneWidget,
      );
      await capture(tester, 'cgyy-cancel-summary');
      await tester.tap(find.text('保留预约'));
      await settle(tester);
      expect(service.commands.where((c) => c['action'] == 'cancel'), isEmpty);
      expect(service.form.calls('submit'), 1);
      expect(tester.takeException(), isNull);
      // Explicitly prove all effects went to in-memory fixtures.
      expect(currentOrder.id, 42);
      expect(jsonEncode(service.form.commands), contains('device-fixture'));
    },
  );
}
