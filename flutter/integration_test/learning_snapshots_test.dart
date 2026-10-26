// Synthetic-only on an isolated QA device. No school session or credentials.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cn.edu.buaa.ginkgo/learning-snapshots');
  testWidgets('Android opt-in Keystore snapshot binary roundtrip and erase', (
    tester,
  ) async {
    await channel.invokeMethod<void>('clear');
    expect(await channel.invokeMethod<bool>('enabled'), isFalse);
    await expectLater(
      channel.invokeMethod<Uint8List>('load'),
      throwsA(isA<PlatformException>()),
    );
    await channel.invokeMethod<void>('enable');
    try {
      final synthetic = Uint8List.fromList([0, 255, 13, 10, 42]);
      await channel.invokeMethod<void>('save', synthetic);
      expect(await channel.invokeMethod<Uint8List>('load'), synthetic);
      expect(await channel.invokeMethod<bool>('enabled'), isTrue);
    } finally {
      await channel.invokeMethod<void>('clear');
    }
    expect(await channel.invokeMethod<bool>('enabled'), isFalse);
  });
}
