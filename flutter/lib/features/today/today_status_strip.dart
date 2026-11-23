import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/service_health.dart';
import 'package:ginkgo_mirror/application/session_reauth.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/widgets/verified_route_label.dart';

/// Compact single-line status bar at the top of TodayPage: keeps next-course
/// and first-deadline above the fold on compact phones while surfacing active
/// sync progress, verified route and one-tap live endpoint status.
class TodayStatusStrip extends StatelessWidget {
  const TodayStatusStrip({
    super.key,
    required this.demo,
    required this.loadingLabels,
    required this.readySections,
    required this.errorSections,
    required this.routeRevision,
    this.verifiedRoute,
    this.tracker,
    this.onOpenDiagnostics,
  });

  final bool demo;
  final List<String> loadingLabels;
  final int readySections;
  final int errorSections;
  final int routeRevision;
  final VerifiedRouteGateway? verifiedRoute;
  final ServiceHealthTracker? tracker;
  final VoidCallback? onOpenDiagnostics;

  @override
  Widget build(BuildContext context) {
    final health = tracker ?? ServiceHealthTracker.shared;
    final reauth = SessionReauthScope.of(context);
    return ListenableBuilder(
      listenable: health,
      builder: (context, _) {
        final inFlightNames = <String>{
          ...loadingLabels,
          for (final item in health.loadingSnapshots) item.endpoint.title,
        }.toList(growable: false);
        final isSyncing = inFlightNames.isNotEmpty;
        final sessionExpired = !isSyncing && health.hasSessionExpired;
        final issues = errorSections > health.degradedCount
            ? errorSections
            : health.degradedCount;
        final healthy = health.healthyCount > readySections
            ? health.healthyCount
            : readySections;

        final (icon, color, headline) = isSyncing
            ? (
                null,
                CupertinoTheme.of(context).primaryColor,
                '正在同步 ${inFlightNames.first}'
                    '${inFlightNames.length > 1 ? ' 等 ${inFlightNames.length} 项' : ''}…',
              )
            : sessionExpired && reauth != null
            ? (
                CupertinoIcons.lock_rotation_open,
                AppleDesign.statusDanger.resolveFrom(context),
                '学校会话已失效，点此重新登录',
              )
            : issues > 0
            ? (
                CupertinoIcons.exclamationmark_circle_fill,
                AppleDesign.statusPending.resolveFrom(context),
                '$healthy 项可用 · $issues 项接口异常',
              )
            : (
                CupertinoIcons.checkmark_circle_fill,
                AppleDesign.statusSuccess.resolveFrom(context),
                demo
                    ? '离线演示已就绪'
                    : healthy > 0
                    ? '接口正常 ($healthy)'
                    : '工作台已就绪',
              );

        final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
        final primaryTap = sessionExpired && reauth != null
            ? () => reauth()
            : onOpenDiagnostics;
        final trailingLabel = sessionExpired && reauth != null
            ? '重新登录'
            : onOpenDiagnostics != null
            ? '接口状态'
            : null;
        return Padding(
          padding: GinkgoSpacing.edgeInsetsPage,
          child: GestureDetector(
            key: const Key('today-open-diagnostics'),
            behavior: HitTestBehavior.opaque,
            onTap: primaryTap,
            child: Padding(
              padding: GinkgoSpacing.edgeInsetsPickerTitle,
              child: Row(
                children: [
                  if (isSyncing)
                    const GinkgoActivity(size: 14)
                  else
                    Icon(icon, color: color, size: 15),
                  const SizedBox(width: GinkgoSpacing.small),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: DefaultTextStyle(
                        style: GinkgoTypography.footnote.copyWith(
                          color: secondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                headline,
                                style: GinkgoTypography.footnote.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: issues > 0 || sessionExpired
                                      ? color
                                      : CupertinoColors.label.resolveFrom(
                                          context,
                                        ),
                                ),
                              ),
                            ),
                            if (verifiedRoute != null) ...[
                              Text(' · ', style: TextStyle(color: secondary)),
                              Flexible(
                                child: VerifiedRouteLabel(
                                  gateway: verifiedRoute!,
                                  revision: routeRevision,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (trailingLabel != null) ...[
                    const SizedBox(width: GinkgoSpacing.sm),
                    Text(
                      trailingLabel,
                      style: GinkgoTypography.footnote.copyWith(
                        color: CupertinoTheme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      CupertinoIcons.chevron_forward,
                      size: 13,
                      color: CupertinoTheme.of(context).primaryColor,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
