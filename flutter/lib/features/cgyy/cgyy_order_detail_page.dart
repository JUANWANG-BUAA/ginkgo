import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'cgyy_gateway.dart';
import 'cgyy_models.dart';

class CgyyOrderDetailPage extends StatefulWidget {
  const CgyyOrderDetailPage({
    super.key,
    required this.orderId,
    this.demo = false,
    this.loader,
    this.service,
  });

  final int orderId;
  final bool demo;
  final CgyyLoader? loader;
  final CgyyGateway? service;

  @override
  State<CgyyOrderDetailPage> createState() => _CgyyOrderDetailPageState();
}

class _CgyyOrderDetailPageState extends State<CgyyOrderDetailPage> {
  CgyyOrder? order;
  String? error;
  bool busy = false;
  int request = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool force = false}) async {
    final serial = ++request;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await cgyyOrderDetail(
        loader: widget.loader,
        service: widget.service,
        orderId: widget.orderId,
        forceRefresh: force,
      );
      if (!mounted || serial != request) return;
      setState(() {
        busy = false;
        if (result.failure != null) error = failureMessage(result.failure);
        if (result.order != null) order = result.order!;
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

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    navigationBar: CupertinoNavigationBar(
      middle: const Text('预约详情'),
      previousPageTitle: '我的预约',
      trailing: AppleGlassButton(
        label: '刷新预约详情',
        onPressed: busy ? null : () => load(force: true),
        child: const Icon(CupertinoIcons.refresh),
      ),
    ),
    child: SafeArea(
      child: ListView(
        children: [
          if (busy) const GinkgoLoadingView(label: '正在读取预约详情…'),
          if (error != null)
            AppleStatusSection(
              title: error!,
              description: order == null ? '请稍后重试。' : '正在显示上次预约详情。',
              onAction: () => load(force: true),
              error: true,
            ),
          if (order case final current?)
            SummaryStrip(
              items: [
                SummaryItem(
                  '审批状态',
                  current.statusLabel,
                  icon: CupertinoIcons.checkmark_seal,
                ),
              ],
              note: '订单查回不等于审批通过；取消资格以学校页面为准。',
            ),
          if (order case final current?)
            AppleSection(
              header: const Text('学校预约记录'),
              children: [
                AppleListTile(
                  title: Text(current.place.isEmpty ? '研讨室预约' : current.place),
                  subtitle: Text('订单 ${current.id}'),
                ),
                AppleListTile(
                  title: const Text('预约时段'),
                  subtitle: Text(
                    '${_orderDateLabel(current)}\n${_orderTimeLabel(current)}',
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

String _orderDateLabel(CgyyOrder order) {
  final date = DateTime.tryParse(order.date.trim());
  if (date == null) return order.date.isEmpty ? '日期未提供' : order.date;
  return schoolDateWeekdayLabel(date);
}

String _orderTimeLabel(CgyyOrder order) {
  final raw = order.time.trim();
  if (raw.isEmpty) return '时段未提供';
  final dateTimes = RegExp(
    r'\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:?\d{2})?',
  ).allMatches(raw).toList();
  if (dateTimes.length >= 2) {
    return schoolTimeRange(dateTimes[0].group(0)!, dateTimes[1].group(0)!);
  }
  var value = raw;
  final date = order.date.trim();
  if (date.isNotEmpty && value.startsWith(date)) {
    value = value.substring(date.length).trimLeft();
  }
  return value.replaceAllMapped(
    RegExp(r'(\d{1,2}:\d{2}):\d{2}\b'),
    (match) => match[1]!,
  );
}
