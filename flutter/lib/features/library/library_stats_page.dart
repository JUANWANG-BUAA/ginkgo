import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/features/library/library_stats_models.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/widgets/resource_meter.dart';

/// Public counts are a snapshot, not a promise that a resource is bookable.
class LibraryStatsPage extends StatefulWidget {
  const LibraryStatsPage({super.key, required this.service});
  final LibraryGateway service;
  @override
  State<LibraryStatsPage> createState() => _LibraryStatsPageState();
}

class _LibraryStatsPageState extends State<LibraryStatsPage> {
  List<LibraryCampusStats>? campuses;
  String? updatedAt;
  String? error;
  bool busy = false;
  bool fromCache = false;
  bool _pendingRefresh = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool force = false}) async {
    // Pull-to-refresh and the toolbar share one in-flight request; a refresh
    // that arrives mid-flight is remembered and rerun, never dropped.
    if (busy) {
      if (force) _pendingRefresh = true;
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.service.libraryStats(forceRefresh: force);
      if (!mounted) return;
      if (result.payload != null && (result.failure == null || result.stale)) {
        // Decode only when data changes, never during layout.
        final snapshot = libraryStats(result.payload!);
        final items = snapshot.campuses;
        final instant = snapshot.fetchedAt == null
            ? null
            : DateTime.tryParse(snapshot.fetchedAt!);
        final local = instant?.toUtc().add(const Duration(hours: 8));
        final formatted = local == null
            ? null
            : '${local.month}月${local.day}日 '
                  '${local.hour.toString().padLeft(2, '0')}:'
                  '${local.minute.toString().padLeft(2, '0')}（北京时间）';
        setState(() {
          campuses = items;
          updatedAt = formatted;
          fromCache = snapshot.fromCache;
        });
      }
      setState(() {
        error = result.failure != null
            ? failureMessage(result.failure)
            : campuses == null
            ? '官网数据暂未读取到'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => error = failureMessage(null));
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (!mounted) return;
    if (_pendingRefresh) {
      _pendingRefresh = false;
      await load(force: true);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('library-stats-scroll'),
      slivers: [
        ApplePageHeader(
          largeTitle: const Text('在馆与空间'),
          section: '空间资源',
          subtitle: '学院路 · 沙河在馆人数与空间余量',
          icon: CupertinoIcons.person_2_fill,
          border: null,
          trailing: AppleGlassButton(
            label: '刷新公共统计',
            onPressed: busy ? null : () => load(force: true),
            child: busy
                ? const GinkgoActivity(size: 17)
                : const Icon(CupertinoIcons.refresh),
          ),
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
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: error!,
                    description: campuses == null
                        ? '公开信息无需预约登录，请稍后重试。'
                        : '刷新未成功，保留上次人数与实际更新时间。',
                    error: true,
                    action: '重试',
                    onAction: busy ? null : () => load(force: true),
                  ),
                ],
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
