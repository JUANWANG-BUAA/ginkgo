import 'dart:typed_data';

import '../application/auth_challenge.dart';
import '../src/rust/api/live/auth_challenge.dart' as live;

import 'package:ginkgo_mirror/infrastructure/native_command.dart';

class NativeAuthChallengeGateway implements AuthChallengeGateway {
  const NativeAuthChallengeGateway();

  @override
  Future<LoginChallenge> loginChallenge({
    String? expectedId,
    bool refresh = false,
  }) async {
    final response = await boundedNativeRead(
      () => live.loadLoginChallenge(expectedId: expectedId, refresh: refresh),
    );
    return decodeLoginChallenge(response);
  }
}

LoginChallenge decodeLoginChallenge(live.LoginChallengeResponse response) {
  final id = response.challengeId;
  final kind = response.challengeType;
  if (response.failure != null ||
      id == null ||
      id.isEmpty ||
      kind == null ||
      kind.isEmpty) {
    throw StateError('验证码已失效或暂时无法读取，请重新登录');
  }
  final image = response.image;
  if (response.textSupported &&
      (image.length > 1024 * 1024 || !_isDisplayableImage(image))) {
    throw StateError('验证码图片无效，请刷新后重试');
  }
  return LoginChallenge(
    id: id,
    kind: kind,
    textSupported: response.textSupported,
    image: image,
  );
}

/// The bytes go straight to the image widget; the school serves JPEG and PNG
/// from the same endpoint, so only the magic numbers are checked.
bool _isDisplayableImage(Uint8List bytes) {
  final jpeg =
      bytes.length >= 4 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff &&
      bytes[bytes.length - 2] == 0xff &&
      bytes.last == 0xd9;
  if (jpeg) return true;
  return bytes.length >= 16 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[bytes.length - 4] == 0xae &&
      bytes[bytes.length - 3] == 0x42 &&
      bytes[bytes.length - 2] == 0x60 &&
      bytes[bytes.length - 1] == 0x82;
}
