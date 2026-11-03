import 'package:ginkgo_mirror/application/gateway_verification_failure.dart';
import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/auth_challenge.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'maintenance_pages.dart';

class GatewayChallengePage extends StatefulWidget {
  const GatewayChallengePage({super.key, required this.gateway});
  final GatewayVerificationGateway gateway;
  @override
  State<GatewayChallengePage> createState() => _GatewayChallengePageState();
}

class _GatewayChallengePageState extends State<GatewayChallengePage> {
  final answer = TextEditingController();
  LoginChallenge? challenge;
  bool busy = false;
  String? error;
  String? notice;
  int generation = 0;

  bool isCurrent(int epoch) => mounted && epoch == generation;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(GatewayChallengePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.gateway, widget.gateway)) return;
    generation++;
    busy = false;
    challenge = null;
    error = notice = null;
    answer.clear();
    load();
  }

  @override
  void dispose() {
    generation++;
    answer.dispose();
    super.dispose();
  }

  String message(Object failure) {
    if (failure is GatewayVerificationException) {
      return '${failureMessage(failure.failure)}；请读取当前挑战后重试，结果不明时不会自动重发';
    }
    return failure is StateError
        ? failure.message.toString()
        : '网关验证暂时无法完成，请重新读取挑战';
  }

  Future<void> load({bool refresh = false}) async {
    if (busy) return;
    final epoch = generation;
    final gateway = widget.gateway;
    final previous = challenge;
    final id = previous?.id;
    setState(() {
      busy = true;
      challenge = null;
      error = null;
      notice = null;
    });
    answer.clear();
    try {
      final next = await gateway.gatewayChallenge(
        expectedId: id,
        refresh: refresh,
      );
      if (!isCurrent(epoch)) return;
      setState(() {
        challenge = next;
        if (next == null) notice = '当前没有待处理验证码；这不代表网关会话已经有效。请返回原页面重试读取。';
      });
    } catch (failure) {
      if (isCurrent(epoch)) {
        setState(() {
          challenge = previous;
          error = message(failure);
        });
      }
    } finally {
      if (isCurrent(epoch)) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    final current = challenge;
    if (busy || current == null || !current.textSupported) return;
    if (answer.text.trim().isEmpty) {
      setState(() => error = '请输入验证码');
      return;
    }
    final epoch = generation;
    final gateway = widget.gateway;
    final text = answer.text.trim();
    answer.clear();
    setState(() {
      busy = true;
      challenge = null;
      error = null;
      notice = null;
    });
    try {
      await gateway.answerGatewayChallenge(
        expectedId: current.id,
        answer: text,
      );
      if (isCurrent(epoch)) setState(() => notice = '网关验证通过，请返回原页面重新读取。');
    } catch (failure) {
      if (!isCurrent(epoch)) return;
      setState(() => error = message(failure));
      // A failed answer may return a new execution; fetch it without re-posting.
      try {
        final next = await gateway.gatewayChallenge();
        if (isCurrent(epoch)) setState(() => challenge = next);
      } catch (_) {
        /* Keep the submission failure and offer an explicit read. */
      }
    } finally {
      if (isCurrent(epoch)) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = challenge;
    return MaintenanceScaffold(
      title: 'WebVPN 验证',
      section: '设置',
      subtitle: '完成学校网关要求的图片验证码',
      icon: CupertinoIcons.checkmark_shield,
      children: [
        AppleSection(
          children: [
            SummaryLine(
              '网关验证',
              busy
                  ? '处理中'
                  : current == null
                  ? '暂无待处理挑战'
                  : '等待作答',
              icon: CupertinoIcons.checkmark_shield,
              tone: StatusTone.pending,
            ),
          ],
        ),
        AppleSection(
          header: const Text('学校网关'),
          footer: const Text('仅提交一次验证码。切换账号或路线后，旧挑战不可继续使用。'),
          children: [
            if (busy)
              const AppleListTile(
                title: Text('正在处理网关验证'),
                trailing: GinkgoActivity(),
              ),
            if (current != null && !busy) ...[
              if (current.textSupported) ...[
                Padding(
                  padding: GinkgoSpacing.edgeInsetsListTile,
                  child: Semantics(
                    image: true,
                    label: '网关验证码图片',
                    child: Image.memory(
                      current.image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Text('图片无法显示，请刷新验证码'),
                    ),
                  ),
                ),
                AppleListTile(
                  title: CupertinoTextField.borderless(
                    key: const Key('gateway-answer'),
                    controller: answer,
                    placeholder: '输入图片中的字符',
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => submit(),
                  ),
                ),
                AppleListTile(
                  key: const Key('gateway-submit'),
                  title: const Text('提交验证'),
                  onTap: submit,
                ),
              ] else
                const AppleListTile(title: Text('当前验证方式无法在应用内作答，请重新登录')),
              AppleListTile(
                key: const Key('gateway-refresh'),
                leading: const Icon(CupertinoIcons.refresh),
                title: const Text('刷新验证码'),
                onTap: () => load(refresh: true),
              ),
            ],
            if (!busy && current == null)
              AppleListTile(
                key: const Key('gateway-read'),
                title: const Text('重新读取挑战'),
                onTap: load,
              ),
            if (notice != null) AppleListTile(title: Text(notice!)),
          ],
        ),
        if (error != null)
          AppleSection(
            children: [
              Semantics(
                liveRegion: true,
                child: AppleListTile(
                  leading: const Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    color: AppleDesign.statusDanger,
                  ),
                  title: Text(error!),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
