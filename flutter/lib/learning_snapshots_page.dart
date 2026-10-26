import 'package:flutter/cupertino.dart';

import 'application/query_snapshots.dart';
import 'apple_widgets.dart';
import 'maintenance_pages.dart';

class LearningSnapshotsPage extends StatefulWidget {
  const LearningSnapshotsPage({super.key, required this.gateway});
  final LearningSnapshotGateway gateway;
  @override
  State<LearningSnapshotsPage> createState() => _LearningSnapshotsPageState();
}

class _LearningSnapshotsPageState extends State<LearningSnapshotsPage> {
  LearningSnapshotStatus? status;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await widget.gateway.learningSnapshotStatus();
    if (mounted) setState(() => status = value);
  }

  Future<void> _toggle(bool enabled) async {
    if (busy) return;
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
      if (confirmed != true || !mounted) return;
    }
    setState(() => busy = true);
    try {
      final result = await widget.gateway.setLearningSnapshotsEnabled(enabled);
      if (mounted) setState(() => status = result);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MaintenanceScaffold(
    title: '加密学习快照',
    section: '数据与隐私',
    subtitle: '可选的本机保存，不增加学校查询',
    icon: CupertinoIcons.lock_shield,
    children: [
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
              onChanged: !busy && status?.supported == true ? _toggle : null,
            ),
          ),
        ],
      ),
      if (status?.message case final message?)
        AppleSection(
          children: [
            Padding(padding: const EdgeInsets.all(16), child: Text(message)),
            CupertinoButton(
              onPressed: busy ? null : () => _toggle(false),
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
