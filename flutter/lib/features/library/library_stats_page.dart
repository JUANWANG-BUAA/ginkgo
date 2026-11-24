import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/library_stats.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/liquid_vial_gauge.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/widgets/resource_meter.dart';
import 'package:ginkgo_mirror/widgets/telemetry_instrument_card.dart';

/// Public counts are a snapshot, not a promise that a resource is bookable.
class LibraryStatsPage extends StatefulWidget {
  const LibraryStatsPage({super.key, required this.service});
  final LibrarySeatingGateway service;
  @override
  State<LibraryStatsPage> createState() => _LibraryStatsPageState();
}

class _LibraryStatsSnapshot {
  const _LibraryStatsSnapshot(this.campuses, this.updatedAt, this.fromCache);
  final List<LibraryCampusStats> campuses;
  final String? updatedAt;
  final bool fromCache;
}

class _LibraryStatsPageState extends State<LibraryStatsPage> {
  late final RefreshSection<_LibraryStatsSnapshot> section;
  List<LibraryCampusStats>? get campuses => section.value?.campuses;
  String? get updatedAt => section.value?.updatedAt;
  String? get error => section.error;
  bool get busy => section.loading;
  bool get fromCache => section.value?.fromCache ?? false;

  @override
  void initState() {
    super.initState();
    section = RefreshSection<_LibraryStatsSnapshot>()
      ..addListener(() {
        if (mounted) setState(() {});
      });
    load();
  }

  @override
  void didUpdateWidget(LibraryStatsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      section
        ..invalidate()
        ..value = null
        ..error = null
        ..loading = false;
      load();
    }
  }

  @override
  void dispose() {
    section.dispose();
    super.dispose();
  }

  Future<void> load({bool force = false}) {
    final service = widget.service;
    return section.refresh(
      () async {
        final result = await service.libraryStats(forceRefresh: force);
        var next = section.value;
        final snapshot = result.data;
        if (snapshot != null) {
          final instant = snapshot.fetchedAt == null
              ? null
              : DateTime.tryParse(snapshot.fetchedAt!);
          final local = instant == null ? null : todaySchoolNow(instant);
          final formatted = local == null
              ? null
              : '${local.month}月${local.day}日 '
                    '${local.hour.toString().padLeft(2, '0')}:'
                    '${local.minute.toString().padLeft(2, '0')}（北京时间）';
          next = _LibraryStatsSnapshot(
            snapshot.campuses,
            formatted,
            snapshot.fromCache,
          );
        }
        return SectionResult(
          value: next,
          error: result.failure != null
              ? failureMessage(result.failure)
              : next == null
              ? '官网数据暂未读取到'
              : null,
        );
      },
      fallbackError: failureMessage(null),
      force: force,
    );
  }

  static const EdgeInsets _captionPadding = EdgeInsets.fromLTRB(
    GinkgoSpacing.xxl,
    GinkgoSpacing.base,
    GinkgoSpacing.xxl,
    0,
  );
  static const EdgeInsets _disclaimerPadding = EdgeInsets.fromLTRB(
    GinkgoSpacing.xxl,
    GinkgoSpacing.xl,
    GinkgoSpacing.xxl,
    GinkgoSpacing.xxl,
  );

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: SafeArea(
      child: CustomScrollView(
        key: const Key('library-stats-scroll'),
        slivers: [
          AppleRefreshPageHeader(
            title: '在馆与空间',
            subtitle: '学院路 · 沙河在馆人数与空间余量',
            icon: CupertinoIcons.person_2_fill,
            refreshLabel: '刷新公共统计',
            busy: busy,
            onRefresh: () => load(force: true),
          ),
          CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
          SliverList.list(
            children: [
              Padding(
                padding: _captionPadding,
                child: Text(
                  widget.service.isDemo
                      ? '离线合成样例 · 不代表当前人数'
                      : updatedAt == null
                      ? '图书馆官网公开信息'
                      : '更新于 $updatedAt${fromCache ? ' · 缓存' : ''}',
                  style: GinkgoTypography.footnote.copyWith(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
              if (error != null)
                AppleStatusSection(
                  title: error!,
                  description: campuses == null
                      ? '公开信息无需预约登录，请稍后重试。'
                      : '刷新未成功，保留上次人数与实际更新时间。',
                  error: true,
                  action: '重试',
                  onAction: busy ? null : () => load(force: true),
                ),
              if (campuses == null && busy)
                const GinkgoLoadingView(label: '正在读取在馆数据…'),
              if (campuses case final items?)
                for (final campus in items) _campus(campus),
              Padding(
                padding: _disclaimerPadding,
                child: Text(
                  '人数与空间余量由图书馆官网提供，可能存在更新延迟。空闲不代表一定可预约，请以预约系统为准。',
                  style: GinkgoTypography.footnote.copyWith(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: GinkgoSpacing.bottomScrollClearance),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _campus(LibraryCampusStats campus) {
    final seatFree = campus.seats?.available;
    final seatTotal = campus.seats?.total;
    final hasSeats = seatFree != null && seatTotal != null && seatTotal > 0;
    final occupiedRatio = hasSeats
        ? ((seatTotal - seatFree) / seatTotal).clamp(0.0, 1.0)
        : null;
    final occPct = occupiedRatio == null ? null : (occupiedRatio * 100).round();
    final maxRoomPeople = campus.readingRooms.fold<int>(
      1,
      (prev, r) => r.people > prev ? r.people : prev,
    );

    return AppleSection(
      header: Semantics(header: true, child: Text(campus.name)),
      children: [
        Padding(
          key: Key('library-stats-${campus.id}'),
          padding: GinkgoSpacing.edgeInsetsCard,
          child: Semantics(
            label: '${campus.name}，在馆人数 ${campus.people} 人',
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                LiquidVialWell(
                  code: 'LIB',
                  readout: occPct != null ? '$occPct%' : '${campus.people}人',
                  fillRatio: occupiedRatio,
                  palette: occupiedRatio != null && occupiedRatio >= 0.85
                      ? LiquidPalette.amber
                      : LiquidPalette.cobalt,
                  scaleTicks: hasSeats
                      ? [
                          '- ${(seatTotal * 0.75).round()}',
                          '- ${(seatTotal * 0.50).round()}',
                          '- ${(seatTotal * 0.25).round()}',
                        ]
                      : const ['- 75%', '- 50%', '- 25%'],
                  footer: hasSeats ? '座位占用率' : '实时在馆',
                ),
                const SizedBox(width: GinkgoSpacing.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '实时在馆人数',
                        style: GinkgoTypography.callout.copyWith(
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                      const SizedBox(height: GinkgoSpacing.small),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${campus.people}',
                              style: GinkgoTypography.largeTitle.copyWith(
                                fontWeight: FontWeight.w700,
                                fontFeatures: GinkgoTypography.tabularDigits,
                                color: CupertinoColors.label.resolveFrom(
                                  context,
                                ),
                              ),
                            ),
                            TextSpan(
                              text: ' 人',
                              style: GinkgoTypography.headline.copyWith(
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasSeats) ...[
                        const SizedBox(height: GinkgoSpacing.sm),
                        SegmentedCapsuleBar(
                          segments: [
                            BarSegment(
                              fraction: occupiedRatio!,
                              startColor: const Color(0xFF1D4ED8),
                              endColor: const Color(0xFF38BDF8),
                            ),
                          ],
                        ),
                        const SizedBox(height: GinkgoSpacing.xs),
                        Text(
                          '空闲座位 $seatFree / $seatTotal 座',
                          style: GinkgoTypography.caption.copyWith(
                            fontFeatures: GinkgoTypography.tabularDigits,
                            color: CupertinoColors.secondaryLabel.resolveFrom(
                              context,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final room in campus.readingRooms)
          AppleListTile(
            title: Text(room.name),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: GinkgoSpacing.xs),
              child: SegmentedCapsuleBar(
                height: 5.5,
                segments: [
                  BarSegment(
                    fraction: (room.people / maxRoomPeople).clamp(0.0, 1.0),
                    startColor: const Color(0xFF0D9488),
                    endColor: const Color(0xFF5EEAD4),
                  ),
                ],
              ),
            ),
            trailing: Text(
              '${room.people} 人',
              style: GinkgoTypography.footnote.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: GinkgoTypography.tabularDigits,
              ),
            ),
          ),
        _metric('预约座位', '座', campus.seats),
        _metric('研讨间', '间', campus.studyRooms),
        _metric('寄存柜', '个', campus.lockers),
      ],
    );
  }

  Widget _metric(String name, String unit, CountPair? pair) => ResourceMeter(
    label: name,
    unit: unit,
    available: pair?.available,
    total: pair?.total,
  );
}
