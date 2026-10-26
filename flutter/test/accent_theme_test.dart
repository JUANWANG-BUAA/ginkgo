import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/settings/accent_theme_preview.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/features/settings/preferences_pages.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return x > y ? (x + 0.05) / (y + 0.05) : (y + 0.05) / (x + 0.05);
}

void main() {
  testWidgets(
    'filled accent buttons retain AA contrast in every palette and theme',
    (tester) async {
      for (final brightness in Brightness.values) {
        for (final accent in AppAccent.values) {
          final prefs = AppPreferences(writer: (_) async {});
          await prefs.update(accent: accent);
          await tester.pumpWidget(
            ginkgoApp(
              preferences: prefs,
              brightness: brightness,
              home: CupertinoPageScaffold(
                child: Center(
                  child: CupertinoButton.filled(
                    onPressed: () {},
                    child: const Text('填色按钮'),
                  ),
                ),
              ),
            ),
          );
          final context = tester.element(find.text('填色按钮'));
          final background = CupertinoTheme.of(context).primaryColor;
          final foreground = DefaultTextStyle.of(context).style.color!;
          expect(
            contrast(foreground, background),
            greaterThanOrEqualTo(4.5),
            reason: '${accent.name} $brightness',
          );
          await tester.pumpWidget(const SizedBox.shrink());
          prefs.dispose();
        }
      }
    },
  );

  test(
    'old names remain stable; every palette round trips device display only',
    () async {
      expect(AppAccent.values.take(3).map((a) => a.name), [
        'green',
        'blue',
        'purple',
      ]);
      expect(AppAccent.values.length, lessThanOrEqualTo(8));
      for (final accent in AppAccent.values) {
        Map<String, Object>? saved;
        final prefs = AppPreferences(writer: (value) async => saved = value);
        await prefs.update(
          accent: accent,
          appearance: AppAppearance.dark,
          reduceMotion: true,
          compactLists: true,
          textSize: 1.3,
        );
        final restored = AppPreferences(
          reader: () async =>
              jsonDecode(jsonEncode(saved)) as Map<String, dynamic>,
        );
        await restored.restore();
        expect(restored.accent, accent);
        expect(restored.appearance, AppAppearance.dark);
        expect(restored.reduceMotion, isTrue);
        expect(restored.compactLists, isTrue);
        expect(restored.textSize, 1.3);
        expect(saved!.keys.toSet(), {
          'accent',
          'appearance',
          'reduceMotion',
          'compactLists',
          'textSize',
          // Safety marker, not a display setting: it stops a saved session
          // from auto-restoring after an explicit sign-out.
          'explicitSignOut',
        });
        prefs.dispose();
        restored.dispose();
      }
    },
  );

  test('legacy minimal and unknown palette preferences restore safely without writes', () async {
    for (final name in ['green', 'blue', 'purple', 'future-color', null]) {
      var writes = 0;
      final prefs = AppPreferences(
        reader: () async => {'accent': name},
        writer: (_) async {
          writes++;
        },
      );
      await prefs.restore();
      expect(
        prefs.accent.name,
        ['green', 'blue', 'purple'].contains(name) ? name : 'green',
      );
      expect(prefs.reduceMotion, isFalse);
      expect(prefs.textSize, 1);
      expect(writes, 0);
      prefs.dispose();
    }
  });

  test('new text accents meet AA on white and dark card surfaces', () {
    for (final accent in [
      AppAccent.teal,
      AppAccent.amber,
      AppAccent.coral,
      AppAccent.rose,
    ]) {
      final dynamic = accent.color as CupertinoDynamicColor;
      expect(
        contrast(dynamic.color, CupertinoColors.white),
        greaterThanOrEqualTo(4.5),
        reason: accent.name,
      );
      for (final surface in [
        const Color(0xff1c1c1e),
        const Color(0xff2c2c2e),
      ]) {
        expect(
          contrast(dynamic.darkColor, surface),
          greaterThanOrEqualTo(4.5),
          reason: accent.name,
        );
      }
      expect(dynamic.color, isNot(dynamic.darkColor));
    }
  });

  testWidgets(
    'selecting swatch immediately updates theme, preview and selected semantics before save',
    (tester) async {
      final blocker = Completer<void>();
      final writes = <Map<String, Object>>[];
      final prefs = AppPreferences(
        writer: (value) async {
          writes.add(value);
          await blocker.future;
        },
      );
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ginkgoApp(preferences: prefs, home: const AppearancePage()),
      );
      final choice = find.byKey(const ValueKey('accent-coral'));
      await tester.ensureVisible(choice);
      await tester.pumpAndSettle();
      await tester.tap(choice);
      await tester.pump();
      expect(prefs.accent, AppAccent.coral);
      expect(
        tester
            .widget<AccentCoursePreview>(find.byType(AccentCoursePreview))
            .accent,
        AppAccent.coral,
      );
      expect(
        tester.getSemantics(choice),
        matchesSemantics(
          label: '珊瑚橙',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      final context = tester.element(choice);
      expect(
        CupertinoTheme.of(context).primaryColor,
        CupertinoDynamicColor.resolve(AppAccent.coral.color, context),
      );
      expect(writes.single['accent'], 'coral');
      blocker.complete();
      await tester.pumpAndSettle();
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
      prefs.dispose();
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      '320dp large type ${brightness.name}: choices, preview and reduce motion stay accessible',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final prefs = AppPreferences(writer: (_) async {});
        await prefs.update(textSize: 1.3, reduceMotion: true);
        await tester.pumpWidget(
          ginkgoApp(
            preferences: prefs,
            brightness: brightness,
            home: const AppearancePage(),
          ),
        );
        await tester.pumpAndSettle();
        for (final accent in AppAccent.values) {
          final choice = find.byKey(ValueKey('accent-${accent.name}'));
          await tester.ensureVisible(choice);
          await tester.pumpAndSettle();
          expect(tester.getSize(choice).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(choice).width, greaterThanOrEqualTo(48));
          await tester.tap(choice);
          await tester.pumpAndSettle();
          expect(prefs.accent, accent);
          expect(tester.takeException(), isNull);
        }
        final button = find.byKey(const ValueKey('accent-preview-button'));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        final context = tester.element(button);
        expect(MediaQuery.disableAnimationsOf(context), isTrue);
        expect(MediaQuery.textScalerOf(context).scale(10), 26);
        expect(tester.widget<CupertinoButton>(button).pressedOpacity, 1);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('刚刚好，今天也从容出发。'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('减少动态效果'), 300);
        await tester.pumpAndSettle();
        expect(find.text('系统已开启时始终生效'), findsOneWidget);
        expect(prefs.reduceMotion, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        prefs.dispose();
      },
    );
  }

  testWidgets(
    'system reduce motion remains effective with device preference off',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final prefs = AppPreferences(writer: (_) async {});
      await tester.pumpWidget(
        ginkgoApp(
          preferences: prefs,
          home: const CupertinoPageScaffold(
            child: SingleChildScrollView(child: AccentThemePicker()),
          ),
        ),
      );
      final button = find.byKey(const ValueKey('accent-preview-button'));
      expect(prefs.reduceMotion, isFalse);
      expect(MediaQuery.disableAnimationsOf(tester.element(button)), isTrue);
      expect(tester.widget<CupertinoButton>(button).pressedOpacity, 1);
      await tester.pumpWidget(const SizedBox());
      prefs.dispose();
    },
  );
}
