import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/failure_message.dart';

void main() {
  group('every failure code maps to its own actionable sentence', () {
    test('all codes produce a non-empty, mutually distinct message', () {
      final messages = <String, String>{};
      for (final code in FailureCode.values) {
        final message = failureMessage(code);
        expect(message, isNotEmpty, reason: '$code must say something');
        expect(
          messages.containsKey(message),
          isFalse,
          reason: '$code reuses the sentence already used by '
              '${messages[message]}: "$message"',
        );
        messages[message] = code.name;
      }
      // A null code is the local-service fallback, which must also exist.
      expect(failureMessage(null), isNotEmpty);
    });

    test('the fallback differs from every typed code', () {
      final fallback = failureMessage(null);
      for (final code in FailureCode.values) {
        expect(failureMessage(code), isNot(fallback));
      }
    });
  });

  group('business rejection is never presented as an ended session', () {
    test('the message explicitly denies that the account signed out', () {
      final message = failureMessage(FailureCode.businessRejected);
      expect(message, contains('不代表账号已退出'));
      // Being rejected by the business system is not an authentication event:
      // an operator reading this must not go looking for a re-login.
      expect(message, isNot(contains('重新登录')));
      expect(message, isNot(contains('会话已失效')));
    });

    test('sign-out wording is reserved for the session-expired code', () {
      final withSignIn = FailureCode.values
          .where((code) => failureMessage(code).contains('重新登录'))
          .toSet();
      expect(withSignIn, {FailureCode.sessionExpired, FailureCode.captchaRequired});
    });
  });

  group('messages stay free of upstream protocol vocabulary', () {
    test('no raw status words leak into user-facing copy', () {
      for (final code in FailureCode.values) {
        final message = failureMessage(code);
        for (final leak in ['accepted', 'rejected', 'notSubmitted', 'uncertain']) {
          expect(
            message.contains(leak),
            isFalse,
            reason: '$code leaks the wire state "$leak"',
          );
        }
      }
    });
  });
}
