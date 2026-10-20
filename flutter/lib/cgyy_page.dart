import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'src/rust/api/live.dart' as live;

class CgyyPage extends StatefulWidget {
  const CgyyPage({super.key, this.demo = false});
  final bool demo;
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
      final result = widget.demo
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
      builder: (_) => _CgyyReadPage(demo: widget.demo, site: site),
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
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              child: Text(
                '教学楼 CGYY · 只读查询',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ),
            AppleSection(
              children: [
                AppleListTile(
                  title: const Text('我的预约记录'),
                  subtitle: const Text('最近 20 条 · 直连学校 SSO'),
                  trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                  onTap: () => open(),
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
                    AppleListTile(
                      title: Text(
                        (site['name'] as String).isEmpty
                            ? site['venue'] as String
                            : site['name'] as String,
                      ),
                      subtitle: Text(
                        [
                          site['venue'],
                          site['campus'],
                          if (site['seats'] != null) '${site['seats']} 座',
                        ].where((s) => s != null && s != '').join(' · '),
                      ),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                      ),
                      onTap: () => open(site: site),
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
  const _CgyyReadPage({required this.demo, this.site});
  final bool demo;
  final Map<String, dynamic>? site;
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
      final result = widget.demo
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
                AppleListTile(
                  title: Text(widget.site!['name'] as String),
                  subtitle: Text(widget.site!['venue'] as String),
                ),
                AppleListTile(
                  title: const Text('查询日期'),
                  subtitle: Text(date),
                  trailing: const Icon(CupertinoIcons.calendar),
                  onTap: busy ? null : chooseDate,
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
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              child: Text('实际显示 ${day!['date']} · 仅供查询'),
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
                    AppleListTile(
                      title: Text(slot['time'] as String),
                      subtitle: Text(slot['status'] as String),
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
                  AppleListTile(
                    title: Text(
                      (order['place'] as String).isEmpty
                          ? '预约记录'
                          : order['place'] as String,
                    ),
                    subtitle: Text(
                      '${order['date']}\n${order['time']} · ${order['status']}',
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 32),
        ],
      ),
    ),
  );
}
