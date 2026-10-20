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
      child: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 36, 20, 28),
          children: [
            const Icon(
              CupertinoIcons.leaf_arrow_circlepath,
              size: 56,
              color: AppleDesign.accent,
            ),
            const SizedBox(height: 18),
            const Text(
              'Ginkgo 银杏',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '北航校园服务 · Android 与 Windows 镜像',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 28),
            AppleSection(
              header: const Text('统一身份认证'),
              footer: const Text('密码只交给本地 Rust 会话并写入系统安全存储，页面不记录密码。'),
              children: [
                _field(
                  key: const Key('login-account'),
                  controller: account,
                  placeholder: '学号',
                  label: '学号',
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
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
                AppleListTile(
                  title: const Text('记住密码'),
                  subtitle: const Text('交给 Android Keystore / 系统钥匙串保存'),
                  additionalInfo: CupertinoSwitch(
                    value: remember,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => remember = value),
                  ),
                ),
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CupertinoColors.systemRed,
                    fontSize: 14,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            CupertinoButton.filled(
              key: const Key('login-submit'),
              onPressed: busy ? null : submit,
              child: busy
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    )
                  : const Text('登录'),
            ),
            const SizedBox(height: 10),
            CupertinoButton(
              onPressed: busy ? null : widget.onDemo,
              child: const Text('先看看离线演示'),
            ),
          ],
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
      obscureText: obscure,
      enableSuggestions: !obscure,
      autocorrect: false,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(),
    ),
  );
}
