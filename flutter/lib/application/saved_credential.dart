/// Remembered account and password read back from the platform secure vault.
///
/// Only populated when the user previously opted into "记住密码" and has not
/// explicitly signed out. Never persisted to plaintext files or logs.
class SavedCredential {
  const SavedCredential({required this.account, required this.password});

  final String account;
  final String password;
}

abstract interface class SavedCredentialGateway {
  Future<SavedCredential?> savedCredential();
}
