import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:ginkgo_mirror/shared/school_links.dart';

import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'shuttle_models.dart';
import 'shuttle_widgets.dart';

/// Official shuttle timetable. Only the published page is shown: the app does
/// not guess live seat counts and never proxies ticketing.
class ShuttlePage extends StatefulWidget {
  const ShuttlePage({super.key, required this.service, this.now});
  final ShuttleGateway service;

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
    final opened = await openSchoolLink(uri.toString());
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
    final tables = timetable?.tables ?? const <ShuttleTable>[];
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
                if (tables.isNotEmpty)
                  ShuttlePlanSection(
                    runs: timetable!.todayRuns(clock),
                    clock: clock,
                  ),
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
                for (final table in tables)
                  for (final section in table.sections)
                    ShuttleTableSection(
                      section: section,
                      leftName: table.left,
                      rightName: table.right,
                      nowMinute: nowMinute,
                    ),
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
}
