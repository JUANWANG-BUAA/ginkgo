import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot:
        (String name, List<int> bytes, [Map<String, Object?>? args]) async {
          final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
          final file = File('build/visual/$safeName.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes);
          // This validates capture integrity, not visual similarity to Apple.
          return bytes.length > 8 && bytes[0] == 137 && bytes[1] == 80;
        },
    writeResponseOnFailure: true,
  );
}
