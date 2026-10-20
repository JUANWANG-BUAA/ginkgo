import 'package:flutter/cupertino.dart';

import 'apple_design.dart';
import 'apple_widgets.dart';
import 'mirror_service.dart';
import 'src/rust/api/live.dart' show RouteChoice, SessionState;

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.service,
    required this.onSignOut,
    this.accountName,
    this.accountId,
    this.route,
  });
  final MirrorService service;
  final Future<void> Function() onSignOut;
  final String? accountName;
  final String? accountId;
  final RouteChoice? route;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool busy = false;
  String? notice;

  RouteChoice get _route => widget.route ?? RouteChoice.automatic;

  String _routeLabel(RouteChoice route) => switch (route) {
    RouteChoice.automatic => '自动（直连优先，必要时 WebVPN）',
    RouteChoice.direct => '仅直连',
    RouteChoice.webVpn => '仅 WebVPN',
  };

  Future<bool> _confirm(String title, String message) async {
    final value = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    return value ?? false;
  }

  Future<void> _changeRoute(RouteChoice route) async {
    if (busy || route == _route) return;
    if (!await _confirm('切换网络路线？', '切换路线会清空当前 Cookie 并退出学校会话，需要重新登录。')) {
      return;
    }
    setState(() => busy = true);
    try {
      final response = await widget.service.setRoute(route);
      if (!mounted) return;
      setState(() => busy = false);
      if (response.state == SessionState.signedOut) {
        await widget.onSignOut();
        return;
      }
      setState(() => notice = failureMessage(response.failure));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        busy = false;
        notice = failureMessage(null);
      });
    }
  }

  Future<void> _clearCache() async {
    if (busy) return;
    if (!await _confirm('清除本机查询快照？', '只清除课表、成绩、空教室等内存快照，不删除账号。')) {
      return;
    }
    setState(() => busy = true);
    try {
      final cleared = await widget.service.clearCache();
      if (!mounted) return;
      setState(() {
        busy = false;
        notice = cleared ? '已清除本机查询快照' : failureMessage(null);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        busy = false;
        notice = failureMessage(null);
      });
    }
  }

  Future<void> _signOut() async {
    if (!await _confirm('退出登录？', '退出后会清除本机会话和已保存的密码。')) return;
    await widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      slivers: [
        const CupertinoSliverNavigationBar(
          largeTitle: Text('设置'),
          border: null,
        ),
        SliverList.list(
          children: [
            AppleSection(
              header: const Text('账号'),
              footer: const Text(
                '密码只保存在 Android Keystore 或系统钥匙串；退出登录会删除已保存凭据。',
              ),
              children: [
                AppleListTile(
                  leading: const Icon(
                    CupertinoIcons.person_crop_circle_fill,
                    color: AppleDesign.accent,
                    size: 30,
                  ),
                  title: Text(widget.accountName ?? '当前账号'),
                  subtitle: Text(widget.accountId ?? '未获取学号'),
                ),
                AppleListTile(
                  title: Text(
                    widget.service.isDemo ? '返回登录' : '退出登录',
                    style: const TextStyle(color: CupertinoColors.systemRed),
                  ),
                  onTap: busy ? null : _signOut,
                ),
              ],
            ),
            AppleSection(
              header: const Text('网络路线'),
              footer: const Text(
                '默认自动：直连优先，遇到学校访问策略时单次切换到 WebVPN。切换路线会要求重新登录。',
              ),
              children: [
                ApplePickerTile<RouteChoice>(
                  title: '路线',
                  value: _route,
                  values: RouteChoice.values,
                  label: _routeLabel,
                  enabled: !busy,
                  onSelected: _changeRoute,
                ),
              ],
            ),
            AppleSection(
              header: const Text('数据与存储'),
              children: [
                AppleListTile(
                  title: const Text('清除查询快照'),
                  subtitle: const Text('课表、成绩、今天、空教室的 5 分钟内存缓存'),
                  onTap: busy ? null : _clearCache,
                ),
              ],
            ),
            if (notice != null)
              AppleSection(
                children: [
                  AppleListTile(
                    leading: const Icon(
                      CupertinoIcons.info_circle,
                      color: AppleDesign.accent,
                      size: 20,
                    ),
                    title: Text(notice!),
                  ),
                ],
              ),
            AppleSection(
              header: const Text('关于'),
              footer: const Text(
                'Ginkgo 镜像仍在开发中；Apple 端 SwiftUI 应用继续作为产品与视觉参照。',
              ),
              children: const [
                AppleListTile(
                  title: Text('版本'),
                  additionalInfo: Text('0.1.0 镜像'),
                ),
                AppleListTile(
                  title: Text('核心'),
                  additionalInfo: Text('Rust · Flutter · FRB 2.12'),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}
