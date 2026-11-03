import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/query_snapshots.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/features/settings/maintenance_pages.dart';

class LearningSnapshotsPage extends StatefulWidget {
  const LearningSnapshotsPage({super.key, required this.gateway});
  final LearningSnapshotGateway gateway;
  @override
  State<LearningSnapshotsPage> createState() => _LearningSnapshotsPageState();
}

class _LearningSnapshotsPageState extends State<LearningSnapshotsPage> {
  LearningSnapshotStatus? status;
  bool busy = false;
  int requestSerial = 0;
  String? error;

  bool current(int serial) => mounted && serial == requestSerial;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LearningSnapshotsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gateway != widget.gateway) {
      requestSerial++;
      status = null;
      error = null;
      busy = false;
      _load();
    }
  }

  Future<void> _load() async {
    final serial = ++requestSerial;
    final gateway = widget.gateway;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await gateway.learningSnapshotStatus();
      if (current(serial)) setState(() => status = value);
    } catch (_) {
      if (current(serial)) {
        setState(() => error = '未能读取本机快照状态，请重试');
      }
    } finally {
      if (current(serial)) setState(() => busy = false);
    }
  }

  Future<void> _toggle(bool enabled) async {
    if (busy || error != null || status?.supported != true) return;
    final serial = ++requestSerial;
    final gateway = widget.gateway;
    // Bind consent and completion to this exact service. Lock before opening
    // the dialog so repeated switch events cannot open overlapping prompts.
    setState(() => busy = true);
    try {
      if (enabled) {
        final confirmed = await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('保存加密学习快照？'),
            content: const Text(
              '仅保存已读取的 SPOC 课程、栏目、公告列表、资料目录及测验列表。不保存文件内容、Cookie 或密码。使用 Android Keystore 加密，重启后仅在同账号已认证、原查询成功后五分钟内且网络暂不可用时作为旧数据使用。退出、清除缓存或关闭开关时删除。此安全存储接线仍待人工审查。',
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('保存加密快照'),
              ),
            ],
          ),
        );
        if (confirmed != true || !current(serial)) return;
      }
      final result = await gateway.setLearningSnapshotsEnabled(enabled);
      if (current(serial)) setState(() => status = result);
    } catch (_) {
      if (current(serial)) {
        setState(() => error = '存储设置结果未确认，请重新读取状态后再操作');
      }
    } finally {
      if (current(serial)) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MaintenanceScaffold(
    title: '加密学习快照',
    section: '数据与隐私',
    subtitle: '可选的本机保存，不增加学校查询',
    icon: CupertinoIcons.lock_shield,
    children: [
      SummaryStrip(
        items: [
          SummaryItem(
            '本机保存',
            error != null
                ? '待核对'
                : status == null
                ? '正在确认'
                : !status!.supported
                ? '平台未接入'
                : status!.enabled
                ? '已开启'
                : '已关闭',
            icon: error != null
                ? CupertinoIcons.exclamationmark_triangle
                : status == null
                ? CupertinoIcons.clock
                : !status!.supported
                ? CupertinoIcons.question_circle
                : status!.enabled
                ? CupertinoIcons.checkmark_seal
                : CupertinoIcons.lock_shield,
            tone: error != null
                ? StatusTone.uncertain
                : status == null
                ? StatusTone.pending
                : !status!.supported
                ? StatusTone.uncertain
                : status!.enabled
                ? StatusTone.success
                : StatusTone.neutral,
          ),
        ],
        note: '默认关闭；不增加学校查询，不保存账号密码。',
      ),
      AppleSection(
        header: const Text('本机加密存储'),
        children: [
          AppleListTile(
            title: const Text('保存 SPOC 学习快照'),
            subtitle: Text(
              status == null
                  ? '正在确认存储状态…'
                  : status!.supported
                  ? '默认关闭 · 原成功时间五分钟内有效'
                  : '当前平台未接入安全存储，不使用明文替代',
            ),
            trailing: CupertinoSwitch(
              value: status?.enabled ?? false,
              onChanged: !busy && error == null && status?.supported == true
                  ? _toggle
                  : null,
            ),
          ),
        ],
      ),
      if (error != null)
        AppleSection(
          children: [
            AppleListTile(title: Text(error!)),
            AppleListTile(
              title: const Text('重新读取存储状态'),
              onTap: busy ? null : _load,
            ),
          ],
        ),
      if (status?.message case final message?)
        AppleSection(
          children: [
            Padding(padding: const EdgeInsets.all(16), child: Text(message)),
            CupertinoButton(
              onPressed: busy || error != null ? null : () => _toggle(false),
              child: const Text('关闭并清除'),
            ),
          ],
        ),
      const AppleSection(
        footer: Text('这不是完整离线数据库。课表、成绩、作业与本人借阅不在本开关范围；无需保存快照也能正常查询。'),
        children: [
          AppleListTile(
            title: Text('仅使用已确认的业务数据'),
            subtitle: Text('网络失败不会刷新有效期；认证或协议异常不采用磁盘旧数据。'),
          ),
        ],
      ),
    ],
  );
}
