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
            _UptimeMatrixCard(
              health: health,
              all: all,
              authEndpoints: authEndpoints,
              publicEndpoints: publicEndpoints,
            ),
            AppleSection(
              header: const Text('实时接口可用性总览'),
              footer: const Text('使用各功能时自动被动记录真实请求状态与耗时，不额外发起后台轮询。'),
              children: [
                AppleListTile(
                  key: const Key('live-health-summary'),
                  leading: health.loadingCount > 0
                      ? const GinkgoActivity(size: GinkgoSpacing.pageInset)
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

/// Statuspage / Cloudflare–style uptime matrix bar for all monitored endpoints.
class _UptimeMatrixCard extends StatelessWidget {
  const _UptimeMatrixCard({
    required this.health,
    required this.all,
    required this.authEndpoints,
    required this.publicEndpoints,
  });

  final ServiceHealthTracker health;
  final List<EndpointHealthSnapshot> all;
  final List<EndpointHealthSnapshot> authEndpoints;
  final List<EndpointHealthSnapshot> publicEndpoints;

  static const double _hairline = 0.75;
  static const double _barHeight = 24.0;
  static const double _barGap = 3.0;
  static const double _dotSize = 9.0;

  Color _stateColor(BuildContext context, EndpointHealthSnapshot item, bool dark) {
    if (item.inFlight > 0 || item.state == EndpointHealthState.loading) {
      return CupertinoTheme.of(context).primaryColor;
    }
    return switch (item.state) {
      EndpointHealthState.healthy || EndpointHealthState.cached =>
        AppleDesign.statusSuccess.resolveFrom(context),
      EndpointHealthState.stale || EndpointHealthState.authRequired =>
        AppleDesign.statusPending.resolveFrom(context),
      EndpointHealthState.unavailable => AppleDesign.statusDanger.resolveFrom(
        context,
      ),
      EndpointHealthState.loading => CupertinoTheme.of(context).primaryColor,
      EndpointHealthState.idle => dark
          ? const Color(0xFF2B3242)
          : const Color(0xFFE0E5EE),
    };
  }

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final surface = CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);
    final border = CupertinoColors.separator
        .resolveFrom(context)
        .withValues(alpha: dark ? 0.45 : 0.35);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    final authOk = authEndpoints
        .where(
          (i) =>
              i.state == EndpointHealthState.healthy ||
              i.state == EndpointHealthState.cached,
        )
        .length;
    final publicOk = publicEndpoints
        .where(
          (i) =>
              i.state == EndpointHealthState.healthy ||
              i.state == EndpointHealthState.cached,
        )
        .length;

    final observed = health.observedCount;
    final statusColor = health.degradedCount > 0
        ? AppleDesign.statusPending.resolveFrom(context)
        : observed > 0
        ? AppleDesign.statusSuccess.resolveFrom(context)
        : CupertinoTheme.of(context).primaryColor;
    final headline = observed == 0
        ? '服务状态矩阵就绪'
        : health.degradedCount > 0
        ? '${health.degradedCount} 项接口存在异常'
        : '所有已测服务运行正常';

    return Padding(
      key: const Key('live-health-telemetry-card'),
      padding: const EdgeInsets.fromLTRB(
        GinkgoSpacing.pageInset,
        GinkgoSpacing.md,
        GinkgoSpacing.pageInset,
        GinkgoSpacing.xs,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(GinkgoRadii.group),
          border: Border.all(color: border, width: _hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(GinkgoSpacing.pageInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(width: _dotSize, height: _dotSize),
                  ),
                  const SizedBox(width: GinkgoSpacing.sm),
                  Expanded(
                    child: Text(
                      headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GinkgoTypography.headline.copyWith(
                        color: labelColor,
                      ),
                    ),
                  ),
                  Text(
                    observed == 0
                        ? '${all.length} 项监控'
                        : '${(health.healthyCount * 100 / observed).round()}%',
                    style: GinkgoTypography.footnote.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontFeatures: GinkgoTypography.tabularDigits,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GinkgoSpacing.md),
              SizedBox(
                height: _barHeight,
                child: Row(
                  children: [
                    for (var i = 0; i < all.length; i++) ...[
                      if (i > 0) const SizedBox(width: _barGap),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _stateColor(context, all[i], dark),
                            borderRadius: BorderRadius.circular(
                              GinkgoRadii.badge,
                            ),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: GinkgoSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '认证通道 $authOk/${authEndpoints.length}',
                    style: GinkgoTypography.caption2.copyWith(
                      color: secondary,
                      fontFeatures: GinkgoTypography.tabularDigits,
                    ),
                  ),
                  Text(
                    '公开直连 $publicOk/${publicEndpoints.length}',
                    style: GinkgoTypography.caption2.copyWith(
                      color: secondary,
                      fontFeatures: GinkgoTypography.tabularDigits,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
          ? const GinkgoActivity(size: GinkgoSpacing.pageInset)
          : Icon(icon, color: color, size: GinkgoSpacing.xl),
      title: Text(snapshot.endpoint.title),
      subtitle: Text(LiveServiceHealthSection._subtitle(snapshot)),
    );
  }
}
