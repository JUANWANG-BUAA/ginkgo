import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/cgyy_commands.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'cgyy_booking_form.dart';
import 'cgyy_booking_write.dart';
import 'cgyy_captcha_page.dart';
import 'cgyy_models.dart';
import 'cgyy_widgets.dart';

/// Mirrors IOSCgyyView's grouped native form and explicit confirmation flow.
/// Form content is memory-only and never enters diagnostics/preferences.
class CgyyBookingPage extends StatefulWidget {
  const CgyyBookingPage({
    super.key,
    required this.gateway,
    required this.siteId,
    required this.siteName,
    required this.date,
  });
  final CgyyBookingGateway gateway;
  final int siteId;
  final String siteName, date;
  @override
  State<CgyyBookingPage> createState() => _CgyyBookingPageState();
}

class _CgyyBookingPageState extends State<CgyyBookingPage> {
  CgyyBookingOptions? options;
  String? notice;
  bool busy = false, loading = false, review = false;
  bool dirty = false, leaving = false, allowExit = false;
  CgyyActionResult? outcome;
  int? space, purpose;
  final times = <int>{};
  final consumedChallenges = <String>{};
  final phone = TextEditingController(),
      theme = TextEditingController(),
      count = TextEditingController(text: '1'),
      content = TextEditingController(),
      joiners = TextEditingController();
  bool philosophy = false, offSchool = false;
  @override
  void initState() {
    super.initState();
    for (final controller in [phone, theme, count, content, joiners]) {
      controller.addListener(markDirty);
    }
    load();
  }

  @override
  void dispose() {
    for (final c in [phone, theme, count, content, joiners]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<CgyyActionResult> execute(CgyyCommand command) async {
    try {
      return await widget.gateway.executeCgyy(command);
    } on Object {
      // The gateway records the typed failure in the diagnostic log; the
      // page itself only needs to know that no draft exists.
      failureMessage(null);
      throw const CgyyBookingFailure();
    }
  }

  void markDirty() {
    if (mounted && !dirty) setState(() => dirty = true);
  }

  Future<void> leave() async {
    if (busy || leaving) return;
    leaving = true;
    try {
      if (dirty && !review) {
        final discard = await showCgyyConfirmDialog(
          context,
          title: '放弃未保存的预约？',
          content: '本次填写的信息不会保存。返回不会自动提交预约。',
          cancelLabel: '继续填写',
          confirmLabel: '放弃并返回',
          destructive: true,
        );
        if (!mounted || !discard) return;
      }
      if (!mounted) return;
      setState(() => allowExit = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, outcome);
    } finally {
      leaving = false;
    }
  }

  Future<void> load() async {
    if (busy || loading || review) return;
    setState(() {
      loading = true;
      notice = null;
    });
    try {
      final result = await execute(
        CgyyOptionsCommand(siteId: widget.siteId, date: widget.date),
      );
      if (!mounted) return;
      setState(() {
        options = result.options;
        space = choices.isEmpty ? null : choices.first.spaceId;
        purpose = purposes.isEmpty ? null : purposes.first.id;
        times.clear();
      });
    } catch (_) {
      if (mounted) setState(() => notice = '未能读取可预约时段与用途，请刷新后重试');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<CgyyBookingChoice> get choices => options?.choices ?? const [];
  List<CgyyPurpose> get purposes => options?.purposes ?? const [];

  void applyOutcome(CgyyActionResult result) {
    outcome = result.isKnown
        ? result
        : CgyyActionResult.fromState('uncertain', '返回状态无法判明，请先到我的预约回查，勿重复提交');
    notice = outcome!.message;
    review = outcome!.requiresReview;
  }

  /// The values of the form as one snapshot for the confirmation and the
  /// school request.
  CgyyBookingDraft buildDraft(List<CgyyBookingChoice> selected) =>
      CgyyBookingDraft(
        siteId: widget.siteId,
        siteName: widget.siteName,
        date: widget.date,
        spaceId: space ?? 0,
        spaceName: selected.isEmpty ? '' : selected.first.spaceName,
        timeIds: times.toList()..sort(),
        times: selected.map((c) => c.time).toList(),
        participantCount: count.text,
        purposeId: purpose ?? 0,
        purposeName: purposes
            .where((p) => p.id == purpose)
            .map((p) => p.name)
            .join(),
        phone: phone.text,
        theme: theme.text.trim(),
        content: content.text.trim(),
        joiners: joiners.text.trim(),
        philosophy: philosophy,
        offSchool: offSchool,
      );

  Future<void> prepare() async {
    if (busy || loading || review || leaving) return;
    final selected =
        choices
            .where((c) => c.spaceId == space && times.contains(c.timeId))
            .toList()
          ..sort((a, b) => a.timeId.compareTo(b.timeId));
    final draft = buildDraft(selected);
    if (!draft.isComplete) {
      setState(
        () => notice = '请选择研讨室、1–12 个时段和用途，并完整填写 11 位手机号、1–100 人、主题、内容及参与人说明',
      );
      return;
    }
    final bookingSummary = draft.summary;
    // Acquire before opening a dialog: two taps in the same frame cannot stack it.
    setState(() {
      busy = true;
      notice = null;
    });
    var requested = false;
    try {
      final confirmed = await showCgyyConfirmDialog(
        context,
        title: '确认预约信息',
        content: '$bookingSummary\n\n将创建学校预约草稿，完成手动拼图后提交一次。结果不明时仅回查，不自动重发。',
        cancelLabel: '取消',
        confirmLabel: '继续验证',
        isDefault: true,
      );
      if (!mounted || !confirmed) return;
      requested = true;
      final result = await execute(CgyyPrepareCommand(draft));
      if (!mounted) return;
      if (result.isChallenge) {
        final message = await Navigator.of(context).push<CgyyActionResult>(
          CupertinoPageRoute(
            builder: (_) => CgyyCaptchaPage(
              gateway: widget.gateway,
              challenge: result.challenge!,
              summary: bookingSummary,
              consumedChallenges: consumedChallenges,
            ),
          ),
        );
        if (!mounted) return;
        if (message != null) {
          setState(() {
            applyOutcome(message);
            times.clear();
          });
        } else {
          setState(() => notice = '未发送最终预约；返回后仍需核对并解除本机保护');
        }
      } else {
        setState(() => applyOutcome(result));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (requested) {
            applyOutcome(
              CgyyActionResult.fromState('uncertain', '结果待核实，请返回我的预约回查，勿重复提交'),
            );
          } else {
            notice = '尚未提交预约，可修改后继续';
          }
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void toggleSlot(CgyyBookingChoice slot) {
    setState(() {
      if (space != slot.spaceId) {
        space = slot.spaceId;
        times.clear();
      }
      if (times.contains(slot.timeId)) {
        times.remove(slot.timeId);
      } else if (times.length < 12) {
        times.add(slot.timeId);
      } else {
        notice = '一次最多选择 12 个时段';
        return;
      }
      dirty = true;
    });
  }

  void selectPurpose(int id) {
    if (!mounted) return;
    setState(() {
      purpose = id;
      dirty = true;
    });
  }

  void stepParticipant(int value) {
    setState(() => count.text = '$value');
  }

  @override
  Widget build(BuildContext context) => PopScope<CgyyActionResult>(
    canPop: allowExit,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) leave();
    },
    child: CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: SafeArea(
        top: false,
        child: CustomScrollView(
          key: const Key('cgyy-booking-form'),
          slivers: [
            const AppleRefreshPageHeader(
              title: '预约研讨室',
              subtitle: '选择场馆并查看可预约空间',
              icon: CupertinoIcons.person_3,
            ),
            SliverList.list(
              children: [
                CgyyVenueSection(siteName: widget.siteName, date: widget.date),
                CgyySlotSection(
                  loading: loading,
                  loaded: options != null,
                  choices: choices,
                  selectedSpaceId: space,
                  selectedTimeIds: times,
                  onToggleSlot: toggleSlot,
                  enabled: !busy && !review,
                ),
                if (purposes.isNotEmpty)
                  CgyyDetailsSection(
                    purposes: purposes,
                    purposeId: purpose,
                    phone: phone,
                    theme: theme,
                    content: content,
                    joiners: joiners,
                    participantCount: int.parse(count.text),
                    philosophy: philosophy,
                    offSchool: offSchool,
                    onSelectPurpose: selectPurpose,
                    onStepParticipant: stepParticipant,
                    onTogglePhilosophy: (value) => setState(() {
                      philosophy = value;
                      dirty = true;
                    }),
                    onToggleOffSchool: (value) => setState(() {
                      offSchool = value;
                      dirty = true;
                    }),
                    enabled: !busy && !review,
                  ),
                if (options?.usesFallbackPurposes == true)
                  const CgyyNoticeSection(message: '学校用途暂未取得，已使用内置用途列表'),
                if (notice != null) CgyyNoticeSection(message: notice!),
                CgyyBookingActionsSection(
                  busy: busy,
                  loading: loading,
                  review: review,
                  enabled: options != null,
                  onSubmit: prepare,
                  onRefresh: load,
                  onLeave: leave,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
