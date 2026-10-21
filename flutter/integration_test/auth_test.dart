import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' as live;
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());

  testWidgets('platform credential vault round-trips a synthetic secret', (
    tester,
  ) async {
    expect(
      await live.verifyCredentialStorage(
        account: '__ginkgo_vault_test__account',
        secret: 'fixture-secret-1',
      ),
      isTrue,
    );
    // A second round-trip proves the first entry was removed and the same
    // Keystore key/SharedPreferences path can be reused.
    expect(
      await live.verifyCredentialStorage(
        account: '__ginkgo_vault_test__account',
        secret: 'fixture-secret-2',
      ),
      isTrue,
    );
  });

  testWidgets('live app starts at the login page when no account is saved', (
    tester,
  ) async {
    await tester.pumpWidget(const GinkgoRoot());
    for (var i = 0; i < 30 && find.text('统一身份认证').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('统一身份认证'), findsOneWidget);
    expect(find.text('先看看离线演示'), findsOneWidget);
    expect(find.byKey(const Key('login-account')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
