import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/graduate_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

void main() {
  testWidgets(
    'academic sections publish independently and keep snapshots after report failure',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <bool, List<Completer<ReadOnlyResponse>>>{
        false: [],
        true: [],
      };
      await tester.pumpWidget(
        ginkgoApp(
          home: GraduatePage(
            loader: ({required report, required forceRefresh}) {
              final pending = Completer<ReadOnlyResponse>();
              requests[report]!.add(pending);
              return pending.future;
            },
          ),
        ),
      );
      requests[false]!.single.complete(
        ReadOnlyResponse(
          stale: false,
          payload: jsonEncode({
            'sections': [
              {
                'title': '学籍信息',
                'rows': [
                  {'title': '学院', 'detail': '合成学院'},
                ],
              },
            ],
          }),
        ),
      );
      await tester.pump();
      expect(find.text('合成学院'), findsOneWidget);
      expect(find.byType(GraduateCreditProgress), findsNothing);
      final fixture = jsonDecode(
        File('../fixtures/graduate/execution-normal-v1.json')
            .readAsStringSync(),
      ) as Map;
      requests[true]!.single.complete(
        ReadOnlyResponse(
          stale: false,
          payload: jsonEncode(fixture['expected']),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('尚需 30'), findsOneWidget);
      expect(find.text('尚需 4'), findsOneWidget);
      expect(find.text('2 学分 · 已完成'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('刷新研究生教务').first);
      await tester.pump();
      requests[true]!.last.complete(
        const ReadOnlyResponse(
          stale: false,
          failure: FailureCode.serviceUnavailable,
        ),
      );
      await tester.pump();
      expect(find.text('尚需 30'), findsOneWidget);
      expect(find.text('合成学院'), findsOneWidget);
      // Retrying the failed report leaves the status request in flight.
      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(requests[true]!.length, 3);
      expect(requests[false]!.length, 2);
      requests[false]!.last.complete(
        const ReadOnlyResponse(stale: false, payload: '{"sections":[]}'),
      );
      requests[true]!.last.complete(
        ReadOnlyResponse(
          stale: false,
          payload: jsonEncode(fixture['expected']),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('合成学院'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'credit progress keeps missing and zero requirements distinct at large text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ginkgoApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: CupertinoTheme(
              data: const CupertinoThemeData(brightness: Brightness.dark),
              child: const CupertinoPageScaffold(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      GraduateCreditProgress(
                        progress: {
                          'required': null,
                          'earned': 2,
                          'pending': null,
                        },
                      ),
                      GraduateCreditProgress(
                        progress: {'required': 0, 'earned': 0, 'pending': 0},
                      ),
                      GraduateCreditProgress(
                        progress: {'required': 4, 'earned': 6, 'pending': 5},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('学分信息不完整'), findsNWidgets(2));
      expect(find.text('尚需 未确认'), findsOneWidget);
      expect(find.text('尚需 0'), findsNWidgets(2));
      expect(find.text('待考核 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
