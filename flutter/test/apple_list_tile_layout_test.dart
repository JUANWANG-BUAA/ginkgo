import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

void main() {
  testWidgets(
    'ordinary tile retains inline metadata and independent trailing action',
    (tester) async {
      tester.view.physicalSize = const Size(430, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var rows = 0, actions = 0;
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: AppleListTile(
              title: const Text('详情'),
              subtitle: const Text('说明', key: Key('subtitle')),
              additionalInfo: const Text('核对', key: Key('metadata')),
              onTap: () => rows++,
              trailing: CupertinoButton(
                onPressed: () => actions++,
                child: const Text('操作'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const Key('metadata'))).top,
        lessThan(tester.getRect(find.byKey(const Key('subtitle'))).bottom),
      );
      await tester.tap(find.text('操作'));
      expect(actions, 1);
      expect(rows, 0);
      await tester.tap(find.text('详情'));
      expect(rows, 1);
      expect(tester.takeException(), isNull);
    },
  );
  for (final (width, scale) in [(320.0, 1.0), (430.0, 2.0), (800.0, 3.2)]) {
    testWidgets(
      'tile metadata stays below subtitle at $width dp and $scale text',
      (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          CupertinoApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 1200),
                textScaler: TextScaler.linear(scale),
              ),
              child: const CupertinoPageScaffold(
                child: SingleChildScrollView(
                  child: AppleSection(
                    children: [
                      AppleListTile(
                        title: Text('今天 2 节课'),
                        subtitle: Text('已签到 1 · 未签到 1', key: Key('subtitle')),
                        additionalInfo: Text('核对 未确认', key: Key('metadata')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final subtitle = tester.getRect(find.byKey(const Key('subtitle')));
        final metadata = tester.getRect(find.byKey(const Key('metadata')));
        final tile = tester.getRect(find.byType(AppleListTile));
        expect(metadata.top, greaterThanOrEqualTo(subtitle.bottom));
        expect(metadata.left, greaterThanOrEqualTo(tile.left));
        expect(metadata.right, lessThanOrEqualTo(tile.right));
        expect(metadata.bottom, lessThanOrEqualTo(tile.bottom));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
