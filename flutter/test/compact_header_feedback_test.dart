import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/tasks/tasks_widgets.dart';
import 'package:ginkgo_mirror/features/library/library_widgets.dart';
import 'package:ginkgo_mirror/platform/update_gate.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

void main() {
  testWidgets('required update remains readable in dark mode', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.dark),
        home: UpdateRequiredPage(
          gate: const UpdateGate(minBuild: 20),
          installedVersion: '合成旧版本',
          onRetry: () async {},
        ),
      ),
    );
    final title = tester.renderObject<RenderParagraph>(find.text('需要更新'));
    expect(title.text.style!.color!.computeLuminance(), greaterThan(0.8));
  });

  testWidgets('task heading resolves its color in dark mode', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.dark),
        home: CupertinoPageScaffold(
          child: CustomScrollView(
            slivers: [
              TasksPageHeader(
                actions: const SizedBox(width: 96, height: 48),
                canPop: false,
                onBack: () {},
              ),
            ],
          ),
        ),
      ),
    );
    final heading = tester.renderObject<RenderParagraph>(find.text('待办'));
    expect(heading.text.style!.color!.computeLuminance(), greaterThan(0.8));
  });

  Widget host(Widget child) => CupertinoApp(
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(320, 700),
        textScaler: TextScaler.linear(1.6),
      ),
      child: CupertinoPageScaffold(child: child),
    ),
  );

  testWidgets('library failure keeps full width at large text', (tester) async {
    await tester.pumpWidget(
      host(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 280,
            child: LibrarySectionStatus(
              id: 'bookings',
              loading: false,
              hasSnapshot: false,
              failure: '本地服务暂时不可用，请重试',
              retry: () {},
            ),
          ),
        ),
      ),
    );
    final error = tester.getRect(find.text('本地服务暂时不可用，请重试'));
    expect(error.width, greaterThan(220));
    expect(tester.getRect(find.text('重试')).top, greaterThan(error.bottom));
  });

  testWidgets('collapsed narrow title stays inside the navigation bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      host(
        CustomScrollView(
          controller: scroll,
          slivers: [
            const ApplePageHeader(
              largeTitle: Text('研究生教务'),
              leading: SizedBox(width: 90, child: Text('工作台')),
              icon: CupertinoIcons.briefcase,
              trailing: SizedBox(
                width: 48,
                child: Icon(CupertinoIcons.refresh),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 1500)),
          ],
        ),
      ),
    );
    scroll.jumpTo(300);
    await tester.pumpAndSettle();
    final visibleTitle = find
        .text('研究生教务')
        .evaluate()
        .map((element) => element.renderObject)
        .whereType<RenderParagraph>()
        .where((paragraph) => paragraph.text.style?.fontSize == 17)
        .first;
    expect(visibleTitle.size.height, lessThan(36));
    expect(tester.takeException(), isNull);
  });

  testWidgets('large feedback gives text its own row above retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var retries = 0;
    await tester.pumpWidget(
      host(
        Align(
          alignment: Alignment.topCenter,
          child: SectionFeedback(
            loading: false,
            hasData: true,
            label: '读取中',
            error: '本地服务暂时不可用，请重试',
            onRetry: () => retries++,
          ),
        ),
      ),
    );
    final error = tester.getRect(find.text('本地服务暂时不可用，请重试'));
    final retry = tester.getRect(find.text('重试'));
    expect(error.width, greaterThan(190));
    expect(retry.top, greaterThan(error.bottom));
    await tester.tap(find.text('重试'));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
}
