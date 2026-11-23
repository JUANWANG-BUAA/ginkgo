import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/service_health.dart';
import 'package:ginkgo_mirror/application/session_reauth.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

/// Displays live passive telemetry recorded by [ServiceHealthTracker] across
/// all upstream school and anonymous public endpoints during the active session.
class LiveServiceHealthSection extends StatelessWidget {
  const LiveServiceHealthSection({super.key, this.tracker});

  final ServiceHealthTracker? tracker;

  static String _timeLabel(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')}';

  static String _subtitle(EndpointHealthSnapshot item) {
    if (item.inFlight > 0 || item.state == EndpointHealthState.loading) {
      return '${item.endpoint.system} · 正在请求上游…';
    }
    if (item.state == EndpointHealthState.idle) {
      return '${item.endpoint.system} · 本次会话尚未请求';
    }
    final parts = <String>[
      item.endpoint.system,
      switch (item.state) {
        EndpointHealthState.healthy => '实时可用',
        EndpointHealthState.cached => '命中缓存',
        EndpointHealthState.stale => '异常 · 已保留旧快照',
        EndpointHealthState.authRequired =>
          item.failure == null ? '需验证身份' : failureMessage(item.failure),
        EndpointHealthState.unavailable =>
          item.failure == null ? '暂不可用' : failureMessage(item.failure),
        EndpointHealthState.loading || EndpointHealthState.idle => '',
      },
      if (item.latencyMs != null) '${item.latencyMs} ms',
      if (item.updatedAt != null) _timeLabel(item.updatedAt!),
    ];
    return parts.where((part) => part.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final health = tracker ?? ServiceHealthTracker.shared;
    return ListenableBuilder(
      listenable: health,
      builder: (context, _) {
        final all = health.snapshots;
        final authEndpoints = all
            .where((item) => !item.endpoint.isPublic)
            .toList(growable: false);
        final publicEndpoints = all
            .where((item) => item.endpoint.isPublic)
            .toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppleSection(
              header: const Text('实时接口可用性总览'),
              footer: const Text('使用各功能时自动被动记录真实请求状态与耗时，不额外发起后台轮询。'),
              children: [
                AppleListTile(
                  key: const Key('live-health-summary'),
                  leading: health.loadingCount > 0
                      ? const GinkgoActivity(size: 16)
                      : Icon(
                          health.degradedCount > 0
                              ? CupertinoIcons.exclamationmark_circle_fill
                              : CupertinoIcons.waveform_path_ecg,
                          color: health.degradedCount > 0
                              ? AppleDesign.statusPending.resolveFrom(context)
                              : AppleDesign.statusSuccess.resolveFrom(context),
                        ),
                  title: Text(
                    health.observedCount == 0
                        ? '等待首次业务请求或下方主动检测'
                        : '可用 ${health.healthyCount} 项'
                              '${health.loadingCount > 0 ? ' · 请求中 ${health.loadingCount} 项' : ''}'
                              '${health.degradedCount > 0 ? ' · 异常 ${health.degradedCount} 项' : ''}',
                  ),
                  subtitle: Text(
                    health.lastUpdatedAt == null
                        ? '共监控 ${all.length} 类学校与公开接口'
                        : '最近更新：${_timeLabel(health.lastUpdatedAt!)}（本机时间）',
                  ),
                ),
                if (health.hasSessionExpired &&
                    SessionReauthScope.of(context) != null)
                  AppleListTile(
                    key: const Key('live-health-reauthenticate'),
                    leading: Icon(
                      CupertinoIcons.lock_rotation_open,
                      color: CupertinoTheme.of(context).primaryColor,
                    ),
                    title: const Text('重新登录（保留已记住密码）'),
                    subtitle: const Text('检测到学校会话已失效，返回登录页一键恢复'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => SessionReauthScope.of(context)!(),
                  ),
              ],
            ),
            AppleSection(
              header: const Text('学校认证接口（实时状态）'),
              children: [
                for (final item in authEndpoints)
                  _EndpointHealthTile(snapshot: item),
              ],
            ),
            AppleSection(
              header: const Text('公开匿名直连接口（实时状态）'),
              children: [
                for (final item in publicEndpoints)
                  _EndpointHealthTile(snapshot: item),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _EndpointHealthTile extends StatelessWidget {
  const _EndpointHealthTile({required this.snapshot});

  final EndpointHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final loading =
        snapshot.inFlight > 0 || snapshot.state == EndpointHealthState.loading;
    final color = switch (snapshot.state) {
      EndpointHealthState.healthy || EndpointHealthState.cached =>
        AppleDesign.statusSuccess.resolveFrom(context),
      EndpointHealthState.stale || EndpointHealthState.authRequired =>
        AppleDesign.statusPending.resolveFrom(context),
      EndpointHealthState.unavailable => AppleDesign.statusDanger.resolveFrom(
        context,
      ),
      EndpointHealthState.loading => CupertinoTheme.of(context).primaryColor,
      EndpointHealthState.idle => AppleDesign.statusInactive.resolveFrom(
        context,
      ),
    };
    final icon = switch (snapshot.state) {
      EndpointHealthState.healthy ||
      EndpointHealthState.cached => CupertinoIcons.checkmark_circle_fill,
      EndpointHealthState.stale ||
      EndpointHealthState.authRequired => CupertinoIcons.exclamationmark_circle,
      EndpointHealthState.unavailable => CupertinoIcons.xmark_circle_fill,
      EndpointHealthState.loading ||
      EndpointHealthState.idle => CupertinoIcons.circle,
    };

    return AppleListTile(
      key: ValueKey('live-endpoint-${snapshot.endpoint.name}'),
      leading: loading
          ? const GinkgoActivity(size: 16)
          : Icon(icon, color: color, size: 20),
      title: Text(snapshot.endpoint.title),
      subtitle: Text(LiveServiceHealthSection._subtitle(snapshot)),
    );
  }
}
