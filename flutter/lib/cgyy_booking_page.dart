import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

import 'application/mirror_service.dart';
import 'apple_widgets.dart';
import 'loading_widgets.dart';

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
  Map<String, dynamic>? options;
  String? notice;
  bool busy = false, loading = false, review = false;
  bool dirty = false, leaving = false, allowExit = false;
  Map<String, dynamic>? outcome;
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

  Future<Map<String, dynamic>> execute(Map<String, Object?> command) async {
    final result = await widget.gateway.executeCgyy(command);
    if (result.failure != null || result.payload == null) {
      throw _BookingFailure(failureMessage(result.failure));
    }
    return jsonDecode(result.payload!) as Map<String, dynamic>;
  }

  void markDirty() {
    if (mounted && !dirty) setState(() => dirty = true);
  }

  Future<void> leave() async {
    if (busy || leaving) return;
    leaving = true;
    try {
      if (dirty && !review) {
        final discard = await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('放弃未保存的预约？'),
            content: const Text('本次填写的信息不会保存。返回不会自动提交预约。'),
            actions: [
              CupertinoDialogAction(
                onPressed: () {
                  if (ModalRoute.of(context)?.isCurrent ?? false) {
                    Navigator.pop(context, false);
                  }
                },
                child: const Text('继续填写'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () {
                  if (ModalRoute.of(context)?.isCurrent ?? false) {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('放弃并返回'),
              ),
            ],
          ),
        );
        if (!mounted || discard != true) return;
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
      final result = await execute({
        'action': 'options',
        'site_id': widget.siteId,
        'date': widget.date,
      });
      if (!mounted) return;
      setState(() {
        options = result['options'] as Map<String, dynamic>?;
        space = choices.isEmpty ? null : choices.first['space_id'] as int;
        purpose = purposes.isEmpty ? null : purposes.first['id'] as int;
        times.clear();
      });
    } catch (_) {
      if (mounted) setState(() => notice = '未能读取可预约时段与用途，请刷新后重试');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get choices =>
      (options?['choices'] as List? ?? []).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get purposes =>
      (options?['purposes'] as List? ?? []).cast<Map<String, dynamic>>();

  String summary(List<Map<String, dynamic>> selected) => [
    '场馆：${widget.siteName}',
    '日期：${widget.date}',
    '空间：${selected.first['space_name']}',
    '时段：${selected.map((c) => c['time']).join('、')}',
    '人数：${count.text} 人',
    '用途：${purposes.firstWhere((p) => p['id'] == purpose)['name']}',
    '手机：${phone.text}',
    '主题：${theme.text.trim()}',
    '内容：${content.text.trim()}',
    '参与人：${joiners.text.trim()}',
    '哲学社会科学类：${philosophy ? '是' : '否'}',
    '含校外参与人：${offSchool ? '是' : '否'}',
  ].join('\n');

  void applyOutcome(Map<String, dynamic> result) {
    final known = {
      'accepted',
      'uncertain',
      'rejected',
      'not_submitted',
      'notSubmitted',
    };
    outcome = known.contains(result['state'])
        ? result
        : {'state': 'uncertain', 'message': '返回状态无法判明，请先到我的预约回查，勿重复提交'};
    notice = outcome!['message'] as String? ?? '请核对我的预约';
    review =
        outcome!['state'] == 'uncertain' || outcome!['state'] == 'accepted';
  }

  Future<void> prepare() async {
    if (busy || loading || review || leaving) return;
    final selected =
        choices
            .where(
              (c) => c['space_id'] == space && times.contains(c['time_id']),
            )
            .toList()
          ..sort(
            (a, b) => (a['time_id'] as int).compareTo(b['time_id'] as int),
          );
    if (space == null ||
        times.isEmpty ||
        times.length > 12 ||
        selected.length != times.length ||
        purpose == null ||
        !purposes.any((p) => p['id'] == purpose) ||
        !RegExp(r'^\d{11}$').hasMatch(phone.text) ||
        widget.siteId <= 0 ||
        space! <= 0 ||
        purpose! <= 0 ||
        times.any((id) => id <= 0) ||
        (int.tryParse(count.text) ?? 0) < 1 ||
        (int.tryParse(count.text) ?? 101) > 100 ||
        [theme.text, content.text, joiners.text].any((s) => s.trim().isEmpty)) {
      setState(
        () => notice = '请选择研讨室、1–12 个时段和用途，并完整填写 11 位手机号、1–100 人、主题、内容及参与人说明',
      );
      return;
    }
    final bookingSummary = summary(selected);
    // Acquire before opening a dialog: two taps in the same frame cannot stack it.
    setState(() {
      busy = true;
      notice = null;
    });
    var requested = false;
    try {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('确认预约信息'),
          content: Text(
            '$bookingSummary\n\n将创建学校预约草稿，完成手动拼图后提交一次。结果不明时仅回查，不自动重发。',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                if (ModalRoute.of(context)?.isCurrent ?? false) {
                  Navigator.pop(context, false);
                }
              },
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                if (ModalRoute.of(context)?.isCurrent ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('继续验证'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      requested = true;
      final result = await execute({
        'action': 'prepare',
        'booking': {
          'site_id': widget.siteId,
          'date': widget.date,
          'space_id': space,
          'time_ids': times.toList()..sort(),
          'phone': phone.text,
          'theme': theme.text.trim(),
          'purpose_type': purpose,
          'joiner_num': int.parse(count.text),
          'activity_content': content.text.trim(),
          'joiners': joiners.text.trim(),
          'philosophy': philosophy,
          'off_school': offSchool,
        },
      });
      if (!mounted) return;
      if (result['state'] == 'challenge') {
        final message = await Navigator.of(context).push<Map<String, dynamic>>(
          CupertinoPageRoute(
            builder: (_) => _CgyyCaptchaPage(
              gateway: widget.gateway,
              challenge: result['challenge'] as Map<String, dynamic>,
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
            applyOutcome({
              'state': 'uncertain',
              'message': '结果待核实，请返回我的预约回查，勿重复提交',
            });
          } else {
            notice = '尚未提交预约，可修改后继续';
          }
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    String label,
    TextEditingController controller, {
    bool number = false,
    bool multiline = false,
  }) => Semantics(
    label: label,
    child: CupertinoTextFormFieldRow(
      controller: controller,
      placeholder: label,
      keyboardType: number
          ? TextInputType.number
          : multiline
          ? TextInputType.multiline
          : TextInputType.text,
      minLines: multiline ? 2 : 1,
      maxLines: multiline ? 4 : 1,
      enabled: !busy && !review,
      maxLength: number ? 11 : 500,
    ),
  );

  Widget spaceGrid(int id, String name) {
    final slots = choices.where((c) => c['space_id'] == id).toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${slots.length} 段可约',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoTheme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final slot in slots)
                Semantics(
                  selected: space == id && times.contains(slot['time_id']),
                  button: true,
                  label:
                      '$name ${slot['time']} ${space == id && times.contains(slot['time_id']) ? '已选' : '空闲'}',
                  child: CupertinoButton(
                    minimumSize: const Size(96, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    color: space == id && times.contains(slot['time_id'])
                        ? CupertinoTheme.of(context).primaryColor
                              .withValues(alpha: 0.16)
                        : CupertinoColors.tertiarySystemFill.resolveFrom(
                            context,
                          ),
                    borderRadius: BorderRadius.circular(7),
                    onPressed: busy || review
                        ? null
                        : () => setState(() {
                            if (space != id) {
                              space = id;
                              times.clear();
                            }
                            final timeId = slot['time_id'] as int;
                            if (times.contains(timeId)) {
                              times.remove(timeId);
                            } else if (times.length < 12) {
                              times.add(timeId);
                            } else {
                              notice = '一次最多选择 12 个时段';
                              return;
                            }
                            dirty = true;
                          }),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          slot['time'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                        Text(
                          space == id && times.contains(slot['time_id'])
                              ? '已选'
                              : '空闲',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                space == id && times.contains(slot['time_id'])
                                ? CupertinoTheme.of(context).primaryColor
                                : CupertinoColors.secondaryLabel.resolveFrom(
                                    context,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget participantStepper() {
    final value = int.parse(count.text);
    return AppleListTile(
      title: Text('参与人数：$value 人'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton.tinted(
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(48, 48),
            onPressed: busy || review || value <= 1
                ? null
                : () => setState(() => count.text = '${value - 1}'),
            child: const SemanticsLabelIcon(
              label: '减少参与人数',
              icon: CupertinoIcons.minus,
            ),
          ),
          const SizedBox(width: 2),
          CupertinoButton.tinted(
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(48, 48),
            onPressed: busy || review || value >= 100
                ? null
                : () => setState(() => count.text = '${value + 1}'),
            child: const SemanticsLabelIcon(
              label: '增加参与人数',
              icon: CupertinoIcons.plus,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spaces = <int, String>{
      for (final c in choices) c['space_id'] as int: c['space_name'] as String,
    };
    return PopScope<Map<String, dynamic>>(
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
              ApplePageHeader(
                largeTitle: const Text('预约研讨室'),
                section: '空间资源',
                subtitle: '选择场馆并查看可预约空间',
                icon: CupertinoIcons.person_3,
                border: null,
              ),
              SliverList.list(
                children: [
                  AppleSection(
                    header: const Text('场地与日期'),
                    children: [
                      AppleListTile(
                        title: const Text('场地'),
                        subtitle: Text(widget.siteName),
                      ),
                      AppleListTile(
                        title: const Text('日期'),
                        subtitle: Text(widget.date),
                      ),
                    ],
                  ),
                  AppleSection(
                    header: const Text('选择空间与时段'),
                    footer: const Text('同一次预约只能选择一个空间，最多选择 12 个时段。'),
                    children: [
                      if (loading) const GinkgoLoadingView(label: '正在读取预约信息…'),
                      if (options != null && choices.isEmpty)
                        const AppleEmptyState(
                          title: '当天暂无可预约空间',
                          description: '请返回切换日期或场地。',
                        ),
                      for (final entry in spaces.entries)
                        spaceGrid(entry.key, entry.value),
                    ],
                  ),
                  if (purposes.isNotEmpty)
                    AppleSection(
                      header: const Text('预约信息'),
                      footer: const Text('手机号与参与人仅用于本次学校预约，不保存在本机日志中。'),
                      children: [
                        field('手机号（11 位）', phone, number: true),
                        field('活动主题', theme),
                        Builder(
                          builder: (anchor) => AppleListTile(
                            title: const Text('活动类型'),
                            additionalInfo: SizedBox(
                              width: MediaQuery.sizeOf(context).width * 0.44,
                              child: Text(
                                purposes.firstWhere(
                                      (p) => p['id'] == purpose,
                                      orElse: () => purposes.first,
                                    )['name']
                                    as String,
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            trailing: const Icon(
                              CupertinoIcons.chevron_up_chevron_down,
                              size: 14,
                            ),
                            onTap: busy || review
                                ? null
                                : () async {
                                    final selected = await choose<int>(
                                      anchor,
                                      '活动类型',
                                      purposes
                                          .map((p) => p['id'] as int)
                                          .toList(),
                                      (id) =>
                                          purposes.firstWhere(
                                                (p) => p['id'] == id,
                                              )['name']
                                              as String,
                                      selected: purpose,
                                    );
                                    if (mounted && selected != null) {
                                      setState(() {
                                        purpose = selected;
                                        dirty = true;
                                      });
                                    }
                                  },
                          ),
                        ),
                        participantStepper(),
                        field('活动内容', content, multiline: true),
                        field('参与人说明', joiners),
                        AppleListTile(
                          title: const Text('哲学社会科学类'),
                          trailing: CupertinoSwitch(
                            value: philosophy,
                            onChanged: busy || review
                                ? null
                                : (v) => setState(() {
                                    philosophy = v;
                                    dirty = true;
                                  }),
                          ),
                        ),
                        AppleListTile(
                          title: const Text('含校外参与人'),
                          trailing: CupertinoSwitch(
                            value: offSchool,
                            onChanged: busy || review
                                ? null
                                : (v) => setState(() {
                                    offSchool = v;
                                    dirty = true;
                                  }),
                          ),
                        ),
                      ],
                    ),
                  if (notice != null)
                    AppleSection(
                      children: [
                        AppleListTile(
                          leading: const Icon(CupertinoIcons.info_circle),
                          title: Text(notice!),
                        ),
                      ],
                    ),
                  AppleSection(
                    footer: const Text('实验功能，真实预约往返仍需人工验收。提交后需核对学校审批状态。'),
                    children: [
                      CupertinoButton(
                        onPressed: busy || loading || review || options == null
                            ? null
                            : prepare,
                        child: const Text('确认信息并验证'),
                      ),
                      if (!review)
                        CupertinoButton(
                          onPressed: busy || loading ? null : load,
                          child: const Text('刷新空闲时段'),
                        ),
                      if (review)
                        CupertinoButton(
                          onPressed: busy ? null : leave,
                          child: const Text('返回并核对我的预约'),
                        ),
                    ],
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
}

class SemanticsLabelIcon extends StatelessWidget {
  const SemanticsLabelIcon({
    super.key,
    required this.label,
    required this.icon,
  });
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) =>
      Semantics(label: label, child: Icon(icon, size: 18));
}

class _BookingFailure implements Exception {
  const _BookingFailure(this.message);
  final String message;
}

class _CgyyCaptchaPage extends StatefulWidget {
  const _CgyyCaptchaPage({
    required this.gateway,
    required this.challenge,
    required this.summary,
    required this.consumedChallenges,
  });
  final CgyyBookingGateway gateway;
  final Map<String, dynamic> challenge;
  final String summary;
  final Set<String> consumedChallenges;
  @override
  State<_CgyyCaptchaPage> createState() => _CgyyCaptchaPageState();
}

class _CgyyCaptchaPageState extends State<_CgyyCaptchaPage> {
  Uint8List? background, piece;
  double width = 310, height = 155, pieceWidth = 60, pieceHeight = 155, x = 0;
  String? error;
  bool busy = false, attempted = false, dragged = false, allowExit = false;
  @override
  void initState() {
    super.initState();
    if (widget.consumedChallenges.contains(widget.challenge['id'])) {
      error = '此验证已使用，请返回后重新准备预约';
    } else {
      decode();
    }
  }

  Future<void> decode() async {
    try {
      Uint8List bytes(String value) {
        if (value.length > 3000000) throw const FormatException();
        return base64Decode(
          value.contains(',') ? value.split(',').last : value,
        );
      }

      final a = bytes(widget.challenge['background'] as String),
          b = bytes(widget.challenge['jigsaw'] as String);
      final ac = await ui.instantiateImageCodec(a),
          bc = await ui.instantiateImageCodec(b);
      try {
        final af = await ac.getNextFrame(), bf = await bc.getNextFrame();
        final w = af.image.width.toDouble(),
            h = af.image.height.toDouble(),
            pw = bf.image.width.toDouble(),
            ph = bf.image.height.toDouble();
        af.image.dispose();
        bf.image.dispose();
        if (w <= pw ||
            w > 1000 ||
            h > 1000 ||
            ph > h ||
            pw <= 0 ||
            ph <= 0 ||
            (widget.challenge['id'] as String? ?? '').isEmpty) {
          throw const FormatException();
        }
        if (mounted) {
          setState(() {
            background = a;
            piece = b;
            width = w;
            height = h;
            pieceWidth = pw;
            pieceHeight = ph;
          });
        }
      } finally {
        ac.dispose();
        bc.dispose();
      }
    } catch (_) {
      if (mounted) setState(() => error = '验证图片无法显示，请返回后重新准备预约');
    }
  }

  Future<void> exit([Map<String, dynamic>? result]) async {
    if (!mounted || allowExit) return;
    setState(() => allowExit = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, result);
  }

  Future<void> submit() async {
    if (busy ||
        attempted ||
        !dragged ||
        x.round() <= 0 ||
        background == null ||
        piece == null ||
        error != null ||
        widget.consumedChallenges.contains(widget.challenge['id'])) {
      return;
    }
    setState(() => busy = true);
    try {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('提交预约？'),
          content: Text(
            '${widget.summary}\n\n将验证你手动拖动的拼图并提交一次预约。受理不等于审批成功，提交后需回查。',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                if (ModalRoute.of(context)?.isCurrent ?? false) {
                  Navigator.pop(context, false);
                }
              },
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                if (ModalRoute.of(context)?.isCurrent ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('提交一次'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      // A challenge is consumed even on rejection or transport failure.
      attempted = true;
      widget.consumedChallenges.add(widget.challenge['id'] as String);
      Map<String, dynamic> outcome = {
        'state': 'uncertain',
        'message': '结果待核实，请在我的预约回查，勿重复提交',
      };
      try {
        final response = await widget.gateway.executeCgyy({
          'action': 'submit',
          'challenge_id': widget.challenge['id'],
          // Device/image pixels are normalized to the 310-wide protocol
          // coordinate by Rust; the width travels with the offset.
          'x': x,
          'width': width,
        });
        if (response.payload != null && response.failure == null) {
          final result = jsonDecode(response.payload!) as Map<String, dynamic>;
          if ({
            'accepted',
            'uncertain',
            'rejected',
            'not_submitted',
            'notSubmitted',
          }.contains(result['state'])) {
            outcome = result;
          }
        }
      } catch (_) {
        // Could fail before captcha/check, or after submit. Never claim success.
      }
      if (mounted) await exit(outcome);
    } finally {
      if (mounted && !attempted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Map<String, dynamic>>(
    canPop: allowExit,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !busy) exit();
    },
    child: CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        leading: CupertinoButton(
          key: const Key('captcha-back'),
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.zero,
          onPressed: busy ? null : () => exit(),
          child: const Text('返回'),
        ),
        middle: const Text('学校拼图验证'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            AppleSection(
              header: const Text('拖动拼图对齐缺口'),
              footer: const Text(
                '验证由你手动完成，有效期约两分钟。返回不会自动提交；未发送最终预约时，返回后仍需核对并解除本机保护。',
              ),
              children: [
                if (background == null && error == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: GinkgoActivity(size: 17),
                  ),
                if (background != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 180,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: Stack(
                            children: [
                              Image.memory(
                                background!,
                                width: width,
                                height: height,
                              ),
                              Positioned(
                                left: x,
                                top: 0,
                                child: Image.memory(
                                  piece!,
                                  width: pieceWidth,
                                  height: pieceHeight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (background != null)
                  Semantics(
                    label: '拼图横向位置',
                    child: SizedBox(
                      height: 48,
                      child: CupertinoSlider(
                        value: x,
                        min: 0,
                        max: width - pieceWidth,
                        onChanged: busy || attempted || error != null
                            ? null
                            : (value) => setState(() {
                                x = value;
                              }),
                        onChangeEnd: (value) =>
                            setState(() => dragged = value.round() > 0),
                      ),
                    ),
                  ),
                if (error != null) AppleListTile(title: Text(error!)),
                CupertinoButton(
                  minimumSize: const Size(48, 48),
                  onPressed:
                      busy ||
                          attempted ||
                          !dragged ||
                          x.round() <= 0 ||
                          background == null ||
                          error != null
                      ? null
                      : submit,
                  child: busy ? const Text('处理中…') : const Text('验证并提交一次'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
