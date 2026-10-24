import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:url_launcher/url_launcher.dart';

import 'apple_design.dart';
import 'apple_widgets.dart';
import 'loading_widgets.dart';
import 'mirror_service.dart';
import 'today_presentation.dart';
import 'today_time.dart';

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
  List<Map<String, dynamic>>? tables;
  String source = '';
  String? error;
  bool busy = false;
  int _generation = 0;
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
      tables = null;
      source = '';
      error = null;
      busy = false;
      load();
    }
  }

  Future<void> load() async {
    if (busy) return;
    final generation = ++_generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.service.shuttleTimetable();
      if (!mounted || generation != _generation) return;
      if (result.payload != null && result.failure == null) {
        final payload = jsonDecode(result.payload!) as Map<String, dynamic>;
        setState(() {
          tables = (payload['tables'] as List).cast<Map<String, dynamic>>();
          source = payload['source'] as String? ?? '';
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
  }

  Future<void> openOfficial() async {
    final uri = Uri.tryParse(source);
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
    final plan = tables != null && tables!.isNotEmpty
        ? _planSection(_todayRuns(tables!, clock), clock)
        : null;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: CustomScrollView(
        key: const Key('shuttle-scroll'),
        slivers: [
          ApplePageHeader(
            largeTitle: const Text('校车时刻表'),
            section: '校园生活',
            subtitle: '查看公开计划时刻与官方入口',
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
                ?plan,
                AppleSection(
                  footer: const Text('数据来自学校公开时刻表页面，仅作参考。应用不代理购票，也不显示实时余票。'),
                  children: [
                    AppleListTile(
                      key: const Key('shuttle-official'),
                      title: const Text('查看官方页面'),
                      subtitle: const Text('购票、余票与临时调整以官方为准'),
                      leading: const Icon(
                        CupertinoIcons.arrow_up_right_square,
                        color: AppleDesign.resourceBlue,
                      ),
                      trailing: const CupertinoListTileChevron(),
                      onTap: openOfficial,
                    ),
                  ],
                ),
                if (busy && tables == null)
                  const GinkgoLoadingView(label: '正在读取校车时刻表…'),
                if (error != null)
                  AppleSection(children: [AppleListTile(title: Text(error!))]),
                if (tables != null && tables!.isEmpty && !busy)
                  const AppleSection(
                    children: [
                      AppleListTile(
                        title: Text('暂时没有可显示的时刻表'),
                        subtitle: Text('官方页面结构可能已变化，请到官方页面查看。'),
                      ),
                    ],
                  ),
                for (final table in tables ?? const <Map<String, dynamic>>[])
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
  Widget _planSection(List<_PublishedRun> runs, DateTime clock) {
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

  Widget _planNext(_PublishedRun run) => MergeSemantics(
    child: Padding(
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

  Widget _planFollowing(_PublishedRun run, int index) => MergeSemantics(
    child: Padding(
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

  String _capacityLabel(_PublishedRun run) =>
      run.capacity.isEmpty ? '计划容量未公布' : '计划 ${run.capacity} 座';

  /// Flattens every published run that applies today. Duplicate rows across
  /// tables (same direction and departure) are collapsed, then sorted by the
  /// Beijing wall clock.
  List<_PublishedRun> _todayRuns(
    List<Map<String, dynamic>> tables,
    DateTime clock,
  ) {
    final runs = <_PublishedRun>[];
    final seen = <String>{};
    for (final table in tables) {
      final directions = [
        (table['left'] as String? ?? '').trim(),
        (table['right'] as String? ?? '').trim(),
      ];
      final sections = (table['sections'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      for (final section in sections) {
        if (!_sectionAppliesToday(
          section['label'] as String? ?? '',
          clock.weekday,
        )) {
          continue;
        }
        for (var side = 0; side < directions.length; side++) {
          final direction = directions[side];
          if (direction.isEmpty) continue;
          final sideRuns =
              (section[side == 0 ? 'left' : 'right'] as List? ?? const [])
                  .cast<Map<String, dynamic>>();
          for (final run in sideRuns) {
            final time = (run['time'] as String? ?? '').trim();
            final minutes = _minuteOfDay(time);
            if (minutes == null) continue;
            if (!seen.add('$direction|$minutes')) continue;
            runs.add(
              _PublishedRun(
                direction: direction,
                time: time,
                minutes: minutes,
                capacity: (run['capacity'] as String? ?? '').trim(),
              ),
            );
          }
        }
      }
    }
    runs.sort((a, b) {
      final byTime = a.minutes.compareTo(b.minutes);
      if (byTime != 0) return byTime;
      final byDirection = a.direction.compareTo(b.direction);
      return byDirection != 0 ? byDirection : a.time.compareTo(b.time);
    });
    return runs;
  }

  static int? _minuteOfDay(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    if (hour > 23 || minute > 59) return null;
    return hour * 60 + minute;
  }

  /// Published validity labels name weekdays rather than dates. Only labels the
  /// page can read unambiguously filter the plan; an unfamiliar label keeps its
  /// runs visible instead of claiming they do not apply.
  static bool _sectionAppliesToday(String label, int weekday) {
    final text = label.replaceAll(' ', '');
    if (text.isEmpty) return true;
    if (text.contains('每天') || text.contains('每日') || text.contains('全年')) {
      return true;
    }
    if (text.contains('双休日') || text.contains('周末')) {
      return weekday >= DateTime.saturday;
    }
    if (text.contains('工作日')) return weekday <= DateTime.friday;
    final range = RegExp(r'星期([一二三四五六日天])(?:至|到|-|—|–|~)星期([一二三四五六日天])')
        .firstMatch(text);
    if (range != null) {
      final from = _weekdayIndex(range.group(1)!);
      final to = _weekdayIndex(range.group(2)!);
      if (from != null && to != null) {
        return from <= to
            ? weekday >= from && weekday <= to
            : weekday >= from || weekday <= to;
      }
    }
    final singles = RegExp(r'星期([一二三四五六日天])')
        .allMatches(text)
        .map((match) => _weekdayIndex(match.group(1)!))
        .whereType<int>()
        .toSet();
    if (singles.isNotEmpty) return singles.contains(weekday);
    return true;
  }

  static int? _weekdayIndex(String value) => switch (value) {
    '一' => DateTime.monday,
    '二' => DateTime.tuesday,
    '三' => DateTime.wednesday,
    '四' => DateTime.thursday,
    '五' => DateTime.friday,
    '六' => DateTime.saturday,
    '日' || '天' => DateTime.sunday,
    _ => null,
  };

  List<Widget> _tableSections(
    Map<String, dynamic> table,
    int nowMinute,
  ) {
    final left = table['left'] as String? ?? '';
    final right = table['right'] as String? ?? '';
    final sections = (table['sections'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    return [
      for (final section in sections)
        AppleSection(
          header: Text(
            (section['label'] as String? ?? '').isEmpty
                ? '公开时刻表'
                : section['label'] as String,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final directions = [
                    _direction(
                      left,
                      (section['left'] as List? ?? const [])
                          .cast<Map<String, dynamic>>(),
                      nowMinute,
                    ),
                    _direction(
                      right,
                      (section['right'] as List? ?? const [])
                          .cast<Map<String, dynamic>>(),
                      nowMinute,
                    ),
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
    List<Map<String, dynamic>> runs,
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
                final minutes = _minuteOfDay(
                  (run['time'] as String? ?? '').trim(),
                );
                final departed = minutes != null && minutes < nowMinute;
                final capacity = (run['capacity'] as String? ?? '').trim();
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
                        : CupertinoTheme.of(context).primaryColor.withValues(
                            alpha: 0.12,
                          ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    capacity.isEmpty
                        ? '${run['time']}'
                        : '${run['time']} · $capacity座',
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

class _PublishedRun {
  const _PublishedRun({
    required this.direction,
    required this.time,
    required this.minutes,
    required this.capacity,
  });

  final String direction;
  final String time;
  final int minutes;
  final String capacity;
}
