import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/infrastructure/native_auth_challenge.dart';
import 'package:ginkgo_mirror/src/rust/api/live/auth_challenge.dart';

void main() {
  test('challenge decoder copies bytes and never needs a URL', () {
    final bytes = Uint8List.fromList([255, 216, 255, 224, 255, 217]);
    final challenge = decodeLoginChallenge(
      LoginChallengeResponse(
        challengeId: 'synthetic',
        challengeType: 'local',
        textSupported: true,
        image: bytes,
      ),
    );
    bytes[0] = 0;
    expect(challenge.image.first, 255);
    expect(() => challenge.image[0] = 0, throwsUnsupportedError);
  });
  test('unknown challenge remains unsupported, not a text form', () {
    final challenge = decodeLoginChallenge(
      LoginChallengeResponse(
        challengeId: 'synthetic',
        challengeType: 'slider',
        textSupported: false,
        image: Uint8List(0),
      ),
    );
    expect(challenge.textSupported, isFalse);
  });
  test('a PNG challenge is answerable, not an invalid image', () {
    final png = Uint8List.fromList([
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, //
      0x49, 0x48, 0x44, 0x52, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
    ]);
    final challenge = decodeLoginChallenge(
      LoginChallengeResponse(
        challengeId: 'synthetic',
        challengeType: 'char',
        textSupported: true,
        image: png,
      ),
    );
    expect(challenge.textSupported, isTrue);
    expect(challenge.image.length, png.length);
  });

  test('malformed bytes cannot become usable challenge', () {
    expect(
      () => decodeLoginChallenge(
        LoginChallengeResponse(
          challengeId: 'synthetic',
          challengeType: 'local',
          textSupported: true,
          image: Uint8List.fromList([60, 104, 116, 109, 108, 62]),
        ),
      ),
      throwsStateError,
    );
    expect(
      () => decodeLoginChallenge(
        LoginChallengeResponse(textSupported: false, image: Uint8List(0)),
      ),
      throwsStateError,
    );
  });
}
