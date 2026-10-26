import 'dart:typed_data';

/// In-memory authentication UI values; never a URL or a persistence payload.
class LoginChallenge {
  LoginChallenge({
    required this.id,
    required this.kind,
    required this.textSupported,
    required List<int> image,
  }) : image = Uint8List.fromList(image).asUnmodifiableView();
  final String id;
  final String kind;
  final bool textSupported;
  final Uint8List image;
}

abstract interface class AuthChallengeGateway {
  /// Read the current pending challenge, or explicitly replace its login page.
  /// expectedId prevents an old page refreshing a different login challenge.
  Future<LoginChallenge> loginChallenge({
    String? expectedId,
    bool refresh = false,
  });
}
