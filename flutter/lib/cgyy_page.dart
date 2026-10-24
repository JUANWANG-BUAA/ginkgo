import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'academic_widgets.dart';
import 'cgyy_booking_page.dart';
import 'cgyy_order_presentation.dart';
import 'cgyy_review_page.dart';
import 'apple_widgets.dart';
import 'apple_design.dart';
import 'loading_widgets.dart';
import 'mirror_service.dart';
import 'reservation_widgets.dart';
import 'application/contracts.dart' as live;

typedef CgyyLoader = Future<live.ReadOnlyResponse> Function({
  required String kind,
  required int siteId,
  required String date,
  required bool forceRefresh,
});

class CgyyPage extends StatefulWidget {
  const CgyyPage({super.key, this.demo = false, this.loader, this.service});
  final bool demo;
  final CgyyLoader? loader;
  final CampusGateway? service;
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
          : await (widget.service ?? mirrorServiceFor(demo: widget.demo)).cgyy(
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
      builder: (_) => _CgyyReadPage(
        demo: widget.demo,
        site: site,
        loader: widget.loader,
        service: widget.service,
      ),
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
        ApplePageHeader(
          largeTitle: const Text('研讨室'),
          section: '空间资源',
          subtitle: '选择场馆并查看可预约空间',
          icon: CupertinoIcons.person_3,
          border: null,
          trailing: AppleGlassButton(
            label: '刷新场馆',
            onPressed: busy ? null : () => load(force: true),
            child: busy
                ? const GinkgoActivity(size: 17)
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
                    detail: '最近最多 20 条',
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
              const GinkgoLoadingView(label: '正在读取研讨室…'),
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
  const _CgyyReadPage({
    required this.demo,
    this.site,
    this.loader,
    this.service,
  });
  final bool demo;
  final Map<String, dynamic>? site;
  final CgyyLoader? loader;
  final CampusGateway? service;
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
  bool actionBusy = false;
  bool guardKnown = false;
  bool reviewRequired = true;
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
          : await (widget.service ?? mirrorServiceFor(demo: widget.demo)).cgyy(
              kind: kind,
              siteId: widget.site?['id'] as int? ?? 0,
              date: queriedDate,
              forceRefresh: force,
            );
      await readGuard();
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

  CgyyBookingGateway? get bookingGateway {
    if (widget.demo || widget.loader != null) return null;
    final source = widget.service ?? mirrorServiceFor(demo: false);
    return source is CgyyBookingGateway ? source as CgyyBookingGateway : null;
  }

  Future<void> readGuard() async {
    final gateway = bookingGateway;
    if (gateway == null) return;
    try {
      final response = await gateway.executeCgyy({'action': 'status'});
      if (response.failure != null ||
          response.stale ||
          response.payload == null) {
        throw const FormatException('Missing write status');
      }
      final result = jsonDecode(response.payload!) as Map<String, dynamic>;
      if (!['ready', 'uncertain'].contains(result['state'])) {
        throw const FormatException('Unknown write status');
      }
      if (mounted) {
        setState(() {
          guardKnown = true;
          reviewRequired = result['state'] != 'ready';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          guardKnown = false;
          reviewRequired = true;
        });
      }
    }
  }

  Future<void> openReview() async {
    if (busy || actionBusy || bookingGateway == null) return;
    setState(() => actionBusy = true);
    await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => CgyyReviewPage(gateway: bookingGateway!),
      ),
    );
    if (!mounted) return;
    setState(() => actionBusy = false);
    await load(force: true);
  }

  Future<void> openBooking() async {
    if (busy ||
        actionBusy ||
        !guardKnown ||
        reviewRequired ||
        bookingGateway == null) {
      return;
    }
    setState(() => actionBusy = true);
    final result = await Navigator.of(context).push<Object?>(
      CupertinoPageRoute(
        builder: (_) => CgyyBookingPage(
          gateway: bookingGateway!,
          siteId: widget.site!['id'] as int,
          siteName: widget.site!['name'] as String,
          date: date,
        ),
      ),
    );
    if (!mounted) return;
    await load(force: true);
    if (!mounted) return;
    setState(() => actionBusy = false);
    // Accepted and uncertain outcomes both lead to records, not back to slots.
    if (result != null || reviewRequired) {
      await Navigator.of(context).push<void>(
        CupertinoPageRoute(
          builder: (_) => _CgyyReadPage(
            demo: widget.demo,
            loader: widget.loader,
            service: widget.service,
          ),
        ),
      );
      if (mounted) await load(force: true);
    }
  }

  Future<void> cancelOrder(Map<String, dynamic> order) async {
    if (busy ||
        actionBusy ||
        !guardKnown ||
        reviewRequired ||
        bookingGateway == null) {
      return;
    }
    setState(() => actionBusy = true);
    String? message;
    try {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('取消这条预约？'),
          content: Text(
            '${cgyyOrderSummary(order)}\n\n确认后仅发送一次取消请求；会重新核对状态与开始前 4 小时限制，结果不明时不会重发。',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                if (ModalRoute.of(context)?.isCurrent ?? false) {
                  Navigator.pop(context, false);
                }
              },
              child: const Text('保留预约'),
            ),
            CupertinoDialogAction(
              key: const Key('cgyy-cancel-confirm'),
              isDestructiveAction: true,
              onPressed: () {
                if (ModalRoute.of(context)?.isCurrent ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('确认取消预约'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final response = await bookingGateway!.executeCgyy({
        'action': 'cancel',
        'order_id': order['id'],
      });
      message = response.failure == null && response.payload != null
          ? (jsonDecode(response.payload!) as Map<String, dynamic>)['message']
                as String
          : '取消结果待核实，请核对最新记录，勿重复提交';
      if (mounted) await load(force: true);
    } catch (_) {
      message = '取消结果待核实，请核对最新记录，勿重复提交';
      if (mounted) await readGuard();
    } finally {
      if (mounted) {
        setState(() {
          actionBusy = false;
          if (message != null) error = message;
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
                    onPressed: () {
                      if (ModalRoute.of(context)?.isCurrent ?? false) {
                        Navigator.pop(context, false);
                      }
                    },
                    child: const Text('取消'),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      if (ModalRoute.of(context)?.isCurrent ?? false) {
                        Navigator.pop(context, true);
                      }
                    },
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
  Widget build(BuildContext context) => PopScope(
    canPop: !actionBusy,
    child: CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.site == null ? '预约记录' : '时段查询'),
        automaticallyImplyLeading: bookingGateway == null,
        previousPageTitle: bookingGateway == null ? '研讨室' : null,
        leading: bookingGateway == null
            ? null
            : CupertinoButton(
                key: const Key('cgyy-records-back'),
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.zero,
                onPressed: actionBusy
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Icon(CupertinoIcons.back, semanticLabel: '返回研讨室'),
              ),
        trailing: AppleGlassButton(
          label: '刷新查询',
          onPressed: busy || actionBusy ? null : () => load(force: true),
          child: const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            if (bookingGateway != null && (!guardKnown || reviewRequired))
              AppleSection(
                header: const Text('写入保护'),
                footer: const Text('预约记录出现不代表审批通过。核实前不会再次预约或取消。'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      guardKnown
                          ? '上次操作结果待核实，请先核对最新预约记录。'
                          : '尚未确认写入状态，暂不可提交。请刷新或读取最新记录核对。',
                    ),
                  ),
                  CupertinoButton(
                    key: const Key('cgyy-open-review'),
                    minimumSize: const Size(48, 48),
                    onPressed: busy || actionBusy ? null : openReview,
                    child: const Text('读取最新记录并核对'),
                  ),
                ],
              ),
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
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
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
                          onPressed: busy ? null : chooseDate,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            if (widget.site != null && bookingGateway != null)
              AppleSection(
                footer: const Text('提交前重新核对空档；实验写入功能，需手动验证并确认。'),
                children: [
                  AppleListTile(
                    leading: const Icon(CupertinoIcons.calendar_badge_plus),
                    title: const Text('预约研讨室'),
                    trailing: const CupertinoListTileChevron(),
                    key: const Key('cgyy-open-booking'),
                    onTap: busy || actionBusy || !guardKnown || reviewRequired
                        ? null
                        : openBooking,
                  ),
                ],
              ),
            if (busy) const GinkgoLoadingView(label: '正在读取预约信息…'),
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
                header: const Text('最近最多 20 条'),
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
                          cgyyOrderStatus(order),
                          tint: CupertinoColors.systemIndigo,
                          icon: CupertinoIcons.info_circle,
                        ),
                      ],
                    ),
                ],
              ),
            if (widget.site == null && bookingGateway != null)
              AppleSection(
                header: const Text('预约管理'),
                footer: const Text('取消前会核对订单状态及开始前 4 小时限制；不符合条件不会发送请求。'),
                children: [
                  for (final order in orders ?? <Map<String, dynamic>>[])
                    if (order['can_cancel'] == true)
                      AppleListTile(
                        key: ValueKey('cgyy-cancel-${order['id']}'),
                        title: Text('取消 · ${order['place'] as String}'),
                        subtitle: Text(cgyyOrderSummary(order)),
                        onTap:
                            busy || actionBusy || !guardKnown || reviewRequired
                            ? null
                            : () => cancelOrder(order),
                      ),
                ],
              ),
            const SizedBox(height: 32),
          ],
        ),
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
