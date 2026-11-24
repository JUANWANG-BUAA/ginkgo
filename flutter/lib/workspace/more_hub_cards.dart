import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/service_health.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';

/// Tactile two-card control hub at the top of MorePage:
/// Account & Settings card + Live API Health status card.
class MoreControlHub extends StatelessWidget {
  const MoreControlHub({
    super.key,
    required this.demo,
    required this.onOpenSettings,
    required this.onOpenDiagnostics,
    this.accountName,
    this.accountId,
  });

  final bool demo;
  final String? accountName;
  final String? accountId;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenDiagnostics;

  @override
  Widget build(BuildContext context) {
    final accountSubtitle = demo
        ? '离线演示 · 外观、隐私与返回登录'
        : '${accountName ?? accountId ?? '当前账号'} · 外观、路线与退出登录';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GinkgoSpacing.pageInset,
        GinkgoSpacing.sm,
        GinkgoSpacing.pageInset,
        GinkgoSpacing.xs,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 330 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.4;
          final accountCard = _HubCard(
            key: const Key('more-account-settings'),
            icon: CupertinoIcons.person_crop_circle_fill,
            color: GinkgoColors.accent,
            title: '账号与设置',
            subtitle: accountSubtitle,
            badgeText: demo ? '演示' : '已登录',
            onTap: onOpenSettings,
          );
          final healthCard = ListenableBuilder(
            listenable: ServiceHealthTracker.shared,
            builder: (context, _) {
              final health = ServiceHealthTracker.shared;
              final observed = health.observedCount;
              final degraded = health.degradedCount;
              final badge = observed == 0
                  ? '待测'
                  : degraded > 0
                  ? '$degraded 异常'
                  : '${health.healthyCount} 可用';
              final tint = degraded > 0
                  ? AppleDesign.statusPending.resolveFrom(context)
                  : observed > 0
                  ? AppleDesign.statusSuccess.resolveFrom(context)
                  : GinkgoColors.resourceBlue;
              return _HubCard(
                key: const Key('more-network-status'),
                icon: CupertinoIcons.waveform_path_ecg,
                color: tint,
                title: '实时接口状态',
                subtitle: observed == 0
                    ? '查看各业务模块可用性、缓存与响应耗时'
                    : '已观测 $observed 项 · 可用 ${health.healthyCount} 项',
                badgeText: badge,
                onTap: onOpenDiagnostics,
              );
            },
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                accountCard,
                const SizedBox(height: GinkgoSpacing.sm),
                healthCard,
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: accountCard),
                const SizedBox(width: GinkgoSpacing.sm),
                Expanded(child: healthCard),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String badgeText;
  final VoidCallback onTap;

  static const double _iconSize = 34.0;
  static const double _minHeight = 96.0;
  static const double _minTouchTarget = 48.0;
  static const double _hairline = 0.75;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final surface = CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);
    final label = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final border = color.withValues(alpha: dark ? 0.3 : 0.2);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(_minTouchTarget, _minHeight),
      onPressed: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(GinkgoRadii.group),
          border: Border.all(color: border, width: _hairline),
          boxShadow: dark
              ? null
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.08),
                    blurRadius: GinkgoSpacing.md,
                    offset: const Offset(0, GinkgoSpacing.xs),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(GinkgoSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GinkgoIconTile(icon: icon, size: _iconSize, color: color),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: dark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(GinkgoRadii.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: GinkgoSpacing.sm,
                        vertical: GinkgoSpacing.xs,
                      ),
                      child: Text(
                        badgeText,
                        style: GinkgoTypography.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GinkgoSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GinkgoTypography.headline.copyWith(color: label),
                  ),
                  const SizedBox(height: GinkgoSpacing.xs),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GinkgoTypography.caption.copyWith(color: secondary),
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
