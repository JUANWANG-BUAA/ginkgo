import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/widgets/mutation_dialog.dart';

class PopCounter extends NavigatorObserver {
  int pops = 0;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops++;
  }
}

void main() {
  testWidgets('repeated confirmation only closes its own dialog', (
    tester,
  ) async {
    final observer = PopCounter();
    await tester.pumpWidget(
      CupertinoApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) => CupertinoButton(
            child: const Text('打开详情'),
            onPressed: () {
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (context) => CupertinoPageScaffold(
                    child: CupertinoButton(
                      child: const Text('执行操作'),
                      onPressed: () {
                        confirmMutation(
                          context,
                          title: '确认？',
                          detail: '合成操作',
                          action: '确定',
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开详情'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('执行操作'));
    await tester.pumpAndSettle();
    final callback = tester
        .widget<CupertinoDialogAction>(
          find.widgetWithText(CupertinoDialogAction, '确定'),
        )
        .onPressed!;
    callback();
    callback();
    await tester.pumpAndSettle();
    expect(observer.pops, 1);
    expect(find.text('执行操作'), findsOneWidget);
  });
}
