import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/notices.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/workspace/service_directory.dart';
import 'package:ginkgo_mirror/workspace/workspace_catalog.dart';
import 'package:ginkgo_mirror/infrastructure/demo_mirror_service.dart';
import 'package:ginkgo_mirror/features/learning/learning_page.dart';
import 'package:ginkgo_mirror/features/library/library_loans_page.dart';

import 'mirror_widget_test.dart' show ControlledService;

class InjectedNotices extends ControlledService {
  int reads = 0;

  @override
  Future<NoticesRead> notices({bool forceRefresh = false}) async {
    reads++;
    return const NoticesRead(
      data: [
        Notice(
          title: '来自注入服务的通知',
          summary: '合成摘要',
          publishedAt: '2026-10-22',
          url: 'https://example.invalid/synthetic',
        ),
      ],
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
          child: ServiceDirectory(
            service: service,
            destinations: workspaceDestinations,
            onSignOut: () async {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('校园通知'));
    await tester.pumpAndSettle();
    expect(service.reads, 1);
    expect(find.text('来自注入服务的通知'), findsOneWidget);
  });
  testWidgets('mobile directory has one graduate destination', (tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ginkgoApp(
        home: CupertinoPageScaffold(
          child: ServiceDirectory(
            service: const DemoMirrorService(),
            destinations: workspaceDestinations,
            onSignOut: () async {},
          ),
        ),
      ),
    );
    expect(find.text('研究生教务'), findsOneWidget);
    expect(find.text('研究生学分图'), findsNothing);
  });
  for (final entry in [('SPOC 学习', LearningPage), ('本人借阅', LibraryLoansPage)]) {
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
                    destinations: workspaceDestinations,
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
