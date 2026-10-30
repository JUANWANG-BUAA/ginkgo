import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/cgyy_commands.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'cgyy_booking_page.dart';
import 'cgyy_day_view.dart';
import 'cgyy_gateway.dart';
import 'cgyy_models.dart';
import 'cgyy_order_detail_page.dart';
import 'cgyy_review_page.dart';
import 'cgyy_widgets.dart';

export 'cgyy_gateway.dart' show CgyyLoader;

class CgyyDayPage extends StatefulWidget {
  const CgyyDayPage({
    super.key,
    required this.demo,
    this.site,
    this.loader,
    this.service,
    this.bookingGateway,
  });
  final bool demo;
  final CgyySite? site;
  final CgyyLoader? loader;
  final CgyyGateway? service;

  /// The CGYY write capability, injected by the composition root.
  final CgyyBookingGateway? bookingGateway;
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

  @override
  void didUpdateWidget(CgyyDayPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.loader != widget.loader ||
        oldWidget.bookingGateway != widget.bookingGateway ||
        oldWidget.demo != widget.demo ||
        oldWidget.site?.id != widget.site?.id) {
      request++;
      day = null;
      orders = null;
      error = null;
      busy = false;
      guardKnown = false;
      reviewRequired = true;
      load();
    }
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
      final result = await cgyyRead(
        loader: widget.loader,
        service: widget.service,
        kind: kind,
        siteId: widget.site?.id ?? 0,
        date: queriedDate,
        forceRefresh: force,
      );
      await readGuard(serial);
      if (!mounted || serial != request) return;
      setState(() {
        busy = false;
        if (result.failure != null) error = failureMessage(result.failure);
        if (kind == 'orders') {
          orders = result.orders ?? const [];
        } else if (result.day != null) {
          day = result.day!;
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

  /// The write capability is injected by the composition root. A page-local
  /// fallback would construct a *second* adapter with its own account binding,
  /// which is exactly how a write can land on the wrong account.
  CgyyBookingGateway? get bookingGateway {
    if (widget.demo || widget.loader != null) return null;
    return widget.bookingGateway;
  }

  Future<void> readGuard([int? serial]) async {
    final gateway = bookingGateway;
    if (gateway == null) return;
    final status = await cgyyReadWriteStatus(gateway);
    if (!mounted || (serial != null && serial != request)) return;
    setState(() {
      guardKnown = status.known;
      reviewRequired = status.reviewRequired;
    });
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
            bookingGateway: widget.bookingGateway,
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
      final confirmed = await showCgyyConfirmDialog(
        context,
        title: '取消这条预约？',
        content:
            '${order.summary}\n\n确认后仅发送一次取消请求；会重新核对状态与开始前 4 小时限制，结果不明时不会重发。',
        cancelLabel: '保留预约',
        confirmLabel: '确认取消预约',
        confirmKey: const Key('cgyy-cancel-confirm'),
        destructive: true,
      );
      if (!confirmed || !mounted) return;
      final result = await bookingGateway!.executeCgyy(
        CgyyCancelCommand(order.id),
      );
      message = result.message;
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
    final draft = await cgyyPickDate(context, selected);
    if (!mounted || draft == null) return;
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
              CgyyWriteGuardSection(
                guardKnown: guardKnown,
                enabled: !busy && !actionBusy,
                onReview: openReview,
              ),
            if (widget.site != null)
              CgyySiteQuerySection(
                site: widget.site!,
                date: date,
                enabled: !busy,
                onChooseDate: chooseDate,
              ),
            if (widget.site != null && bookingGateway != null)
              CgyyBookingEntrySection(
                enabled: !busy && !actionBusy && guardKnown && !reviewRequired,
                onTap: openBooking,
              ),
            if (busy) const GinkgoLoadingView(label: '正在读取预约信息…'),
            if (error != null)
              AppleStatusSection(
                title: error!,
                description: day != null || orders != null
                    ? '保留上次结果，请核对下方实际日期。'
                    : '需要可用的直连学校会话；可记住密码后重试。',
                onAction: () => load(force: true),
                error: true,
              ),
            if (day != null) ...cgyyDaySlots(context, day!),
            if (orders?.isEmpty == true)
              const AppleStatusSection(
                title: '暂无预约记录',
                description: '学校返回的最近记录为空。',
              ),
            if (orders != null && orders!.isNotEmpty)
              CgyyOrderListSection(
                orders: orders!,
                onOpen: (order) => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => CgyyOrderDetailPage(
                      loader: widget.loader,
                      service: widget.service,
                      orderId: order.id,
                    ),
                  ),
                ),
              ),
            if (widget.site == null && bookingGateway != null)
              CgyyOrderManageSection(
                orders: orders ?? <CgyyOrder>[],
                enabled: !busy && !actionBusy && guardKnown && !reviewRequired,
                onCancel: cancelOrder,
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
  );
}
