import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:url_launcher/url_launcher.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/features/shuttle/shuttle_models.dart';
import 'package:ginkgo_mirror/features/today/today_presentation.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';

/// Official shuttle timetable. Only the published page is shown: the app does
/// not guess live seat counts and never proxies ticketing.
class ShuttlePage extends StatefulWidget {
  const ShuttlePage({super.key, required this.service, this.now});
  final MirrorService service;

  /// Beijing wall time used by the first-screen plan; tests inject it so the
  /// selection never depends on the device clock or timezone.
  final DateTime? now;
  @override
  State<ShuttlePage> createState() => _ShuttlePageState();
}

class _ShuttlePageState extends State<ShuttlePage> with WidgetsBindingObserver {
  ShuttleTimetable? timetable;
  String source = '';
  String? error;
  bool busy = false;
  int _generation = 0;
  bool _pendingReload = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startClock();
    load();
  }

  /// The first-screen plan is derived from the wall clock, so it must advance
  /// while the page stays open across a departure minute. Local recompute
  /// only: no timer-driven school requests.
  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && TickerMode.valuesOf(context).enabled) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startClock();
      if (mounted) setState(() {});
    } else {
      _clock?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ShuttlePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.service, widget.service)) {
      timetable = null;
      source = '';
      error = null;
      busy = false;
      _pendingReload = false;
      load();
    }
  }

  Future<void> load() async {
    // A reload request during an in-flight read is remembered and rerun once
    // it settles, never silently dropped.
    if (busy) {
      _pendingReload = true;
      return;
    }
    final generation = ++_generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.service.shuttleTimetable();
      if (!mounted || generation != _generation) return;
      if (result.payload != null && result.failure == null) {
        final decoded = shuttleTimetable(result.payload!);
        setState(() {
          timetable = decoded;
          source = decoded.source;
        });
      } else {
        setState(() => error = '时刻表读取未完成，请稍后重试');
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => error = '时刻表读取未完成，请稍后重试');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => busy = false);
      }
    }
    if (!mounted || generation != _generation) return;
    if (_pendingReload) {
      _pendingReload = false;
      await load();
    }
  }

  Future<void> openOfficial({bool live = false}) async {
    final uri = Uri.tryParse(live ? (timetable?.liveSource ?? '') : source);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      await _showOfficialDialog(
        '官方页面暂不可用',
        const Text('尚未取得有效的官方页面地址，请刷新时刻表后重试。'),
      );
      return;
    }
    final generation = _generation;
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (opened || !mounted || generation != _generation) return;
    await _showOfficialDialog(
      '未能打开浏览器',
      SelectableText(
        '请手动访问：\n$uri',
        contextMenuBuilder: (context, editableText) =>
            CupertinoAdaptiveTextSelectionToolbar.buttonItems(
              anchors: editableText.contextMenuAnchors,
              buttonItems: editableText.contextMenuButtonItems,
            ),
      ),
    );
  }

  Future<void> _showOfficialDialog(String title, Widget content) =>
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: content,
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                if (ModalRoute.of(context)?.isCurrent ?? false) {
                  Navigator.pop(context);
                }
              },
              child: const Text('知道了'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final clock = widget.now ?? todaySchoolNow(DateTime.now());
    final nowMinute = clock.hour * 60 + clock.minute;
    final plan = timetable != null && timetable!.tables.isNotEmpty
        ? _planSection(timetable!.todayRuns(clock), clock)
        : null;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: CustomScrollView(
        key: const Key('shuttle-scroll'),
        slivers: [
          ApplePageHeader(
            largeTitle: const Text('校车'),
            section: '校园生活',
            subtitle: '计划班次与实时余票，分开核对',
            icon: CupertinoIcons.bus,
            border: null,
            trailing: AppleGlassButton(
              key: const Key('shuttle-refresh'),
              label: '刷新校车时刻表',
              onPressed: busy ? null : load,
              child: busy
                  ? const GinkgoActivity(size: 17)
                  : const Icon(CupertinoIcons.refresh, size: 22),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                AppleSection(
                  header: const Text('实时余票'),
                  footer: const Text(
                    '应用内尚未接通实时余票会话。可在官方页面完成学校认证后核对，时刻表容量不是余票。',
                  ),
                  children: [
                    AppleListTile(
                      key: const Key('shuttle-live-official'),
                      leading: Icon(
                        CupertinoIcons.ticket,
                        color: CupertinoTheme.of(context).primaryColor,
                      ),
                      title: const Text('前往官方认证并查看余票'),
                      subtitle: const Text('在外部浏览器打开智慧校车登录入口'),
                      trailing: const CupertinoListTileChevron(),
                      onTap: timetable?.liveSource.isNotEmpty == true
                          ? () => openOfficial(live: true)
                          : null,
                    ),
                  ],
                ),
                ?plan,
                AppleSection(
                  footer: const Text('公开计划仅供参考，临时调整以学校通知为准。应用不代理购票。'),
                  children: [
                    AppleListTile(
                      key: const Key('shuttle-official'),
                      title: const Text('查看时刻表原文'),
                      subtitle: const Text('公开班次来源，不是实时余票系统'),
                      leading: Icon(
                        CupertinoIcons.arrow_up_right_square,
                        color: CupertinoTheme.of(context).primaryColor,
                      ),
                      trailing: const CupertinoListTileChevron(),
                      onTap: openOfficial,
                    ),
                  ],
                ),
                if (busy && timetable == null)
                  const GinkgoLoadingView(label: '正在读取校车时刻表…'),
                if (error != null)
                  AppleSection(children: [AppleListTile(title: Text(error!))]),
                if (timetable != null && timetable!.tables.isEmpty && !busy)
                  const AppleSection(
                    children: [
                      AppleListTile(
                        title: Text('暂时没有可显示的时刻表'),
                        subtitle: Text('官方页面结构可能已变化，请到官方页面查看。'),
                      ),
                    ],
                  ),
                for (final table in timetable?.tables ?? const <ShuttleTable>[])
                  ..._tableSections(table, nowMinute),
                // The former ListView sat inside SafeArea; keep the bottom inset
                // now that the page is a sliver list.
                SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Next departure and at most two follow-ups, derived only from the published
  /// runs and Beijing wall time. No request is issued and no seat availability
  /// is inferred.
  Widget _planSection(List<ShuttleDeparture> runs, DateTime clock) {
    final nowMinute = clock.hour * 60 + clock.minute;
    final upcoming = runs
        .where((run) => run.minutes >= nowMinute)
        .take(3)
        .toList();
    return TodayVisualSection(
      key: const Key('shuttle-plan'),
      header: const TodaySectionHeader(
        icon: CupertinoIcons.bus,
        title: '下一班计划',
        badge: '静态时刻表',
      ),
      footer: const Text(
        '按北京时间从公开静态时刻表推算；计划容量是公布的可乘人数，不代表实时空位。节假日与临时调整以官方页面为准。',
      ),
      children: [
        if (upcoming.isEmpty)
          AppleListTile(
            key: Key(runs.isEmpty ? 'shuttle-plan-none' : 'shuttle-plan-ended'),
            title: Text(runs.isEmpty ? '今日无计划班次' : '今日计划班次已结束'),
            subtitle: Text(
              runs.isEmpty
                  ? '公开时刻表没有今天适用的班次，完整时刻表见下方。'
                  : '按北京时间，今天适用的班次已全部发出；后续安排见完整时刻表或官方页面。',
            ),
            leading: Icon(
              CupertinoIcons.clock,
              color: AppleDesign.statusInactive,
            ),
          )
        else ...[
          _planNext(upcoming.first),
          for (var i = 1; i < upcoming.length; i++) ...[
            const TodayVisualDivider(),
            _planFollowing(upcoming[i], i - 1),
          ],
        ],
      ],
    );
  }

  Widget _planNext(ShuttleDeparture run) => MergeSemantics(
    child: Container(
      width: double.infinity,
      key: const Key('shuttle-plan-next'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            run.direction,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                run.time,
                key: const Key('shuttle-plan-next-time'),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.8,
                ),
              ),
              Text(
                _capacityLabel(run),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppleDesign.statusInactive.resolveFrom(context),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _planFollowing(ShuttleDeparture run, int index) => MergeSemantics(
    child: Container(
      width: double.infinity,
      key: Key('shuttle-plan-following-$index'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '随后',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppleDesign.statusInactive.resolveFrom(context),
                ),
              ),
              Text(
                run.time,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _capacityLabel(run),
                style: TextStyle(
                  fontSize: 13,
                  color: AppleDesign.statusInactive.resolveFrom(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            run.direction,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    ),
  );

  String _capacityLabel(ShuttleDeparture run) =>
      run.capacity.isEmpty ? '计划容量未公布' : '计划 ${run.capacity} 座';

  List<Widget> _tableSections(ShuttleTable table, int nowMinute) {
    return [
      for (final section in table.sections)
        AppleSection(
          header: Text(section.label.isEmpty ? '公开时刻表' : section.label),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final directions = [
                    _direction(table.left, section.left, nowMinute),
                    _direction(table.right, section.right, nowMinute),
                  ];
                  // Do not shrink accessible text to preserve a two-column table.
                  // Keep each direction and its runs together at large scales.
                  final scaledFont = MediaQuery.textScalerOf(context).scale(13);
                  final stacked =
                      constraints.maxWidth < 300 ||
                      (constraints.maxWidth - 12) / 2 < scaledFont * 9;
                  if (stacked) {
                    return Column(
                      key: const Key('shuttle-directions-stacked'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        directions[0],
                        const SizedBox(height: 20),
                        directions[1],
                      ],
                    );
                  }
                  return Row(
                    key: const Key('shuttle-directions-columns'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: directions[0]),
                      const SizedBox(width: 12),
                      Expanded(child: directions[1]),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
    ];
  }

  /// Published runs stay consistent with the app accent: upcoming departures
  /// use the theme tint, departed runs fall back to quiet fill so the remaining
  /// schedule reads at a glance. Pure presentation on already-fetched data.
  Widget _direction(
    String name,
    List<ShuttleRun> runs,
    int nowMinute,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        name,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final run in runs)
            Builder(
              builder: (context) {
                final departed =
                    run.minuteOfDay != null && run.minuteOfDay! < nowMinute;
                final capacity = run.capacity;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: departed
                        ? CupertinoColors.tertiarySystemFill.resolveFrom(
                            context,
                          )
                        : CupertinoTheme.of(context).primaryColor
                              .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    capacity.isEmpty ? run.time : '${run.time} · $capacity座',
                    style: TextStyle(
                      fontSize: 13,
                      color: departed
                          ? CupertinoColors.secondaryLabel.resolveFrom(context)
                          : CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    ],
  );
}
