import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/infrastructure/display_preferences_file_store.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';

void main() {
  test('legacy display-only preferences keep default route and signout compatibility', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ginkgo-legacy-preferences-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/display-preferences-v1.json');
    const original = '{"appearance":"dark"}';
    await file.writeAsString(original);
    final store = DisplayPreferencesFileStore(
      supportDirectory: () async => directory,
    );
    final preferences = AppPreferences(reader: store.read, writer: store.write);
    addTearDown(preferences.dispose);
    await preferences.restore();
    expect(preferences.saveError, isNull);
    expect(preferences.appearance, AppAppearance.dark);
    expect(preferences.routeMode, 'automatic');
    expect(preferences.explicitSignOut, false);
    expect(await file.readAsString(), original);
  });
  test(
    'display preferences persist through the injected file adapter',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ginkgo-display-preferences-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = DisplayPreferencesFileStore(
        supportDirectory: () async => directory,
      );

      expect(await store.read(), isNull);

      final preferences = AppPreferences(
        reader: store.read,
        writer: store.write,
      );
      await preferences.restore();
      await preferences.update(
        appearance: AppAppearance.dark,
        accent: AppAccent.teal,
        compactLists: true,
        reduceMotion: true,
        textSize: 1.3,
      );
      await preferences.setExplicitSignOut(true);

      final restored = AppPreferences(reader: store.read, writer: store.write);
      await restored.restore();
      expect(restored.appearance, AppAppearance.dark);
      expect(restored.accent, AppAccent.teal);
      expect(restored.compactLists, isTrue);
      expect(restored.reduceMotion, isTrue);
      expect(restored.textSize, 1.3);
      expect(restored.explicitSignOut, isTrue);
      expect(
        await File('${directory.path}/display-preferences-v1.json.tmp')
            .exists(),
        isFalse,
      );

      preferences.dispose();
      restored.dispose();
    },
  );
}
