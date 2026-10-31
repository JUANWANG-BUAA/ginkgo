import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/infrastructure/display_preferences_file_store.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';

void main() {
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
