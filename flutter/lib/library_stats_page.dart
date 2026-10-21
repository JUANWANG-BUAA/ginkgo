import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'mirror_service.dart';
import 'resource_meter.dart';

/// Public counts are a snapshot, not a promise that a resource is bookable.
class LibraryStatsPage extends StatefulWidget {
  const LibraryStatsPage({super.key, required this.service});
  final MirrorService service;
  @override
  State<LibraryStatsPage> createState() => _LibraryStatsPageState();
}

class _LibraryStatsPageState extends State<LibraryStatsPage> {
  List<Map<String, dynamic>>? campuses;
  String? updatedAt;
  String? error;
  bool busy = false;
  bool fromCache = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool force = false}) async {
    // Pull-to-refresh and the toolbar share one in-flight request.
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.service.libraryStats(forceRefresh: force);
      if (!mounted) return;
      if (result.payload != null && (result.failure == null || result.stale)) {
        // Decode only when data changes, never during layout.
        final payload = jsonDecode(result.payload!) as Map<String, dynamic>;
        final items = (payload['campuses'] as List)
            .cast<Map<String, dynamic>>();
        final timestamp = payload['fetchedAt'] as String?;
        final instant = timestamp == null ? null : DateTime.tryParse(timestamp);
        final local = instant?.toUtc().add(const Duration(hours: 8));
        final formatted = local == null
            ? null
            : '${local.month}月${local.day}日 '
                  '${local.hour.toString().padLeft(2, '0')}:'
                  '${local.minute.toString().padLeft(2, '0')}（北京时间）';
        setState(() {
          campuses = items;
          updatedAt = formatted;
          fromCache = payload['fromCache'] == true;
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
          border: null,
          trailing: AppleGlassButton(
            label: '刷新公共统计',
            onPressed: busy ? null : () => load(force: true),
            child: busy
                ? const CupertinoActivityIndicator()
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
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CupertinoActivityIndicator()),
              ),
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

  Widget _campus(Map<String, dynamic> campus) => AppleSection(
    header: Semantics(header: true, child: Text(campus['name'] as String)),
    children: [
      Padding(
        key: Key('library-stats-${campus['id']}'),
        padding: const EdgeInsets.all(20),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            label: '${campus['name']}，在馆人数 ${campus['people']} 人',
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
                        text: '${campus['people']}',
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
      for (final room in campus['readingRooms'] as List)
        AppleListTile(
          title: Text(room['name'] as String),
          subtitle: Text('${room['people']} 人'),
        ),
      _metric('预约座位', '座', campus['seats']),
      _metric('研讨间', '间', campus['studyRooms']),
      _metric('寄存柜', '个', campus['lockers']),
    ],
  );

  Widget _metric(String name, String unit, dynamic pair) => ResourceMeter(
    label: name,
    unit: unit,
    available: pair?['available'] as int?,
    total: pair?['total'] as int?,
  );
}
