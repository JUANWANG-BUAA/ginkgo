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
      (image.length < 4 ||
          image.length > 1024 * 1024 ||
          image[0] != 255 ||
          image[1] != 216 ||
          image[2] != 255 ||
          image[image.length - 2] != 255 ||
          image.last != 217)) {
    throw StateError('验证码图片无效，请刷新后重试');
  }
  return LoginChallenge(
    id: id,
    kind: kind,
    textSupported: response.textSupported,
    image: image,
  );
}
