import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/apple_widgets.dart';
import 'package:ginkgo_mirror/main.dart';

void main() {
  testWidgets(
    'group grows after delayed response without navigation or new input',
    (tester) async {
      final response = Completer<void>();
      await tester.pumpWidget(
        ginkgoApp(
          home: CupertinoPageScaffold(
            child: FutureBuilder<void>(
              future: response.future,
              builder: (context, state) => CustomScrollView(
                slivers: [
                  SliverList.list(
                    children: [
                      AppleSection(
                        children: state.connectionState == ConnectionState.done
                            ? List.generate(
                                15,
                                (i) => AppleListTile(title: Text('合成结果 $i')),
                              )
                            : const [AppleListTile(title: Text('正在加载'))],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      response.complete();
      await tester.pump();
      await tester.pumpAndSettle();
      final first = tester.renderObject<RenderBox>(find.text('合成结果 0'));
      expect(first.size.height, greaterThan(0));
      expect(find.text('合成结果 0').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('offstage response renders fully when tab becomes visible', (
    tester,
  ) async {
    final response = Completer<void>();
    final controller = CupertinoTabController();
    await tester.pumpWidget(
      ginkgoApp(
        home: CupertinoTabScaffold(
          controller: controller,
          tabBar: CupertinoTabBar(
            items: const [
              BottomNavigationBarItem(icon: Icon(CupertinoIcons.home)),
              BottomNavigationBarItem(icon: Icon(CupertinoIcons.book)),
            ],
          ),
          tabBuilder: (_, tab) => tab == 1
              ? const Center(child: Text('另一页'))
              : FutureBuilder<void>(
                  future: response.future,
                  builder: (context, state) => CustomScrollView(
                    slivers: [
                      SliverList.list(
                        children: [
                          AppleSection(
                            children:
                                state.connectionState == ConnectionState.done
                                ? List.generate(
                                    8,
                                    (i) =>
                                        AppleListTile(title: Text('后台结果 $i')),
                                  )
                                : const [AppleListTile(title: Text('加载中'))],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.index = 1;
    await tester.pumpAndSettle();
    response.complete();
    await tester.pump();
    controller.index = 0;
    await tester.pumpAndSettle();
    expect(find.text('后台结果 5').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });
}
