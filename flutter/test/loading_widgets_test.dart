import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/apple_design.dart';
import 'package:ginkgo_mirror/loading_widgets.dart';

class _RecordingCanvas implements Canvas {
  final List<Color> colors = [];

  @override
  void save() {}

  @override
  void restore() {}

  @override
  void scale(double sx, [double? sy]) {}

  @override
  void drawPath(Path path, Paint paint) {
    colors.add(paint.color);
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    colors.add(paint.color);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'full-page loading keeps a stable semantic label and no spinner',
    (tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: GinkgoLoadingView(label: '正在读取课表…', detail: '保留上次结果'),
        ),
      );
      expect(find.text('正在读取课表…'), findsOneWidget);
      expect(find.text('保留上次结果'), findsOneWidget);
      expect(find.byType(GinkgoActivity), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      final activity = tester.widget<GinkgoActivity>(
        find.byType(GinkgoActivity),
      );
      expect(activity.size, 36);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact loading shrinks the leaf without losing its label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: GinkgoLoadingView(label: '正在核对…', compact: true),
      ),
    );
    final activity = tester.widget<GinkgoActivity>(find.byType(GinkgoActivity));
    expect(activity.size, 24);
    expect(find.text('正在核对…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading view exposes one live-region label', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const CupertinoApp(
        home: GinkgoLoadingView(label: '正在读取课表…', detail: '保留上次结果'),
      ),
    );
    final node = tester.getSemantics(find.byType(GinkgoLoadingView));
    expect(node.label, contains('正在读取课表…'));
    expect(node.label, contains('保留上次结果'));
    semantics.dispose();
  });

  testWidgets('reduced motion leaves the leaf static and schedules no frames', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: GinkgoLoadingView(label: '正在读取…'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('正在读取…'), findsOneWidget);
  });

  testWidgets(
    'an inactive ticker leaves the leaf static and schedules no frames',
    (tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: TickerMode(
            enabled: false,
            child: GinkgoLoadingView(label: '正在读取…'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.text('正在读取…'), findsOneWidget);
    },
  );

  testWidgets(
    'brand leaf keeps the ginkgo accent independent of theme accent',
    (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          theme: const CupertinoThemeData(
            primaryColor: CupertinoColors.systemBlue,
          ),
          home: const Center(child: GinkgoActivity()),
        ),
      );
      final customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(GinkgoActivity),
          matching: find.byType(CustomPaint),
        ),
      );
      final canvas = _RecordingCanvas();
      customPaint.painter!.paint(canvas, const Size.square(22));
      expect(canvas.colors, isNotEmpty);
      final context = tester.element(find.byType(GinkgoActivity));
      final expected = CupertinoDynamicColor.resolve(
        AppleDesign.accent,
        context,
      );
      for (final color in canvas.colors) {
        expect(color.r, closeTo(expected.r, 0.001));
        expect(color.g, closeTo(expected.g, 0.001));
        expect(color.b, closeTo(expected.b, 0.001));
      }
      expect(
        canvas.colors.map((color) => color.a).reduce((a, b) => a > b ? a : b),
        closeTo(1, 0.001),
      );
    },
  );

  testWidgets('brand leaf is static when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(child: GinkgoActivity(size: 20)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
