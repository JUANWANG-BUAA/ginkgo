import 'package:flutter/cupertino.dart';

import 'apple_design.dart';
import 'apple_widgets.dart';
import 'mirror_service.dart';
import 'query_cache_scope.dart';
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
    if (!await _confirm(
      '清除本机查询快照？',
      '清除查询快照与已打开页面的旧结果，然后返回工作台重新读取。账号和本地待办会保留。',
    )) {
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
      if (cleared) QueryCacheScope.invalidate(context);
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
              footer: const Text('已记住的密码保存在系统安全存储中，退出登录会删除。'),
              children: [
                AppleListTile(
                  leading: const Icon(
                    CupertinoIcons.person_crop_circle_fill,
                    color: AppleDesign.accent,
                    size: 30,
                  ),
                  title: Text(
                    widget.service.isDemo
                        ? '离线演示'
                        : widget.accountName ?? '当前账号',
                  ),
                  subtitle: Text(
                    widget.service.isDemo
                        ? '演示数据不会连接学校账号'
                        : widget.accountId ?? '学校统一身份认证',
                  ),
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
                  subtitle: const Text('清除已读取的学校数据，不影响个人待办'),
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
              footer: const Text('Ginkgo 银杏 · 校园学习与生活'),
              children: const [
                AppleListTile(
                  title: Text('版本'),
                  additionalInfo: Text('0.1.0 镜像'),
                ),
              ],
            ),
            const SizedBox(height: 96),
          ],
        ),
      ],
    ),
  );
}
