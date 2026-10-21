import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'academic_widgets.dart';
import 'apple_widgets.dart';
import 'apple_design.dart';
import 'reservation_widgets.dart';
import 'src/rust/api/live.dart' as live;

typedef CgyyLoader = Future<live.ReadOnlyResponse> Function({
  required String kind,
  required int siteId,
  required String date,
  required bool forceRefresh,
});

class CgyyPage extends StatefulWidget {
  const CgyyPage({super.key, this.demo = false, this.loader});
  final bool demo;
  final CgyyLoader? loader;
  @override
  State<CgyyPage> createState() => _CgyyPageState();
}

class _CgyyPageState extends State<CgyyPage> {
  List<Map<String, dynamic>>? sites;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool force = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = widget.loader != null
          ? await widget.loader!(
              kind: 'venues',
              siteId: 0,
              date: '',
              forceRefresh: force,
            )
          : widget.demo
          ? await live.loadDemoCgyy(kind: 'venues')
          : await live.loadCgyy(
              kind: 'venues',
              siteId: 0,
              date: '',
              forceRefresh: force,
            );
      if (!mounted) return;
      setState(() {
        busy = false;
        if (result.failure != null) error = failureMessage(result.failure);
        if (result.payload != null) {
          sites = (jsonDecode(result.payload!) as List)
              .cast<Map<String, dynamic>>();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = failureMessage(null);
        });
      }
    }
  }

  void open({Map<String, dynamic>? site}) => Navigator.of(context).push(
    CupertinoPageRoute<void>(
      builder: (_) =>
          _CgyyReadPage(demo: widget.demo, site: site, loader: widget.loader),
    ),
  );
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('cgyy-scroll'),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('研讨室'),
          border: null,
          trailing: AppleGlassButton(
            label: '刷新场馆',
            onPressed: busy ? null : () => load(force: true),
            child: busy
                ? const CupertinoActivityIndicator()
                : const Icon(CupertinoIcons.refresh),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
        SliverList.list(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Text(
                '教学楼空间与时段',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ),
            AppleSection(
              children: [
                _CgyyInteractiveRow(
                  onTap: () => open(),
                  child: _CgyyTileContent(
                    icon: CupertinoIcons.calendar_badge_plus,
                    tint: CupertinoColors.systemIndigo,
                    title: '我的预约记录',
                    detail: '最近 20 条',
                    chevron: true,
                  ),
                ),
              ],
            ),
            if (error != null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: error!,
                    description: sites == null ? '请稍后重试。' : '正在显示上次场馆。',
                    action: '重试',
                    onAction: () => load(force: true),
                    error: true,
                  ),
                ],
              ),
            if (sites == null && busy)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CupertinoActivityIndicator(),
              ),
            if (sites?.isEmpty == true)
              const AppleSection(
                children: [
                  AppleEmptyState(title: '暂无公开场馆', description: '学校暂未提供公开场馆。'),
                ],
              ),
            if (sites != null && sites!.isNotEmpty)
              AppleSection(
                header: const Text('公开场馆'),
                children: [
                  for (final site in sites!)
                    _CgyyInteractiveRow(
                      key: ValueKey('cgyy-site-${site['id']}'),
                      onTap: () => open(site: site),
                      child: _siteContent(site, chevron: true),
                    ),
                ],
              ),
            const SizedBox(height: 96),
          ],
        ),
      ],
    ),
  );
}

class _CgyyReadPage extends StatefulWidget {
  const _CgyyReadPage({required this.demo, this.site, this.loader});
  final bool demo;
  final Map<String, dynamic>? site;
  final CgyyLoader? loader;
  @override
  State<_CgyyReadPage> createState() => _CgyyReadPageState();
}

class _CgyyReadPageState extends State<_CgyyReadPage> {
  late DateTime selected = widget.demo
      ? DateTime(2026, 10, 20)
      : _schoolToday();
  Map<String, dynamic>? day;
  List<Map<String, dynamic>>? orders;
  String? error;
  bool busy = false;
  int request = 0;
  static DateTime _schoolToday() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    return DateTime(now.year, now.month, now.day);
  }

  String get date =>
      '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool force = false}) async {
    final serial = ++request;
    final queriedDate = date;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final kind = widget.site == null ? 'orders' : 'day';
      final result = widget.loader != null
          ? await widget.loader!(
              kind: kind,
              siteId: widget.site?['id'] as int? ?? 0,
              date: queriedDate,
              forceRefresh: force,
            )
          : widget.demo
          ? await live.loadDemoCgyy(kind: kind)
          : await live.loadCgyy(
              kind: kind,
              siteId: widget.site?['id'] as int? ?? 0,
              date: queriedDate,
              forceRefresh: force,
            );
      if (!mounted || serial != request) return;
      setState(() {
        busy = false;
        if (result.failure != null) error = failureMessage(result.failure);
        if (result.payload != null) {
          final payload = jsonDecode(result.payload!);
          if (kind == 'orders') {
            orders = (payload as List).cast<Map<String, dynamic>>();
          } else {
            day = payload as Map<String, dynamic>;
          }
        }
      });
    } catch (_) {
      if (mounted && serial == request) {
        setState(() {
          busy = false;
          error = failureMessage(null);
        });
      }
    }
  }

  Future<void> chooseDate() async {
    var draft = selected;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => Container(
        height: 310,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('确定'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: selected,
                  onDateTimeChanged: (value) => draft = value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || confirmed != true) return;
    if (draft.year != selected.year ||
        draft.month != selected.month ||
        draft.day != selected.day) {
      setState(() => selected = draft);
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    navigationBar: CupertinoNavigationBar(
      middle: Text(widget.site == null ? '预约记录' : '时段查询'),
      previousPageTitle: '研讨室',
      trailing: AppleGlassButton(
        label: '刷新查询',
        onPressed: busy ? null : () => load(force: true),
        child: const Icon(CupertinoIcons.refresh),
      ),
    ),
    child: SafeArea(
      child: ListView(
        children: [
          if (widget.site != null)
            AppleSection(
              children: [
                _siteContent(widget.site!),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '查询日期',
                            style: TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.secondaryLabel.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _displayDate(date),
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      ReservationActionButton(
                        buttonKey: const Key('cgyy-choose-date'),
                        label: '更改日期',
                        icon: CupertinoIcons.calendar,
                        tint: CupertinoColors.systemTeal,
                        onPressed: busy ? null : chooseDate,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CupertinoActivityIndicator(),
            ),
          if (error != null)
            AppleSection(
              children: [
                AppleEmptyState(
                  title: error!,
                  description: day != null || orders != null
                      ? '保留上次结果，请核对下方实际日期。'
                      : '需要可用的直连学校会话；可记住密码后重试。',
                  action: '重试',
                  onAction: () => load(force: true),
                  error: true,
                ),
              ],
            ),
          if (day != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '空间时段',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '实际显示 ${_displayDate(day!['date'] as String)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const AcademicBadge(
                    '仅供查询',
                    tint: CupertinoColors.systemTeal,
                    icon: CupertinoIcons.info_circle,
                  ),
                ],
              ),
            ),
            if ((day!['spaces'] as List).isEmpty)
              const AppleSection(
                children: [
                  AppleEmptyState(title: '当天暂无空间时段', description: '可切换其他日期。'),
                ],
              ),
            for (final space in day!['spaces'] as List)
              AppleSection(
                header: Text(space['name'] as String),
                children: [
                  if ((space['slots'] as List).isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('暂无时段'),
                    ),
                  for (final slot in space['slots'] as List)
                    _CgyySlotRow(
                      time: slot['time'] as String,
                      status: slot['status'] as String,
                    ),
                ],
              ),
          ],
          if (orders?.isEmpty == true)
            const AppleSection(
              children: [
                AppleEmptyState(title: '暂无预约记录', description: '学校返回的最近记录为空。'),
              ],
            ),
          if (orders != null && orders!.isNotEmpty)
            AppleSection(
              header: const Text('最近 20 条'),
              children: [
                for (final order in orders!)
                  _CgyyTileContent(
                    icon: CupertinoIcons.doc_text,
                    tint: CupertinoColors.systemIndigo,
                    title: (order['place'] as String).isEmpty
                        ? '预约记录'
                        : order['place'] as String,
                    detail:
                        '${_displayDate(order['date'] as String)}\n${order['time']}',
                    badges: [
                      AcademicBadge(
                        order['status'] as String,
                        tint: CupertinoColors.systemIndigo,
                        icon: CupertinoIcons.info_circle,
                      ),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: 32),
        ],
      ),
    ),
  );
}

String _displayDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return '${date.year}年${date.month}月${date.day}日 · ${weekdays[date.weekday - 1]}';
}

Widget _siteContent(Map<String, dynamic> site, {bool chevron = false}) {
  final name = site['name'] as String;
  final campus = site['campus'] as String? ?? '';
  final tint = campus.contains('沙河')
      ? CupertinoColors.systemBlue
      : CupertinoColors.systemTeal;
  return _CgyyTileContent(
    icon: CupertinoIcons.building_2_fill,
    tint: tint,
    title: name.isEmpty ? site['venue'] as String : name,
    detail: [site['venue'], campus]
        .whereType<String>()
        .where((value) => value.isNotEmpty && value != name)
        .join(' · '),
    badges: [
      if (site['seats'] != null)
        AcademicBadge(
          '${site['seats']} 座',
          tint: tint,
          icon: CupertinoIcons.person_2,
        ),
    ],
    chevron: chevron,
  );
}

/// Inset rows inherit Cupertino press feedback and add a quiet pointer state.
/// The whole row remains a single action with its full readable label.
class _CgyyInteractiveRow extends StatefulWidget {
  const _CgyyInteractiveRow({
    super.key,
    required this.child,
    required this.onTap,
  });
  final Widget child;
  final VoidCallback onTap;
  @override
  State<_CgyyInteractiveRow> createState() => _CgyyInteractiveRowState();
}

class _CgyyInteractiveRowState extends State<_CgyyInteractiveRow> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => hovered = true),
    onExit: (_) => setState(() => hovered = false),
    child: AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 140),
      color: CupertinoColors.systemTeal
          .resolveFrom(context)
          .withValues(alpha: hovered ? 0.045 : 0),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: widget.onTap,
        child: widget.child,
      ),
    ),
  );
}

class _CgyyTileContent extends StatelessWidget {
  const _CgyyTileContent({
    required this.icon,
    required this.tint,
    required this.title,
    required this.detail,
    this.badges = const [],
    this.chevron = false,
  });
  final IconData icon;
  final CupertinoDynamicColor tint;
  final String title, detail;
  final List<Widget> badges;
  final bool chevron;
  @override
  Widget build(BuildContext context) {
    final color = tint.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ],
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: badges),
                ],
              ],
            ),
          ),
          if (chevron) ...[
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CgyySlotRow extends StatelessWidget {
  const _CgyySlotRow({required this.time, required this.status});
  final String time, status;
  @override
  Widget build(BuildContext context) {
    final (tint, icon) = switch (status) {
      '空闲' => (AppleDesign.statusSuccess, CupertinoIcons.checkmark_circle),
      '不可预约' => (AppleDesign.statusInactive, CupertinoIcons.minus_circle),
      _ => (AppleDesign.statusUncertain, CupertinoIcons.question_circle),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final label = Text(
            time,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          );
          final badge = AcademicBadge(status, tint: tint, icon: icon);
          if (constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.4) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label, const SizedBox(height: 9), badge],
            );
          }
          return Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: 12),
              badge,
            ],
          );
        },
      ),
    );
  }
}
