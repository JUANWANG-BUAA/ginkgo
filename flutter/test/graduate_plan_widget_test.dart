import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/graduate_page.dart';
import 'package:ginkgo_mirror/graduate_plan_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart';

ReadOnlyResponse planFixture() {
  final fixture = jsonDecode(
    File('../fixtures/graduate/plan-normal-v1.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return ReadOnlyResponse(
    stale: false,
    payload: jsonEncode(fixture['expected']),
  );
}

void main() {
  testWidgets('plan fetch starts only when opening its independent route', (
    tester,
  ) async {
    var calls = 0;
    final pending = Completer<ReadOnlyResponse>();
    await tester.pumpWidget(
      ginkgoApp(
        home: GraduatePage(
          loader: ({required report, required forceRefresh}) async =>
              ReadOnlyResponse(stale: false, payload: '{"sections":[]}'),
          planLoader: ({required forceRefresh}) {
            calls++;
            return pending.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.ensureVisible(find.text('培养方案与原文'));
    await tester.tap(find.text('培养方案与原文'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, 1);
    expect(find.text('正在读取培养方案…'), findsOneWidget);
    pending.complete(planFixture());
    await tester.pumpAndSettle();
    expect(find.text('合成培养方案'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(GraduatePlanPage), findsNothing);
    expect(calls, 1);
  });

  testWidgets(
    'large dark plan keeps expanded text on failed coalesced refresh',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <Completer<ReadOnlyResponse>>[];
      final forced = <bool>[];
      await tester.pumpWidget(
        ginkgoApp(
          brightness: Brightness.dark,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.8),
              disableAnimations: true,
            ),
            child: GraduatePlanPage(
              loader: ({required forceRefresh}) {
                forced.add(forceRefresh);
                final pending = Completer<ReadOnlyResponse>();
                requests.add(pending);
                return pending.future;
              },
            ),
          ),
        ),
      );
      requests.single.complete(planFixture());
      await tester.pumpAndSettle();
      final chapter = find.byKey(const ValueKey('plan-section-1'));
      await tester.scrollUntilVisible(
        chapter,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('合成方案正文 & 要求'), findsNothing);
      await tester.tap(chapter);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('合成方案正文 & 要求'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(SelectableText), findsOneWidget);
      final refresh = tester.widget<CupertinoSliverRefreshControl>(
        find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
      );
      final first = refresh.onRefresh!();
      final second = refresh.onRefresh!();
      expect(requests.length, 2);
      expect(forced, [false, true]);
      requests.last.completeError(StateError('synthetic failure'));
      await Future.wait([first, second]);
      await tester.pumpAndSettle();
      expect(find.text('合成方案正文 & 要求'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('保留上次结果'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('保留上次结果'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
