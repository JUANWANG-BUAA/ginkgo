import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/apple_widgets.dart';
import 'package:ginkgo_mirror/ginkgo_visuals.dart';

void main() {
  testWidgets(
    'icon tile uses the selected alpha per brightness and keeps size',
    (tester) async {
      final semantics = tester.ensureSemantics();
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          CupertinoApp(
            theme: CupertinoThemeData(brightness: brightness),
            home: const Center(
              child: GinkgoIconTile(
                icon: CupertinoIcons.calendar,
                selected: true,
                semanticLabel: '课表',
              ),
            ),
          ),
        );
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(GinkgoIconTile),
            matching: find.byType(Container),
          ),
        );
        final decoration = container.decoration! as BoxDecoration;
        expect((decoration.borderRadius! as BorderRadius).topLeft.x, 12);
        expect(tester.getSize(find.byType(GinkgoIconTile)), const Size(44, 44));
        expect(find.byIcon(CupertinoIcons.calendar), findsOneWidget);
        final icon = tester.widget<Icon>(find.byIcon(CupertinoIcons.calendar));
        expect(icon.size, 22);
        final context = tester.element(find.byType(GinkgoIconTile));
        final resolved = CupertinoDynamicColor.resolve(
          decoration.color!,
          context,
        );
        expect(
          resolved.a,
          closeTo(brightness == Brightness.dark ? 0.28 : 0.16, 0.001),
        );
        expect(
          tester.getSemantics(find.byType(GinkgoIconTile)).label,
          contains('课表'),
        );
      }
      semantics.dispose();
    },
  );

  testWidgets('unselected icon tile is subtler than the selected one', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(child: GinkgoIconTile(icon: CupertinoIcons.calendar)),
      ),
    );
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(GinkgoIconTile),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    final context = tester.element(find.byType(GinkgoIconTile));
    expect(
      CupertinoDynamicColor.resolve(decoration.color!, context).a,
      closeTo(0.10, 0.001),
    );
    expect(tester.getSize(find.byType(GinkgoIconTile)), const Size(44, 44));
  });

  testWidgets('icon tile honors explicit size, icon size and tint', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: GinkgoIconTile(
            icon: CupertinoIcons.book,
            size: 34,
            iconSize: 18,
            color: CupertinoColors.systemOrange,
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(GinkgoIconTile)), const Size(34, 34));
    final icon = tester.widget<Icon>(find.byIcon(CupertinoIcons.book));
    expect(icon.size, 18);
    expect(
      icon.color,
      CupertinoDynamicColor.resolve(
        CupertinoColors.systemOrange,
        tester.element(find.byType(GinkgoIconTile)),
      ),
    );
  });

  testWidgets('badge keeps text and icon readable at large type', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Center(
            child: GinkgoBadge(label: '3 项', icon: CupertinoIcons.checkmark),
          ),
        ),
      ),
    );
    expect(find.text('3 项'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.checkmark), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('badge stays legible in narrow layouts and dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.dark),
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: Center(
            child: GinkgoBadge(
              label: '今日已读取全部课程',
              icon: CupertinoIcons.checkmark,
              compact: true,
            ),
          ),
        ),
      ),
    );
    expect(find.text('今日已读取全部课程'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Widget headerHost(Widget header) => CupertinoApp(
    theme: const CupertinoThemeData(primaryColor: Color(0xff189840)),
    home: CupertinoPageScaffold(
      child: MediaQuery(
        data: const MediaQueryData(size: Size(1000, 800)),
        child: CustomScrollView(
          slivers: [
            header,
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    ),
  );

  testWidgets('desktop page header prefers explicit identity values', (
    tester,
  ) async {
    await tester.pumpWidget(
      headerHost(
        const ApplePageHeader(
          largeTitle: Text('预约'),
          section: '空间资源',
          subtitle: '图书馆座位、研讨室与空闲教室的集中入口',
          icon: CupertinoIcons.square_stack_3d_up,
        ),
      ),
    );
    expect(find.text('空间资源'), findsOneWidget);
    expect(find.text('图书馆座位、研讨室与空闲教室的集中入口'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.square_stack_3d_up), findsOneWidget);
    expect(find.byType(GinkgoIconTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop page header falls back safely without explicit identity',
    (tester) async {
      await tester.pumpWidget(
        headerHost(const ApplePageHeader(largeTitle: Text('成绩'))),
      );
      expect(find.text('Ginkgo'), findsOneWidget);
      expect(find.text('学业'), findsNothing);
      expect(find.text('查看课程成绩、学分与加权统计'), findsNothing);
      expect(find.byType(GinkgoIconTile), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
