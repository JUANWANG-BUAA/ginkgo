import 'package:flutter/cupertino.dart';

import 'academic_widgets.dart';
import 'apple_widgets.dart';
import 'cgyy_booking_page.dart';
import 'cgyy_models.dart';
import 'cgyy_review_page.dart';
import 'cgyy_widgets.dart';
import 'loading_widgets.dart';
import 'mirror_service.dart';
import 'reservation_widgets.dart';
import 'school_timestamp.dart';
import 'today_time.dart';
import 'application/contracts.dart' as live;

/// Loader signature shared by the CGYY hub and the day/orders page.
typedef CgyyLoader = Future<live.ReadOnlyResponse> Function({
  required String kind,
  required int siteId,
  required String date,
  required bool forceRefresh,
});

class CgyyDayPage extends StatefulWidget {
  const CgyyDayPage({
    super.key,
    required this.demo,
    this.site,
    this.loader,
    this.service,
  });
  final bool demo;
  final CgyySite? site;
  final CgyyLoader? loader;
  final CampusGateway? service;
  @override
  State<CgyyDayPage> createState() => _CgyyDayPageState();
}

class _CgyyDayPageState extends State<CgyyDayPage> {
  late DateTime selected = widget.demo
      ? DateTime(2026, 10, 20)
      : _schoolToday();
  CgyyDay? day;
  List<CgyyOrder>? orders;
  String? error;
  bool busy = false;
  int request = 0;
  bool actionBusy = false;
  bool guardKnown = false;
  bool reviewRequired = true;
  static DateTime _schoolToday() => todaySchoolNow(DateTime.now());

  String get date => schoolDateString(selected);
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
              siteId: widget.site?.id ?? 0,
              date: queriedDate,
              forceRefresh: force,
            )
          : await (widget.service ?? mirrorServiceFor(demo: widget.demo)).cgyy(
              kind: kind,
              siteId: widget.site?.id ?? 0,
              date: queriedDate,
              forceRefresh: force,
            );
      await readGuard();
      if (!mounted || serial != request) return;
      setState(() {
        busy = false;
        if (result.failure != null) error = failureMessage(result.failure);
        if (result.payload != null) {
          if (kind == 'orders') {
            orders = cgyyOrders(result.payload!);
          } else {
            day = cgyyDay(result.payload!);
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
    final source = widget.service ?? mirrorServiceFor(demo: widget.demo);
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
      final status = cgyyWriteStatus(response.payload!);
      if (!status.known) {
        throw const FormatException('Unknown write status');
      }
      if (mounted) {
        setState(() {
          guardKnown = status.known;
          reviewRequired = status.reviewRequired;
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
          siteId: widget.site!.id,
          siteName: widget.site!.name,
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
          builder: (_) => CgyyDayPage(
            demo: widget.demo,
            loader: widget.loader,
            service: widget.service,
          ),
        ),
      );
      if (mounted) await load(force: true);
    }
  }

  Future<void> cancelOrder(CgyyOrder order) async {
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
            '${order.summary}\n\n确认后仅发送一次取消请求；会重新核对状态与开始前 4 小时限制，结果不明时不会重发。',
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
        'order_id': order.id,
      });
      message = response.failure == null && response.payload != null
          ? cgyyActionResult(response.payload!).message
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
                  cgyySiteContent(widget.site!),
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
                      '实际显示 ${_displayDate(day!.date)}',
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
              if (day!.spaces.isEmpty)
                const AppleSection(
                  children: [
                    AppleEmptyState(title: '当天暂无空间时段', description: '可切换其他日期。'),
                  ],
                ),
              for (final space in day!.spaces)
                AppleSection(
                  header: Text(space.name),
                  children: [
                    if (space.slots.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('暂无时段'),
                      ),
                    for (final slot in space.slots)
                      CgyySlotRow(time: slot.time, status: slot.status),
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
                    CgyyTileContent(
                      icon: CupertinoIcons.doc_text,
                      tint: CupertinoColors.systemIndigo,
                      title: order.place.isEmpty ? '预约记录' : order.place,
                      detail: '${_displayDate(order.date)}\n${order.time}',
                      badges: [
                        AcademicBadge(
                          order.statusLabel,
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
                  for (final order in orders ?? <CgyyOrder>[])
                    if (order.canCancel)
                      AppleListTile(
                        key: ValueKey('cgyy-cancel-${order.id}'),
                        title: Text('取消 · ${order.place}'),
                        subtitle: Text(order.summary),
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
  return schoolDateWeekdayLabel(date);
}
