import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/widgets/resource_meter.dart';

import 'package:ginkgo_mirror/application/library_stats.dart';

import 'package:ginkgo_mirror/shared/today_time.dart';

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
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
              child: Text(
                widget.service.isDemo
                    ? '离线合成样例 · 不代表当前人数'
                    : updatedAt == null
                    ? '图书馆官网公开信息'
                    : '更新于 $updatedAt${fromCache ? ' · 缓存' : ''}',
                style: TextStyle(
                  fontSize: 13,
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
              padding: const EdgeInsets.fromLTRB(32, 20, 32, 32),
              child: Text(
                '人数与空间余量由图书馆官网提供，可能存在更新延迟。空闲不代表一定可预约，请以预约系统为准。',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 64),
          ],
        ),
      ],
    )
    ),
  );

  Widget _campus(LibraryCampusStats campus) => AppleSection(
    header: Semantics(header: true, child: Text(campus.name)),
    children: [
      Padding(
        key: Key('library-stats-${campus.id}'),
        padding: const EdgeInsets.all(20),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            label: '${campus.name}，在馆人数 ${campus.people} 人',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('在馆人数', style: TextStyle(fontSize: 15)),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${campus.people}',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1,
                        ),
                      ),
                      const TextSpan(
                        text: ' 人',
                        style: TextStyle(fontSize: 17),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      for (final room in campus.readingRooms)
        AppleListTile(
          title: Text(room.name),
          subtitle: Text('${room.people} 人'),
        ),
      _metric('预约座位', '座', campus.seats),
      _metric('研讨间', '间', campus.studyRooms),
      _metric('寄存柜', '个', campus.lockers),
    ],
  );

  Widget _metric(String name, String unit, CountPair? pair) => ResourceMeter(
    label: name,
    unit: unit,
    available: pair?.available,
    total: pair?.total,
  );
}
