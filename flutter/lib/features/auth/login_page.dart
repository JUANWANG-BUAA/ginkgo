import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_mark.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/contracts.dart'
    show RouteChoice, SessionResponse, SessionState;
import 'package:ginkgo_mirror/shared/app_preferences.dart';

import 'login_route_selector.dart';
import 'login_credential_field.dart';
import 'login_feedback.dart';
import 'login_retry_pause.dart';

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
  late final LoginRetryPause retryPause = LoginRetryPause(() {
    if (mounted) setState(() => error = retryPause.message);
  });

  bool remember = false;
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
    final previous = challenge;
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
        error = previous == null
            ? '验证码读取失败或已失效，请重新登录获取验证'
            : '验证码刷新失败，请重试刷新；旧答案不会用于新的挑战';
        challenge = previous;
        needCaptcha = previous != null;
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

  RouteChoice _route = RouteChoice.automatic;
  bool _routeApplied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeApplied) return;
    _routeApplied = true;
    final stored = AppPreferencesScope.of(context).routeMode;
    _route = switch (stored) {
      'direct' => RouteChoice.direct,
      'webVpn' => RouteChoice.webVpn,
      _ => RouteChoice.automatic,
    };
  }

  Future<void> _changeRoute(RouteChoice route) async {
    if (busy || challengeBusy || route == _route) return;
    final preferences = AppPreferencesScope.of(context);
    setState(() => busy = true);
    try {
      final response = await widget.service.setRoute(route);
      if (!mounted) return;
      if (response.failure != null) {
        setState(() => error = failureMessage(response.failure));
        return;
      }
      challengeEpoch++;
      captcha.clear();
      setState(() {
        _route = route;
        needCaptcha = false;
        challenge = null;
        error = null;
      });
      await preferences.setRouteMode(route.name);
      if (mounted && preferences.saveError != null) {
        setState(() => error = preferences.saveError);
      }
    } catch (_) {
      if (mounted) setState(() => error = '网络路线切换失败，请重试');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    retryPause.dispose();
    account.dispose();
    password.dispose();
    captcha.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || challengeBusy || retryPause.remaining > 0) return;
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
        // The school's own reason ("验证码错误", "账号已锁定") is more useful
        // than a generic line and is already stripped of markup upstream.
        final detail = response.failureDetail?.trim();
        error = needCaptcha
            ? '学校本次登录要求验证码，请输入验证码后继续'
            : detail != null && detail.isNotEmpty
            ? detail
            : response.failure == null
            ? '登录未完成，请重试'
            : failureMessage(response.failure);
        captcha.clear();
        challenge = null;
        if (retryPause.record(response.failure)) error = retryPause.message;
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
                        child: const Center(
                          child: GinkgoMark(
                            key: Key('login-mark'),
                            size: 52,
                            color: GinkgoColors.accent,
                            veinColor: GinkgoColors.accentSubtle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Ginkgo',
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
                        fontSize: AppleDesign.bodyCondensedSize,
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
                            LoginRouteSelector(
                              route: _route,
                              onChanged: busy || challengeBusy
                                  ? null
                                  : _changeRoute,
                            ),
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
                            if (needCaptcha) _challengeRow(),
                            Container(
                              height: .5,
                              margin: const EdgeInsets.only(left: 48),
                              color: CupertinoColors.separator.resolveFrom(
                                context,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                      LoginFeedback(
                        key: const Key('login-error'),
                        message: error!,
                      ),
                    const SizedBox(height: 24),
                    CupertinoButton.filled(
                      key: const Key('login-submit'),
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      onPressed:
                          busy ||
                              retryPause.remaining > 0 ||
                              challengeBusy ||
                              (needCaptcha && challenge?.textSupported != true)
                          ? null
                          : submit,
                      child: busy
                          ? Semantics(
                              key: const Key('login-busy-status'),
                              liveRegion: true,
                              label: '正在登录',
                              child: ColorFiltered(
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
                              ),
                            )
                          : const Text(
                              '登录',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '密码仅发送至学校认证系统；勾选记住密码后才保存到本机安全存储。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                    const SizedBox(height: GinkgoSpacing.sm),
                    const LoginNetworkNote(),
                    CupertinoButton(
                      onPressed: busy ? null : widget.onDemo,
                      minimumSize: const Size(48, 48),
                      child: const Text(
                        '先看看离线演示',
                        style: TextStyle(fontSize: 13),
                      ),
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

  /// The challenge image and its refresh action belong to the same card as
  /// the fields they validate, so they keep one rhythm instead of floating on
  /// the page background.
  Widget _challengeRow() {
    final current = challenge;
    if (current == null || !current.textSupported) {
      return Padding(
        padding: GinkgoSpacing.edgeInsetsListTile,
        child: Row(
          children: [
            Expanded(
              child: Text(
                challengeBusy ? '正在读取验证码…' : '验证方式暂不可用，请刷新',
                style: TextStyle(
                  fontSize: AppleDesign.bodyCondensedSize,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
            CupertinoButton(
              key: const Key('login-captcha-refresh'),
              padding: EdgeInsets.zero,
              onPressed: busy || challengeBusy
                  ? null
                  : () =>
                        loadChallenge(expectedId: challenge?.id, refresh: true),
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
                  style: TextStyle(
                    fontSize: AppleDesign.bodyCondensedSize,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ),
          ),
          CupertinoButton(
            key: const Key('login-captcha-refresh'),
            padding: const EdgeInsets.only(left: 12),
            onPressed: busy || challengeBusy
                ? null
                : () => loadChallenge(expectedId: current.id, refresh: true),
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
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String placeholder,
    required String label,
    bool obscure = false,
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
    ValueChanged<String>? onSubmitted,
  }) => loginCredentialField(
    context: context,
    busy: busy,
    challengeBusy: challengeBusy,
    showPassword: showPassword,
    togglePassword: () => setState(() => showPassword = !showPassword),
    key: key,
    controller: controller,
    placeholder: placeholder,
    label: label,
    obscure: obscure,
    textInputAction: textInputAction,
    autofillHints: autofillHints,
    onSubmitted: onSubmitted,
  );
}
