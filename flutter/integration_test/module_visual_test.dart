import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/features/learning/learning_page.dart';
import 'package:ginkgo_mirror/features/graduate/graduate_credit_map_page.dart';
import 'package:ginkgo_mirror/features/homework/homework_files_panel.dart';
import 'package:ginkgo_mirror/infrastructure/demo_homework_files.dart';
import 'package:ginkgo_mirror/features/library/library_loans_page.dart';
import 'package:ginkgo_mirror/features/library/library_books_page.dart';
import 'package:ginkgo_mirror/features/shuttle/shuttle_page.dart';
import 'package:ginkgo_mirror/features/settings/settings_page.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';
import 'package:ginkgo_mirror/workspace/workspace_tab_transition.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';
import 'package:ginkgo_mirror/application/contracts.dart';

import 'support.dart' show settle;

const demo = DemoMirrorService();

class PublicBooks implements LibraryGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<ReadOnlyResponse> libraryBooks({
    required String query,
    int page = 1,
    String sort = 'relevance',
    bool descending = true,
  }) async => const ReadOnlyResponse(
    stale: false,
    payload: '{"total":2,"actualTotal":2,"page":1,"pageSize":20,"hasMore":false,"items":[{"bibId":"SYNTHETIC1","title":"合成示例：计算机系统导论与实践","author":"示例作者","publisher":"示例出版社","year":"2026","callno":"TP3/1","isbn":"","doc_type":"图书"},{"bibId":"SYNTHETIC2","title":"合成示例：设计与日常生活","author":"示例作者","publisher":"示例出版社","year":"2025","callno":"J0/2","isbn":"","doc_type":"图书"}]}',
  );
}

const largeType = bool.fromEnvironment('GINKGO_VISUAL_LARGE');
const captureToHost = bool.fromEnvironment('GINKGO_VISUAL_CAPTURE');
const primitivesOnly = bool.fromEnvironment('GINKGO_VISUAL_PRIMITIVES_ONLY');
const tabsOnly = bool.fromEnvironment('GINKGO_VISUAL_TABS_ONLY');
const scalePercent = int.fromEnvironment(
  'GINKGO_VISUAL_SCALE_PERCENT',
  defaultValue: largeType ? 160 : 100,
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await RustLib.init();
  });
  testWidgets('synthetic module visual loop without school writes', (
    tester,
  ) async {
    await binding.convertFlutterSurfaceToImage();
    final root = await getTemporaryDirectory();
    final directory = Directory('${root.path}/goal-visual')
      ..createSync(recursive: true);
    Future<void> capture(String name, {bool advance = true}) async {
      if (advance) await settle(tester, frames: 8);
      expect(tester.takeException(), isNull);
      final bytes = await binding.takeScreenshot(name);
      binding.reportData?.remove('screenshots');
      if (captureToHost) {
        await tester.runAsync(() async {
          final socket = await Socket.connect(
            '127.0.0.1',
            18765,
            timeout: const Duration(seconds: 5),
          );
          socket.add(
            'POST /$name.png HTTP/1.0\r\nHost: 127.0.0.1\r\nContent-Length: ${bytes.length}\r\n\r\n'
                .codeUnits,
          );
          socket.add(bytes);
          await socket.flush();
          await socket.drain<void>();
          socket.destroy();
        });
      }
      await File('${directory.path}/$name.png')
          .writeAsBytes(bytes, flush: true);
    }

    Future<void> show(Widget page, bool dark) async {
      await tester.pumpWidget(
        CupertinoApp(
          key: UniqueKey(),
          debugShowCheckedModeBanner: false,
          theme: ginkgoTheme(
            dark ? Brightness.dark : Brightness.light,
            largeType
                ? CupertinoColors.systemPurple
                : CupertinoColors.systemGreen,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scalePercent / 100)),
            child: child!,
          ),
          home: page,
        ),
      );
      await settle(tester, frames: 20);
    }

    for (final dark in [false, true]) {
      final mode = '${dark ? 'dark' : 'light'}${largeType ? '-large' : ''}';
      if (tabsOnly) {
        await tester.pumpWidget(
          GinkgoApp(
            key: UniqueKey(),
            service: demo,
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
        );
        await settle(tester);
        await capture('tabs-$mode-before');
        // Slow only the screenshot run, so the engine can capture both real
        // pages mid-turn. Production duration remains 230ms.
        final originalDilation = timeDilation;
        try {
          timeDilation = 10;
          for (final label in ['课表', '工作台']) {
            await tester.tap(
              find.descendant(
                of: find.byType(CupertinoTabBar),
                matching: find.text(label),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));
            expect(find.byType(WorkspaceTabTransition), findsNWidgets(2));
            await capture(
              'tabs-$mode-${label == '课表' ? 'forward' : 'reverse'}-mid',
              advance: false,
            );
            await settle(tester, frames: 30);
          }
        } finally {
          timeDilation = originalDilation;
        }
        await settle(tester);
        await tester.drag(find.byType(CupertinoTabBar), const Offset(-110, 0));
        await settle(tester);
        expect(
          tester
              .widget<WorkspaceTabScaffold>(find.byType(WorkspaceTabScaffold))
              .controller
              .index,
          1,
        );
        await capture('tabs-$mode-swipe');
        continue;
      }
      if (primitivesOnly) {
        const tint = CupertinoDynamicColor.withBrightness(
          color: Color(0xff006640),
          darkColor: Color(0xff80ffb0),
        );
        await show(
          CupertinoPageScaffold(
            navigationBar: const CupertinoNavigationBar(middle: Text('标签')),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('合成状态；非学校数据', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 16),
                    for (final compact in [false, true]) ...[
                      SizedBox(
                        width: 160,
                        child: GinkgoBadge(
                          label: '尚未确认，请勿再次提交',
                          icon: CupertinoIcons.exclamationmark_triangle,
                          color: tint,
                          compact: compact,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const GinkgoIconTile(
                      icon: CupertinoIcons.checkmark,
                      color: tint,
                      semanticLabel: '合成状态图标',
                    ),
                  ],
                ),
              ),
            ),
          ),
          dark,
        );
        await capture('primitives-$mode-scale$scalePercent');
        if (scalePercent >= 200) {
          await tester.ensureVisible(find.byType(GinkgoIconTile));
          await capture('primitives-$mode-scale$scalePercent-end');
        }
        continue;
      }
      await show(LearningPage(service: demo), dark);
      await capture('learning-$mode');
      await tester.tap(
        find.byKey(const ValueKey('learning-course-demo-learning-course')),
      );
      await settle(tester);
      await capture('course-$mode');
      await show(GraduateCreditMapPage(service: demo), dark);
      await capture('credit-$mode');
      await show(
        CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(middle: Text('合成作业详情')),
          child: SafeArea(
            child: ListView(
              children: [
                HomeworkFilesPanel(
                  assignmentId: 'fixture',
                  title: '合成课程设计报告',
                  course: '合成课程',
                  gateway: DemoHomeworkFiles(),
                ),
              ],
            ),
          ),
        ),
        dark,
      );
      await capture('homework-files-$mode');
      await show(LibraryLoansPage(gateway: demo), dark);
      await tester.tap(find.text('读取本人借阅'));
      await capture('loans-$mode');
      await show(LibraryBooksPage(service: PublicBooks()), dark);
      await capture('books-$mode');
      await tester.enterText(
        find.byKey(const Key('library-books-query')),
        '合成',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await capture('books-results-$mode');
      await show(
        ShuttlePage(service: demo, now: DateTime(2026, 10, 26, 8, 20)),
        dark,
      );
      await capture('shuttle-$mode');
      await show(SettingsPage(service: demo, onSignOut: () async {}), dark);
      await capture('settings-$mode');
    }
  });
}
