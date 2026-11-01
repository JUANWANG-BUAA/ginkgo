import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/auth_challenge.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/features/settings/maintenance_pages.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

/// The WebVPN gateway keeps its own login, separate from the school session.
/// When it demands a captcha the campus modules that need it stop working
/// until the user answers once here.
class GatewayChallengePage extends StatefulWidget {
  const GatewayChallengePage({super.key, required this.service});

  final MirrorService service;

  @override
  State<GatewayChallengePage> createState() => _GatewayChallengePageState();
}

class _GatewayChallengePageState extends State<GatewayChallengePage> {
  final answer = TextEditingController();
  LoginChallenge? challenge;
  bool loading = true;
  bool submitting = false;
  String? error;
  String? notice;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    answer.dispose();
    super.dispose();
  }

  Future<void> load({bool keepError = false}) async {
    setState(() {
      loading = true;
      if (!keepError) error = null;
    });
    try {
      final result = await widget.service.gatewayChallenge();
      if (!mounted) return;
      setState(() {
        challenge = result;
        loading = false;
        if (result == null && notice == null) {
          notice = '网关当前没有要求验证，签到和图书馆可以正常读取。';
        }
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = exception is StateError
            ? exception.message
            : '网关验证码暂时无法读取，请稍后重试';
      });
    }
  }

  Future<void> submit() async {
    if (submitting) return;
    final text = answer.text.trim();
    if (text.isEmpty) {
      setState(() => error = '请输入图片中的验证码');
      return;
    }
    setState(() {
      submitting = true;
      error = null;
      notice = null;
    });
    try {
      final solved = await widget.service.submitGatewayChallenge(text);
      if (!mounted) return;
      setState(() {
        submitting = false;
        if (solved) {
          challenge = null;
          answer.clear();
          notice = '网关验证已通过，请返回重试原来的操作。';
        } else {
          error = '验证码未通过，请重新输入';
        }
      });
      // A rejected answer leaves the challenge pending: read the next image
      // so the user is not retyping against a stale one.
      if (!solved) await load(keepError: true);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        submitting = false;
        error = exception is StateError ? exception.message : '验证码未通过，请稍后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = challenge;
    return MaintenanceScaffold(
      title: 'WebVPN 验证',
      section: '设置',
      subtitle: '网关要求时输入一次图片验证码',
      icon: CupertinoIcons.checkmark_shield,
      children: [
        AppleSection(
          children: [
            SummaryLine(
              '网关状态',
              loading
                  ? '正在读取'
                  : current == null
                  ? '无需验证'
                  : '等待输入验证码',
              icon: CupertinoIcons.checkmark_shield,
              tone: current == null ? StatusTone.success : StatusTone.pending,
            ),
          ],
        ),
        AppleSection(
          header: const Text('学校网关'),
          footer: const Text(
            '签到和图书馆需要 WebVPN 网关的独立会话。网关要求验证码时，在这里输入图片中的字符即可，验证只提交一次。',
          ),
          children: [
            if (loading)
              const AppleListTile(
                title: Text('正在读取验证状态'),
                trailing: GinkgoActivity(size: 16),
              )
            else if (current == null)
              AppleListTile(
                title: Text(notice ?? '当前不需要验证'),
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: load,
                  child: const Text('重新检查'),
                ),
              )
            else ...[
              if (current.textSupported) ...[
                Padding(
                  padding: GinkgoSpacing.edgeInsetsListTile,
                  child: Semantics(
                    label: '网关验证码图片',
                    image: true,
                    child: Image.memory(
                      current.image,
                      key: const Key('gateway-captcha-image'),
                      height: 64,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                AppleListTile(
                  title: CupertinoTextField.borderless(
                    key: const Key('gateway-captcha'),
                    controller: answer,
                    placeholder: '输入图片中的字符',
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => submit(),
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                ),
                AppleListTile(
                  title: Text(submitting ? '正在提交' : '提交验证'),
                  trailing: submitting
                      ? const GinkgoActivity(size: 16)
                      : const CupertinoListTileChevron(),
                  onTap: submitting ? null : submit,
                ),
              ] else
                const AppleListTile(
                  title: Text('网关要求的验证方式暂不支持在应用内完成'),
                  subtitle: Text('请稍后重试，或在系统浏览器完成登录后再回到应用。'),
                ),
            ],
          ],
        ),
        if (error != null)
          AppleSection(
            children: [
              AppleListTile(
                leading: const Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  color: AppleDesign.statusDanger,
                ),
                title: Text(error!),
              ),
            ],
          ),
      ],
    );
  }
}
