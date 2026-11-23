import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/auth_challenge.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';

/// Displays the login captcha image and its refresh control inside the form card.
class LoginChallengeRow extends StatelessWidget {
  const LoginChallengeRow({
    super.key,
    required this.challenge,
    required this.busy,
    required this.challengeBusy,
    required this.onRefresh,
  });

  final LoginChallenge? challenge;
  final bool busy;
  final bool challengeBusy;
  final void Function(String? expectedId) onRefresh;

  @override
  Widget build(BuildContext context) {
    final current = challenge;
    if (current == null || !current.textSupported) {
      return Padding(
        padding: GinkgoSpacing.edgeInsetsListTile,
        child: Row(
          children: [
            Expanded(
              child: Text(
                challengeBusy ? '正在读取验证码…' : '验证方式暂不可用，请刷新',
                style: GinkgoTypography.bodyCondensed.copyWith(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
            CupertinoButton(
              key: const Key('login-captcha-refresh'),
              padding: EdgeInsets.zero,
              onPressed: busy || challengeBusy
                  ? null
                  : () => onRefresh(challenge?.id),
              child: const Text('刷新'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: GinkgoSpacing.edgeInsetsListTile,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: '登录验证码图片，请输入图片中的字符',
              image: true,
              child: Image.memory(
                current.image,
                height: 72,
                alignment: Alignment.centerLeft,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Text(
                  '图片无法显示，请刷新',
                  style: GinkgoTypography.bodyCondensed.copyWith(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ),
          ),
          CupertinoButton(
            key: const Key('login-captcha-refresh'),
            padding: GinkgoSpacing.edgeInsetsPickerAction,
            onPressed: busy || challengeBusy
                ? null
                : () => onRefresh(current.id),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.refresh,
                  size: 18,
                  color: CupertinoTheme.of(context).primaryColor,
                ),
                const SizedBox(width: GinkgoSpacing.xs),
                Text(
                  challengeBusy ? '读取中' : '刷新',
                  style: GinkgoTypography.callout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LoginRememberRow extends StatelessWidget {
  const LoginRememberRow({
    super.key,
    required this.remember,
    required this.prefilledFromVault,
    required this.busy,
    required this.onChanged,
  });

  final bool remember;
  final bool prefilledFromVault;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: busy ? null : () => onChanged(!remember),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppleDesign.rowHeight),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '记住密码',
                  style: GinkgoTypography.callout.copyWith(
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                Text(
                  prefilledFromVault
                      ? '已从系统安全存储自动填充学号与密码'
                      : remember
                      ? '加密保存至系统安全存储，下次打开自动填充'
                      : '仅本次登录有效，退出应用后需重新输入',
                  style: GinkgoTypography.footnote.copyWith(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: remember,
            onChanged: busy ? null : onChanged,
          ),
        ],
      ),
    ),
  );
}
