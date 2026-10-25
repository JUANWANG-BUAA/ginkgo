import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'loading_widgets.dart';
import 'maintenance_pages.dart';
import 'graduate_models.dart';
import 'mirror_service.dart';
import 'application/contracts.dart' as live;
import 'application/contracts.dart' show FailureCode;

typedef AcademicProbe = Future<live.ReadOnlyResponse> Function({
  required bool report,
  required bool forceRefresh,
});

/// Only aggregate counts and error codes leave a probe. Response bodies and
/// identity fields are neither retained nor included in the diagnostic UI.
class NetworkProbeResult {
  const NetworkProbeResult({
    required this.count,
    this.fromCache,
    this.stale = false,
    this.failure,
  });
  final int count;
  final bool? fromCache;
  final bool stale;
  final FailureCode? failure;
}

class NetworkProbe {
  const NetworkProbe(this.title, this.read);
  final String title;
  final Future<NetworkProbeResult> Function(bool force) read;
}

List<NetworkProbe> schoolNetworkProbes(
  MirrorService service, {
  AcademicProbe? academic,
}) {
  Future<NetworkProbeResult> graduate(bool report, bool force) async {
    final result = await (academic ?? service.graduatePart)(
      report: report,
      forceRefresh: force,
    );
    return NetworkProbeResult(
      count: graduatePayloadRowCount(result.payload),
      stale: result.stale,
      failure: result.failure,
    );
  }

  return [
    NetworkProbe('图书馆场馆', (force) async {
      final result = await service.libraryVenues(forceRefresh: force);
      return NetworkProbeResult(
        count: result.venues.length,
        fromCache: result.fromCache,
        stale: result.stale,
        failure: result.failure,
      );
    }),
    NetworkProbe('当前预约', (force) async {
      final result = await service.libraryBookings(forceRefresh: force);
      return NetworkProbeResult(
        count: result.bookings.length,
        fromCache: result.fromCache,
        stale: result.stale,
        failure: result.failure,
      );
    }),
    NetworkProbe('iclass 当天课程', (force) async {
      final result = await service.checkin(forceRefresh: force);
      return NetworkProbeResult(
        count: result.courses.length,
        fromCache: result.fromCache,
        stale: result.stale,
        failure: result.failure,
      );
    }),
    NetworkProbe('研究生学籍', (force) => graduate(false, force)),
    NetworkProbe('研究生执行报告', (force) => graduate(true, force)),
  ];
}

class NetworkDiagnosticsPage extends StatelessWidget {
  const NetworkDiagnosticsPage({super.key, required this.service});
  final MirrorService service;
  @override
  Widget build(BuildContext context) => service.isDemo
      ? const MaintenanceScaffold(
          title: '学校接口耗时',
          section: 'Ginkgo',
          subtitle: '比较当前账号的缓存与刷新等待',
          icon: CupertinoIcons.timer,
          children: [
            AppleSection(
              children: [
                AppleListTile(
                  title: Text('请先登录学校账号'),
                  subtitle: Text('离线演示不能测量学校接口耗时。'),
                ),
              ],
            ),
          ],
        )
      : SchoolNetworkChecks(probes: schoolNetworkProbes(service));
}

class _ProbeState {
  bool running = false;
  Duration? elapsed;
  NetworkProbeResult? result;
  bool unavailable = false;
}

/// Injectable checks also allow deterministic delayed-render tests without
/// school traffic. Each result is published before starting the next request.
class SchoolNetworkChecks extends StatefulWidget {
  const SchoolNetworkChecks({super.key, required this.probes});
  final List<NetworkProbe> probes;
  @override
  State<SchoolNetworkChecks> createState() => _SchoolNetworkChecksState();
}

class _SchoolNetworkChecksState extends State<SchoolNetworkChecks> {
  late List<_ProbeState> states;
  bool busy = false;
  int rounds = 0;
  bool forced = false;
  DateTime? completed;

  @override
  void initState() {
    super.initState();
    states = [for (final _ in widget.probes) _ProbeState()];
  }

  Future<void> run(bool force) async {
    if (busy) return;
    setState(() {
      busy = true;
      forced = force;
      rounds++;
      completed = null;
      states = [for (final _ in widget.probes) _ProbeState()];
    });
    for (var i = 0; i < widget.probes.length; i++) {
      if (!mounted) return;
      final state = states[i];
      setState(() => state.running = true);
      final watch = Stopwatch()..start();
      NetworkProbeResult? result;
      try {
        result = await widget.probes[i].read(force);
      } catch (_) {
        // Never expose exception text: upstream URLs can contain identity data.
      }
      watch.stop();
      if (!mounted) return;
      setState(() {
        state.running = false;
        state.elapsed = watch.elapsed;
        state.result = result;
        state.unavailable = result == null;
      });
    }
    if (mounted) {
      setState(() {
        busy = false;
        completed = DateTime.now();
      });
    }
  }

  String detail(_ProbeState state) {
    if (state.running) return '正在读取…';
    if (state.elapsed == null) return '等待检查';
    final duration = (state.elapsed!.inMilliseconds / 1000).toStringAsFixed(2);
    final result = state.result;
    if (result == null) return '$duration 秒 · 读取失败';
    return [
      '$duration 秒',
      if (result.failure != null) '错误码 ${result.failure!.name}',
      if (result.stale) '保留旧结果',
      if (result.failure == null || result.stale) '${result.count} 条',
      if (result.fromCache != null) result.fromCache! ? '命中缓存' : '本次请求结果',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) => MaintenanceScaffold(
    title: '学校接口耗时',
    section: 'Ginkgo',
    subtitle: '比较当前账号的缓存与刷新等待',
    icon: CupertinoIcons.timer,
    children: [
      AppleSection(
        footer: const Text(
          '逐项只读，不提交签到或预约。首次读取后再次读取可比较缓存耗时；强制刷新会重新请求学校。仅在本页显示耗时、条数与错误码，离开后清除。',
        ),
        children: [
          AppleListTile(
            title: Text(rounds == 0 ? '开始读取' : '再次读取'),
            subtitle: const Text('允许使用有效缓存'),
            trailing: busy && !forced
                ? const GinkgoActivity(size: 16)
                : const CupertinoListTileChevron(),
            onTap: busy ? null : () => run(false),
          ),
          AppleListTile(
            title: const Text('强制刷新并测量'),
            subtitle: const Text('忽略有效缓存，逐项回查'),
            trailing: busy && forced
                ? const GinkgoActivity(size: 16)
                : const CupertinoListTileChevron(),
            onTap: busy ? null : () => run(true),
          ),
        ],
      ),
      AppleSection(
        header: Text(
          rounds == 0 ? '检查项目' : '第 $rounds 次 · ${forced ? '强制刷新' : '普通读取'}',
        ),
        footer: completed == null
            ? null
            : Text(
                '完成于 ${completed!.hour.toString().padLeft(2, '0')}:${completed!.minute.toString().padLeft(2, '0')}（本机时间）',
              ),
        children: [
          for (var i = 0; i < states.length; i++)
            AppleListTile(
              key: ValueKey('network-probe-$i'),
              title: Text(widget.probes[i].title),
              subtitle: Text(detail(states[i])),
              leading: states[i].running
                  ? const GinkgoActivity(size: 16)
                  : Icon(
                      states[i].elapsed == null
                          ? CupertinoIcons.circle
                          : states[i].unavailable ||
                                states[i].result?.failure != null ||
                                states[i].result?.stale == true
                          ? CupertinoIcons.exclamationmark_circle
                          : CupertinoIcons.checkmark_circle_fill,
                      color: states[i].elapsed == null
                          ? CupertinoColors.secondaryLabel.resolveFrom(context)
                          : states[i].unavailable ||
                                states[i].result?.failure != null ||
                                states[i].result?.stale == true
                          ? CupertinoColors.systemOrange.resolveFrom(context)
                          : CupertinoColors.systemGreen.resolveFrom(context),
                    ),
            ),
        ],
      ),
    ],
  );
}
