import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/widgets/apple_controls.dart';

void main() {
  testWidgets('short choices use the native action sheet', (tester) async {
    var selected = '甲';
    await tester.pumpWidget(
      CupertinoApp(
        home: StatefulBuilder(
          builder: (context, setState) => CupertinoPageScaffold(
            child: ApplePickerTile<String>(
              title: '校区',
              value: selected,
              values: const ['甲', '乙', '丙', '丁', '戊', '己', '庚'],
              label: (value) => value,
              onSelected: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('校区'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(find.byType(CupertinoPicker), findsNothing);
    await tester.tap(find.text('乙'));
    await tester.pumpAndSettle();
    expect(selected, '乙');
  });

  testWidgets('long discrete choices remain a scrollable system sheet', (
    tester,
  ) async {
    final values = List.generate(12, (index) => '类别 $index');
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: ApplePickerTile<String>(
            title: '选择类别',
            value: values.first,
            values: values,
            label: (value) => value,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('选择类别'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(find.byType(CupertinoPicker), findsNothing);
    expect(find.text('类别 11'), findsOneWidget);
  });

  testWidgets('long ordered choices opt into the native picker wheel', (
    tester,
  ) async {
    final values = List.generate(12, (index) => '第 $index 项');
    var selected = values.first;
    await tester.pumpWidget(
      CupertinoApp(
        home: StatefulBuilder(
          builder: (context, setState) => CupertinoPageScaffold(
            child: ApplePickerTile<String>(
              title: '选择周次',
              value: selected,
              values: values,
              label: (value) => value,
              onSelected: (value) => setState(() => selected = value),
              useWheel: true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('选择周次'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPicker), findsOneWidget);
    expect(find.byType(CupertinoActionSheet), findsNothing);
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, -44 * 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(selected, '第 3 项');
  });

  testWidgets('toolbar action exposes one labeled 48 point button target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: AppleToolbarButton(
            label: '刷新校历',
            onPressed: _noop,
            child: Icon(CupertinoIcons.refresh),
          ),
        ),
      ),
    );

    final target = tester.getSize(find.byType(AppleToolbarButton));
    expect(target.width, greaterThanOrEqualTo(48));
    expect(target.height, greaterThanOrEqualTo(48));
    final data = tester
        .getSemantics(find.byType(AppleToolbarButton))
        .getSemanticsData();
    expect(data.label, '刷新校历');
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.flagsCollection.isButton, isTrue);
    semantics.dispose();
  });
}

void _noop() {}
