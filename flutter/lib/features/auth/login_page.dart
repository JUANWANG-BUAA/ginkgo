import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/application/contracts.dart' show SessionResponse, SessionState;
import 'package:ginkgo_mirror/application/auth_challenge.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.service,
    required this.onSignedIn,
    required this.onDemo,
    this.initialMessage,
    this.initialCaptcha = false,
    this.challengeGateway,
  });

  final MirrorService service;
  final ValueChanged<SessionResponse> onSignedIn;
  final VoidCallback onDemo;
  final String? initialMessage;
  final bool initialCaptcha;
  final AuthChallengeGateway? challengeGateway;

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
  LoginChallenge? challenge;
  bool challengeBusy = false;
  int challengeEpoch = 0;

  Future<void> loadChallenge({String? expectedId, bool refresh = false}) async {
    final gateway = widget.challengeGateway;
    final epoch = ++challengeEpoch;
    captcha.clear();
    setState(() {
      challengeBusy = true;
      challenge = null;
    });
    try {
      if (gateway == null) throw StateError('unsupported');
      final result = await gateway.loginChallenge(
        expectedId: expectedId,
        refresh: refresh,
      );
      if (!mounted || epoch != challengeEpoch) return;
      setState(() {
        challenge = result;
        challengeBusy = false;
        error = result.textSupported
            ? '请输入图片中的验证码后继续'
            : '学校要求的验证方式暂不支持，请前往学校统一认证完成验证后重新登录';
      });
    } catch (_) {
      if (!mounted || epoch != challengeEpoch) return;
      setState(() {
        challengeBusy = false;
        error = '验证码读取失败或已失效，请重新登录获取验证';
        needCaptcha = false;
      });
    }
  }

  void credentialsChanged() {
    if (busy || challengeBusy) return;
    if (needCaptcha || challenge != null || captcha.text.isNotEmpty) {
      challengeEpoch++;
      captcha.clear();
      setState(() {
        needCaptcha = false;
        challenge = null;
        error = null;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    error = widget.initialMessage;
    account.addListener(credentialsChanged);
    password.addListener(credentialsChanged);
    if (needCaptcha) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) loadChallenge();
      });
    }
  }

  @override
  void dispose() {
    account.dispose();
    password.dispose();
    captcha.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || challengeBusy) return;
    if (needCaptcha &&
        (challenge?.textSupported != true || captcha.text.trim().isEmpty)) {
      setState(
        () => error = challenge?.textSupported == true
            ? '请输入验证码'
            : '当前验证方式尚未就绪或不支持，请刷新验证或重新登录',
      );
      return;
    }
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
        if (remember && !response.remembered) {
          setState(() => busy = false);
          await showCupertinoDialog<void>(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('已登录，密码未保存'),
              content: const Text(
                '系统安全存储未能保存密码。仍可继续使用，下次启动需要重新登录；部分校外服务可能需要再次认证。',
              ),
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.pop(context),
                  child: const Text('继续使用'),
                ),
              ],
            ),
          );
          if (!mounted) return;
        }
        captcha.clear();
        challengeEpoch++;
        challenge = null;
        widget.onSignedIn(response);
        return;
      }
      setState(() {
        busy = false;
        needCaptcha = response.state == SessionState.captchaRequired;
        error = needCaptcha
            ? '学校本次登录要求验证码，请输入验证码后继续'
            : response.failure == null
            ? '登录未完成，请重试'
            : failureMessage(response.failure);
        captcha.clear();
        challenge = null;
      });
      if (needCaptcha) await loadChallenge(expectedId: response.captchaId);
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
              constraints: const BoxConstraints(
                maxWidth: GinkgoLayout.formMaxWidth,
              ),
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
                          color: GinkgoColors.accent.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          CupertinoIcons.leaf_arrow_circlepath,
                          size: 46,
                          color: GinkgoColors.accent,
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
                      borderRadius: GinkgoRadii.borderRadiusDialog,
                      child: ColoredBox(
                        key: const Key('login-fields'),
                        color: GinkgoColors.secondaryGroupedBackground
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
                            if (needCaptcha && challenge?.textSupported == true)
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
                    if (needCaptcha) ...[
                      if (challengeBusy)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('正在读取验证码…'),
                        ),
                      if (challenge case final current?
                          when current.textSupported)
                        Semantics(
                          label: '登录验证码图片，请输入图片中的字符',
                          image: true,
                          child: Image.memory(
                            current.image,
                            height: 90,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const Text('图片无法显示，请刷新验证'),
                          ),
                        ),
                      if (challenge != null)
                        CupertinoButton(
                          key: const Key('login-captcha-refresh'),
                          onPressed: busy || challengeBusy
                              ? null
                              : () => loadChallenge(
                                  expectedId: challenge!.id,
                                  refresh: true,
                                ),
                          child: const Text('刷新验证'),
                        ),
                    ],
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
                      onPressed:
                          busy ||
                              challengeBusy ||
                              (needCaptcha && challenge?.textSupported != true)
                          ? null
                          : submit,
                      child: busy
                          ? ColorFiltered(
                              // The filled button keeps the brand leaf legible
                              // on its accent fill.
                              colorFilter: ColorFilter.mode(
                                CupertinoDynamicColor.resolve(
                                  CupertinoTheme.of(context)
                                      .primaryContrastingColor,
                                  context,
                                ),
                                BlendMode.srcIn,
                              ),
                              child: const GinkgoActivity(size: 17),
                            )
                          : const Text(
                              '登录',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '记住的密码保存在本机系统安全存储，退出登录时删除。'
                      '校外使用部分服务时，WebVPN 网关可能需要再次认证；'
                      '保存密码可用于重建网关会话，不代表密码会交给项目服务器。'
                      '不保存也可登录，但可能需要手动重新认证。验证码不会保存。',
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
      enabled: !busy && !challengeBusy,
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
