import 'dart:async';

import 'package:ginkgo_mirror/application/contracts.dart' show FailureCode;

/// Local pacing after explicit password rejection; network/captcha errors do
/// not count. This never schedules or repeats an authentication request.
class LoginRetryPause {
  LoginRetryPause(this.onTick);
  final void Function() onTick;
  int rejected = 0;
  int remaining = 0;
  Timer? _ticker;
  String get message =>
      remaining > 0 ? '登录被拒绝次数较多，请等待 $remaining 秒后再试' : '可再次登录，请核对账号和密码';

  bool record(FailureCode? failure) {
    if (failure != FailureCode.invalidCredentials) return false;
    rejected++;
    if (rejected < 3) return false;
    remaining = switch (rejected) {
      3 => 60,
      4 => 120,
      _ => 300,
    };
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      if (remaining == 0) timer.cancel();
      onTick();
    });
    return true;
  }

  void dispose() => _ticker?.cancel();
}
