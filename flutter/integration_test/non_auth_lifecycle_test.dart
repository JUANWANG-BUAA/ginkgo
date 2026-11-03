import 'package:integration_test/integration_test.dart';

import '../test/non_auth_lifecycle_regression_test.dart' as regression;

// Synthetic ports only: no school login, network, vault or stored account data.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  regression.main();
}
