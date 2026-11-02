import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/tokens/typography.dart';
import 'package:ginkgo_mirror/design/tokens/spacing.dart';
import 'package:ginkgo_mirror/design/tokens/layout.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';

class LoginFeedback extends StatelessWidget {
  const LoginFeedback({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(top: 10, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 18,
            color: CupertinoColors.systemRed.resolveFrom(context),
          ),
          const SizedBox(width: GinkgoSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: GinkgoTypography.footnote.copyWith(
                color: CupertinoColors.systemRed.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class LoginNetworkNote extends StatelessWidget {
  const LoginNetworkNote({super.key});
  @override
  Widget build(BuildContext context) => Text(
    'WebVPN 网关可能需要再次认证。不保存也可登录；本次登录凭据仅在内存中用于恢复，'
    '应用重启后可能需要重新登录。验证码不会保存。',
    textAlign: TextAlign.center,
    style: GinkgoTypography.footnote.copyWith(
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    ),
  );
}

class LoginPreferencesRecovery extends StatelessWidget {
  const LoginPreferencesRecovery({super.key, required this.onRetry});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    minimumSize: const Size.fromHeight(GinkgoLayout.rowHeight),
    onPressed: onRetry,
    child: const Text('重新读取本机设置'),
  );
}

class LoginPreferencesSaveFailure extends StatelessWidget {
  const LoginPreferencesSaveFailure({super.key, required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final preferences = AppPreferencesScope.of(context);
    final message = preferences.writeError;
    if (message == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LoginFeedback(message: message),
        CupertinoButton(
          minimumSize: const Size.fromHeight(GinkgoLayout.rowHeight),
          onPressed: enabled ? preferences.retrySave : null,
          child: const Text('重试保存设置'),
        ),
      ],
    );
  }
}
