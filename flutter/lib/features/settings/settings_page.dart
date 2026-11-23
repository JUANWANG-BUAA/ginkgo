import 'gateway_challenge_page.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';
import 'package:ginkgo_mirror/widgets/verified_route_label.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/maintenance.dart';
import 'package:ginkgo_mirror/features/settings/maintenance_pages.dart';
import 'package:ginkgo_mirror/features/settings/network_diagnostics_page.dart';
import 'package:ginkgo_mirror/shared/query_cache_scope.dart';
import 'package:ginkgo_mirror/application/query_snapshots.dart';
import 'package:ginkgo_mirror/application/service_capabilities.dart';
import 'package:ginkgo_mirror/application/service_health.dart';
import 'package:ginkgo_mirror/application/session_reauth.dart';
import 'package:ginkgo_mirror/features/learning/learning_snapshots_page.dart';
import 'package:ginkgo_mirror/features/settings/preferences_pages.dart';
import 'package:ginkgo_mirror/application/contracts.dart'
    show FailureCode, RouteChoice;

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.service,
    required this.onSignOut,
    this.accountName,
    this.accountId,
    this.route,
    required this.maintenance,
  });
  final MirrorService service;

  /// The self-check and update capability. It is absent when the app was
  /// started without the platform binding, and the entries that need it are
  /// then hidden instead of failing.
  final MaintenanceService? maintenance;
  final Future<void> Function() onSignOut;
  final String? accountName;
  final String? accountId;
  final RouteChoice? route;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool clearingCache = false;
  bool signingOut = false;
  String? notice;
  bool changingRoute = false;
  String? routeNotice;
  String versionLabel = '读取中…';
  int routeRevision = 0;

  bool get busy => clearingCache || signingOut || changingRoute;

  late ServiceCapabilities capabilities = ServiceCapabilities.resolve(
    widget.service,
  );
  LearningSnapshotGateway? get snapshotGateway =>
      capabilities.learningSnapshots;

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      capabilities = ServiceCapabilities.resolve(widget.service);
      notice = null;
      routeNotice = null;
      changingRoute = false;
      clearingCache = false;
      signingOut = false;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.maintenance
        ?.version()
        .then((value) {
          if (mounted) setState(() => versionLabel = value.label);
        })
        .catchError((Object _) {
          if (mounted) setState(() => versionLabel = '暂时无法读取');
        });
  }

  void _open(Widget page) {
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));
  }

  RouteChoice get _route => switch (AppPreferencesScope.of(context).routeMode) {
    'direct' => RouteChoice.direct,
    'webVpn' => RouteChoice.webVpn,
    'automatic' => RouteChoice.automatic,
    _ => widget.route ?? RouteChoice.automatic,
  };

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
    final gateway = capabilities.verifiedRoute;
    if (gateway == null) return;
    final service = widget.service;
    final preferences = AppPreferencesScope.of(context);
    setState(() {
      changingRoute = true;
      routeNotice = null;
    });
    try {
      final failure = await gateway.switchVerifiedRoute(route);
      if (!mounted || widget.service != service) return;
      if (failure != null) {
        setState(
          () => routeNotice = switch (failure) {
            FailureCode.moduleAuthRequired => '目标路线尚未验证，已保留当前路线和登录。',
            _ => failureMessage(failure),
          },
        );
        return;
      }
      await preferences.setRouteMode(route.name);
      if (!mounted || widget.service != service) return;
      setState(() {
        routeRevision++;
        routeNotice = preferences.writeError ?? '网络路线已更新';
      });
    } catch (_) {
      if (!mounted || widget.service != service) return;
      setState(() {
        routeNotice = failureMessage(null);
      });
    } finally {
      if (mounted && widget.service == service) {
        setState(() => changingRoute = false);
      }
    }
  }

  Future<void> _clearCache() async {
    if (clearingCache || signingOut) return;
    if (!await _confirm(
      '清除本机查询快照？',
      '清除查询快照与已打开页面的旧结果，然后返回工作台重新读取。账号和本地待办会保留。',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => clearingCache = true);
    try {
      final cleared = await widget.service.clearCache();
      if (!mounted) return;
      setState(() {
        clearingCache = false;
        notice = cleared ? '已清除本机查询快照' : failureMessage(null);
      });
      if (cleared) QueryCacheScope.invalidate(context);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        clearingCache = false;
        notice = failureMessage(null);
      });
    }
  }

  Future<void> _signOut() async {
    if (signingOut) return;
    if (!await _confirm('退出登录？', '退出后会清除本机会话和已保存的密码。')) return;
    if (!mounted) return;
    setState(() => signingOut = true);
    try {
      await widget.onSignOut();
    } catch (_) {
      if (mounted) setState(() => notice = '退出未完成，请重试');
    } finally {
      if (mounted) setState(() => signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: SafeArea(
      child: CustomScrollView(
        key: const Key("settings-scroll"),
        slivers: [
          const ApplePageHeader(
            largeTitle: Text('设置'),
            border: null,
            section: 'Ginkgo',
            subtitle: '管理账号、显示偏好与系统设置',
            icon: CupertinoIcons.gear_alt,
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
                  if (!widget.service.isDemo &&
                      SessionReauthScope.of(context) != null)
                    AppleListTile(
                      key: const Key('settings-reauthenticate'),
                      title: const Text('重新登录（保留已记住密码）'),
                      subtitle: const Text('会话过期或需要验证码时使用，不删除已保存密码'),
                      trailing: const CupertinoListTileChevron(),
                      onTap: signingOut
                          ? null
                          : () => SessionReauthScope.of(context)!(
                              reason: '请核对已保存的账号密码并重新登录。',
                            ),
                    ),
                  AppleListTile(
                    key: const Key('settings-sign-out'),
                    title: Text(
                      widget.service.isDemo ? '返回登录' : '退出登录',
                      style: const TextStyle(color: CupertinoColors.systemRed),
                    ),
                    trailing: signingOut
                        ? const GinkgoActivity(size: 16)
                        : null,
                    onTap: signingOut ? null : _signOut,
                  ),
                ],
              ),
              AppleSection(
                header: const Text('偏好与系统'),
                children: [
                  AppleListTile(
                    leading: const Icon(
                      CupertinoIcons.paintbrush,
                      color: AppleDesign.resourcePurple,
                    ),
                    title: const Text('显示与阅读'),
                    subtitle: Text(
                      AppPreferencesScope.of(context).appearance.label,
                    ),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _open(const AppearancePage()),
                  ),
                  AppleListTile(
                    leading: const Icon(
                      CupertinoIcons.bell,
                      color: AppleDesign.resourceBlue,
                    ),
                    title: const Text('通知与后台'),
                    subtitle: const Text('通知权限、系统启动与电池管理'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _open(const SystemPreferencesPage()),
                  ),
                  AppleListTile(
                    leading: const Icon(
                      CupertinoIcons.lock_shield,
                      color: AppleDesign.accent,
                    ),
                    title: const Text('账号与隐私'),
                    subtitle: const Text('自动登录、本机数据与请求去向'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _open(const PrivacyPage()),
                  ),
                ],
              ),
              AppleSection(
                header: const Text('网络路线'),
                footer: const Text('显示最近验证成功的路线，不代表网络实时在线。切换失败不会退出账号。'),
                children: [
                  if (capabilities.verifiedRoute case final gateway?)
                    AppleListTile(
                      title: const Text('学校会话路线'),
                      subtitle: VerifiedRouteLabel(
                        gateway: gateway,
                        revision: routeRevision,
                      ),
                    ),
                  if (capabilities.gatewayVerification case final gateway?)
                    AppleListTile(
                      title: const Text('WebVPN 验证'),
                      subtitle: const Text('查看并完成学校网关的验证码'),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () =>
                          _open(GatewayChallengePage(gateway: gateway)),
                    ),
                  ApplePickerTile<RouteChoice>(
                    title: '路线',
                    value: _route,
                    values: RouteChoice.values,
                    label: _routeLabel,
                    enabled: !busy && capabilities.verifiedRoute != null,
                    onSelected: _changeRoute,
                  ),
                  if (changingRoute || routeNotice != null)
                    AppleListTile(
                      leading: changingRoute
                          ? const GinkgoActivity(size: 16)
                          : const Icon(CupertinoIcons.info_circle, size: 20),
                      title: Semantics(
                        liveRegion: true,
                        child: Text(
                          changingRoute
                              ? '正在验证目标路线，当前登录会保留…'
                              : routeNotice!,
                        ),
                      ),
                    ),
                ],
              ),
              AppleSection(
                header: const Text('数据与存储'),
                footer: const Text('查询结果 5 分钟内复用，刷新失败时保留旧结果。'),
                children: [
                  if (!kReleaseMode && snapshotGateway != null)
                    AppleListTile(
                      leading: const Icon(CupertinoIcons.lock_shield),
                      trailing: const CupertinoListTileChevron(),
                      title: const Text('加密学习快照'),
                      subtitle: const Text('默认关闭 · 仅限 Android 本机保存'),
                      onTap: () => _open(
                        LearningSnapshotsPage(gateway: snapshotGateway!),
                      ),
                    ),
                  AppleListTile(
                    leading: const Icon(
                      CupertinoIcons.trash,
                      color: CupertinoColors.systemOrange,
                    ),
                    trailing: clearingCache
                        ? const GinkgoActivity(size: 16)
                        : const CupertinoListTileChevron(),
                    title: const Text('清除查询快照'),
                    subtitle: const Text('清除已读取的学校数据，不影响个人待办'),
                    onTap: clearingCache || signingOut ? null : _clearCache,
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
                header: const Text('支持与更新'),
                children: [
                  if (widget.maintenance != null)
                    AppleListTile(
                      leading: const Icon(
                        CupertinoIcons.checkmark_shield,
                        color: AppleDesign.accent,
                      ),
                      title: const Text('运行自检'),
                      subtitle: const Text('组件、存储与公开服务连通性'),
                      trailing: const CupertinoListTileChevron(),
                      onTap: busy
                          ? null
                          : () => _open(
                              DiagnosticsPage(
                                service: widget.maintenance!,
                                mirror: widget.service,
                              ),
                            ),
                    ),
                  ListenableBuilder(
                    listenable: ServiceHealthTracker.shared,
                    builder: (context, _) {
                      final tracker = ServiceHealthTracker.shared;
                      final summary = tracker.observedCount == 0
                          ? '实时查看各业务接口可用性、缓存与响应耗时'
                          : '已观测 ${tracker.healthyCount} 项可用'
                                '${tracker.degradedCount > 0 ? ' · ${tracker.degradedCount} 项异常' : ''}';
                      return AppleListTile(
                        leading: const Icon(
                          CupertinoIcons.timer,
                          color: AppleDesign.accent,
                        ),
                        title: const Text('学校接口耗时'),
                        subtitle: Text(summary),
                        trailing: const CupertinoListTileChevron(),
                        onTap: signingOut
                            ? null
                            : () => _open(
                                NetworkDiagnosticsPage(service: widget.service),
                              ),
                      );
                    },
                  ),
                  if (widget.maintenance != null)
                    AppleListTile(
                      leading: const Icon(
                        CupertinoIcons.arrow_down_circle,
                        color: AppleDesign.accent,
                      ),
                      title: const Text('软件更新'),
                      subtitle: const Text('检查 Android 发布与更新说明'),
                      trailing: const CupertinoListTileChevron(),
                      onTap: busy
                          ? null
                          : () => _open(
                              SoftwareUpdatePage(service: widget.maintenance!),
                            ),
                    ),
                ],
              ),
              AppleSection(
                header: const Text('关于 Ginkgo'),
                footer: const Text('北航校园工作台 · 校园日常，从容有序'),
                children: [
                  AppleListTile(
                    title: const Text('版本'),
                    subtitle: Text(versionLabel),
                  ),
                  AppleListTile(
                    title: const Text('关于与致谢'),
                    subtitle: const Text('UBAA、开源项目与分享 Ginkgo'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _open(const AboutPage()),
                  ),
                ],
              ),
              const SizedBox(height: 96),
            ],
          ),
        ],
      ),
    ),
  );
}
