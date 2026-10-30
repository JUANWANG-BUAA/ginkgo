import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/features/campus_card/campus_card_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'mirror_widget_test.dart' show ControlledService;

class _FakeCampusCardGateway implements CampusCardGateway {
  @override
  bool get isDemo => false;

  @override
  Future<CampusCardBalanceResponse> campusCardBalance() async =>
      const CampusCardBalanceResponse(
        balanceMinor: 12345,
        fetchedAt: '2026-10-20T08:00:00+08:00',
      );
}

/// The semantics node that carries [label].
SemanticsNode _nodeWithLabel(WidgetTester tester, Pattern label) {
  final finder = find.bySemanticsLabel(label);
  expect(finder, findsOneWidget);
  return tester.getSemantics(finder);
}

/// The semantics bounds of [label] must stay on the widget that owns it.
void _expectBoundedTo(WidgetTester tester, Pattern label, Rect widget) {
  final rect = _nodeWithLabel(tester, label).getSemanticsData().rect;
  expect(
    rect.width,
    closeTo(widget.width, 1),
    reason: 'the node for $label must not be wider than its widget',
  );
  expect(
    rect.height,
    closeTo(widget.height, 1),
    reason: 'the node for $label must not be taller than its widget',
  );
}

void main() {
  testWidgets('the campus card read button owns its own bounded node', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ginkgoApp(home: CampusCardPage(gateway: _FakeCampusCardGateway())),
    );
    await tester.pumpAndSettle();

    final card = tester.getRect(find.byType(AppleSection));
    final button = tester.getRect(find.byKey(const Key('campus-card-read')));

    // The button used to share one node with the whole card, so a screen
    // reader or an automation tap aimed at "查询余额" landed anywhere on the
    // card instead of on the button.
    _expectBoundedTo(tester, '查询余额', button);
    expect(button.width, lessThan(card.width));
    expect(button.height, lessThan(card.height));

    final data = _nodeWithLabel(tester, '查询余额').getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('a homework row is one node bounded to the row', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GinkgoApp(service: ControlledService()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('作业').last);
    await tester.pumpAndSettle();

    final tile = tester.getRect(find.byKey(const Key('homework-spoc:a')));
    // The row used to be folded into a node that spanned the whole screen
    // width, so an automation tap aimed at the row could hit the tab bar.
    _expectBoundedTo(tester, RegExp('作业一'), tile);

    final data = _nodeWithLabel(tester, RegExp('作业一')).getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.label, contains('作业一'));
    expect(data.label, contains('软件工程'));
    handle.dispose();
  });

  testWidgets('a section header is announced as a heading', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      ginkgoApp(
        home: CupertinoPageScaffold(
          child: SafeArea(
            child: ListView(
              children: const [
                AppleSection(
                  header: Text('校园卡余额'),
                  children: [AppleListTile(title: Text('金额默认遮挡'))],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final header = _nodeWithLabel(tester, '校园卡余额');
    expect(header.getSemanticsData().flagsCollection.isHeader, isTrue);
    final row = _nodeWithLabel(tester, '金额默认遮挡');
    expect(row.getSemanticsData().label, '金额默认遮挡');
    handle.dispose();
  });
}
