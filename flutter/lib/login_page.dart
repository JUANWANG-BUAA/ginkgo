import 'package:flutter/cupertino.dart';

import 'apple_design.dart';
import 'apple_widgets.dart';
import 'mirror_service.dart';
import 'src/rust/api/live.dart' show SessionResponse, SessionState;

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.service,
    required this.onSignedIn,
    required this.onDemo,
    this.initialMessage,
    this.initialCaptcha = false,
  });

  final MirrorService service;
  final ValueChanged<SessionResponse> onSignedIn;
  final VoidCallback onDemo;
  final String? initialMessage;
  final bool initialCaptcha;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final account = TextEditingController();
  final password = TextEditingController();
  final captcha = TextEditingController();
  bool remember = true;
  bool busy = false;
  bool showPassword = false;
  late bool needCaptcha = widget.initialCaptcha;
  String? error;

  @override
  void initState() {
    super.initState();
    error = widget.initialMessage;
  }

  @override
  void dispose() {
    account.dispose();
    password.dispose();
    captcha.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    final studentId = account.text.trim();
    if (studentId.isEmpty || password.text.isEmpty) {
      setState(() => error = '请输入学号和密码');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await widget.service.login(
        account: studentId,
        password: password.text,
        captcha: captcha.text.trim().isEmpty ? null : captcha.text.trim(),
        remember: remember,
      );
      if (!mounted) return;
      if (response.state == SessionState.signedIn) {
        widget.onSignedIn(response);
        return;
      }
      setState(() {
        busy = false;
        needCaptcha = response.state == SessionState.captchaRequired;
        error = needCaptcha
            ? '学校本次登录要求验证码。验证码图片展示尚未接入，请稍后重试。'
            : response.failure == null
            ? '登录未完成，请重试'
            : failureMessage(response.failure);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = failureMessage(null);
      });
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: constraints.maxHeight > 650 ? 48 : 8),
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: AppleDesign.accent.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          CupertinoIcons.leaf_arrow_circlepath,
                          size: 46,
                          color: AppleDesign.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Ginkgo 银杏',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '让校园生活井然有序',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                    const SizedBox(height: 44),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        '统一身份认证',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                    ),
                    ClipRSuperellipse(
                      borderRadius: BorderRadius.circular(18),
                      child: ColoredBox(
                        key: const Key('login-fields'),
                        color: CupertinoColors.secondarySystemGroupedBackground
                            .resolveFrom(context),
                        child: Column(
                          children: [
                            _field(
                              key: const Key('login-account'),
                              controller: account,
                              placeholder: '学号',
                              label: '学号',
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                            ),
                            Container(
                              height: .5,
                              margin: const EdgeInsets.only(left: 48),
                              color: CupertinoColors.separator.resolveFrom(
                                context,
                              ),
                            ),
                            _field(
                              key: const Key('login-password'),
                              controller: password,
                              placeholder: '密码',
                              label: '密码',
                              obscure: true,
                              textInputAction: needCaptcha
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) => submit(),
                            ),
                            if (needCaptcha)
                              _field(
                                key: const Key('login-captcha'),
                                controller: captcha,
                                placeholder: '验证码',
                                label: '验证码',
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => submit(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('记住密码', style: TextStyle(fontSize: 15)),
                        ),
                        CupertinoSwitch(
                          value: remember,
                          onChanged: busy
                              ? null
                              : (value) => setState(() => remember = value),
                        ),
                      ],
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            error!,
                            style: const TextStyle(
                              color: CupertinoColors.systemRed,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    CupertinoButton.filled(
                      key: const Key('login-submit'),
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      onPressed: busy ? null : submit,
                      child: busy
                          ? const CupertinoActivityIndicator(
                              color: CupertinoColors.white,
                            )
                          : const Text(
                              '登录',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '记住的密码保存在本机，退出登录时删除',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoButton(
                      onPressed: busy ? null : widget.onDemo,
                      child: const Text('先看看离线演示'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String placeholder,
    required String label,
    bool obscure = false,
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
    ValueChanged<String>? onSubmitted,
  }) => Semantics(
    textField: true,
    label: label,
    child: CupertinoTextField(
      key: key,
      controller: controller,
      placeholder: placeholder,
      enabled: !busy,
      obscureText: obscure && !showPassword,
      prefix: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Icon(
          obscure ? CupertinoIcons.lock : CupertinoIcons.person,
          size: 20,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
      suffix: !obscure
          ? null
          : CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              onPressed: busy
                  ? null
                  : () => setState(() => showPassword = !showPassword),
              child: Icon(
                showPassword ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                size: 20,
                semanticLabel: showPassword ? '隐藏密码' : '显示密码',
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
      enableSuggestions: !obscure,
      autocorrect: false,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: const BoxDecoration(),
    ),
  );
}
