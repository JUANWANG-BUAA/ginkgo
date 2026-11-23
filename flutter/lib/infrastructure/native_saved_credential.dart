import 'package:ginkgo_mirror/application/saved_credential.dart';
import 'package:ginkgo_mirror/infrastructure/native_command.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' as live;

mixin NativeSavedCredential implements SavedCredentialGateway {
  @override
  Future<SavedCredential?> savedCredential() async {
    final result = await boundedNativeRead(live.loadSavedCredential);
    final account = result.account?.trim();
    final password = result.password;
    if (result.failure != null ||
        account == null ||
        account.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }
    return SavedCredential(account: account, password: password);
  }
}
