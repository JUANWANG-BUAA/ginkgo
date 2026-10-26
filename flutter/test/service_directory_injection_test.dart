import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/workspace/service_directory.dart';
import 'package:ginkgo_mirror/infrastructure/demo_mirror_service.dart';
import 'package:ginkgo_mirror/features/learning/learning_page.dart';
import 'package:ginkgo_mirror/features/graduate/graduate_credit_map_page.dart';
import 'package:ginkgo_mirror/features/library/library_loans_page.dart';

import 'mirror_widget_test.dart' show ControlledService;

class InjectedNotices extends ControlledService {
  int reads = 0;

  @override
  Future<ReadOnlyResponse> notices({bool forceRefresh = false}) async {
    reads++;
    return ReadOnlyResponse(
      payload: jsonEncode([
        {
          'title': '来自注入服务的通知',
          'summary': '合成摘要',
          'published_at': '2026-10-22',
          'url': 'https://example.invalid/synthetic',
        },
      ]),
      stale: false,
    );
  }
}

void main() {
  testWidgets('feature navigation preserves the injected provider', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = InjectedNotices();
    await tester.pumpWidget(
      ginkgoApp(
        home: CupertinoPageScaffold(
          child: ServiceDirectory(service: service, onSignOut: () async {}),
        ),
      ),
    );
    await tester.tap(find.text('校园通知'));
    await tester.pumpAndSettle();
    expect(service.reads, 1);
    expect(find.text('来自注入服务的通知'), findsOneWidget);
  });
  for (final entry in [
    ('SPOC 学习', LearningPage),
    ('研究生学分图', GraduateCreditMapPage),
    ('本人借阅', LibraryLoansPage),
  ]) {
    testWidgets('mobile directory opens ${entry.$1} with large type', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ginkgoApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 760),
              textScaler: TextScaler.linear(1.6),
            ),
            child: CupertinoPageScaffold(
              child: ListView(
                children: [
                  ServiceDirectory(
                    service: const DemoMirrorService(),
                    accountId: 'synthetic-account',
                    onSignOut: () async {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text(entry.$1));
      await tester.tap(find.text(entry.$1));
      await tester.pumpAndSettle();
      expect(find.byType(entry.$2), findsOneWidget);
      if (entry.$2 == LearningPage) {
        expect(
          tester.widget<LearningPage>(find.byType(LearningPage)).accountId,
          'synthetic-account',
        );
      }
      if (entry.$2 == GraduateCreditMapPage) {
        expect(
          tester
              .widget<GraduateCreditMapPage>(find.byType(GraduateCreditMapPage))
              .accountId,
          'synthetic-account',
        );
      }
      if (entry.$2 == LibraryLoansPage) {
        expect(find.text('合成借阅示例'), findsNothing);
        await tester.tap(find.text('读取本人借阅'));
        await tester.pumpAndSettle();
        expect(find.text('合成借阅示例'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
