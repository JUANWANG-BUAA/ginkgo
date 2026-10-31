import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

class CampusCardPage extends StatefulWidget {
  const CampusCardPage({super.key, this.gateway});
  final CampusCardGateway? gateway;

  @override
  State<CampusCardPage> createState() => _CampusCardPageState();
}

class _CampusCardPageState extends State<CampusCardPage>
    with WidgetsBindingObserver {
  CampusCardBalanceResponse? _data;
  FailureCode? _failure;
  bool _busy = false;
  bool _showBalance = false;
  int _generation = 0;

  void _clear() {
    _generation++;
    _data = null;
    _failure = null;
    _busy = false;
    _showBalance = false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled) _clear();
  }

  @override
  void didUpdateWidget(CampusCardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.gateway, widget.gateway)) _clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) setState(_clear);
  }

  @override
  void dispose() {
    _clear();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _read() async {
    final gateway = widget.gateway;
    if (_busy || gateway == null) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _failure = null;
    });
    CampusCardBalanceResponse result;
    try {
      result = await gateway.campusCardBalance();
    } catch (_) {
      result = const CampusCardBalanceResponse(
        failure: FailureCode.serviceUnavailable,
      );
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _busy = false;
      _failure = result.failure;
      if (result.failure == null && result.balanceMinor != null) {
        _data = result;
        _showBalance = false;
      } else if (result.failure == null) {
        _failure = FailureCode.changedResponse;
      }
    });
  }

  String get _amount {
    final minor = _data?.balanceMinor;
    if (minor == null) return '';
    final cents = minor.abs();
    final whole = cents ~/ 100;
    final fraction = (cents % 100).toString().padLeft(2, '0');
    return '${minor < 0 ? '-' : ''}¥ $whole.$fraction';
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final failure = _failure;
    final summary = widget.gateway == null
        ? const SummaryItem('余额状态', '暂不支持', icon: CupertinoIcons.info_circle)
        : _busy
        ? const SummaryItem(
            '余额状态',
            '查询中',
            icon: CupertinoIcons.clock,
            tone: StatusTone.pending,
          )
        : failure != null
        ? const SummaryItem(
            '余额状态',
            '读取失败',
            icon: CupertinoIcons.exclamationmark_triangle,
            tone: StatusTone.danger,
          )
        : data != null
        ? const SummaryItem(
            '余额状态',
            '已读取',
            icon: CupertinoIcons.checkmark_circle,
            tone: StatusTone.success,
          )
        : const SummaryItem(
            '余额状态',
            '尚未查询',
            icon: CupertinoIcons.question_circle,
            tone: StatusTone.uncertain,
          );
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('校园卡'),
        // The read action lives in the navigation bar, next to the page it
        // refreshes. It is disabled while a read is in flight.
        trailing: widget.gateway == null
            ? null
            : CupertinoButton(
                key: const Key('campus-card-read'),
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 48),
                onPressed: _busy ? null : _read,
                child: _busy
                    ? const CupertinoActivityIndicator(radius: 9)
                    : const Icon(CupertinoIcons.refresh, semanticLabel: '查询余额'),
              ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            SummaryStrip(items: [summary]),
            AppleSection(
              header: const Text('校园卡余额'),
              footer: Text(
                data == null
                    ? '按需读取；不会保存到磁盘，也不提供充值、挂失或消费明细。'
                    : failure != null
                    ? '上次成功读取 ${schoolClockLabel(data.fetchedAt)}；当前余额可能过期。'
                    : '最近成功读取 ${schoolClockLabel(data.fetchedAt)}。',
              ),
              children: [
                AppleListTile(
                  leading: const Icon(CupertinoIcons.lock_shield),
                  title: Text(_showBalance ? '余额当前已显示' : '金额默认遮挡'),
                  subtitle: const Text('离开页面或进入后台后清除'),
                  trailing: data == null
                      ? null
                      : CupertinoButton(
                          key: const Key('campus-card-toggle'),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 48),
                          onPressed: () =>
                              setState(() => _showBalance = !_showBalance),
                          child: Text(
                            _showBalance ? '隐藏' : '显示',
                            semanticsLabel: _showBalance
                                ? '隐藏校园卡余额'
                                : '显示校园卡余额',
                          ),
                        ),
                ),
                if (_busy)
                  SectionFeedback(
                    key: const Key('campus-card-feedback'),
                    loading: true,
                    label: '正在查询校园卡余额',
                    hasData: data != null,
                  )
                else if (failure != null)
                  SectionFeedback(
                    key: const Key('campus-card-feedback'),
                    loading: false,
                    label: '校园卡余额',
                    hasData: data != null,
                    error: failureMessage(failure),
                    onRetry: _read,
                  ),
                if (widget.gateway == null)
                  const AppleEmptyState(
                    title: '暂不支持查询',
                    description: '当前服务未提供校园卡余额查询能力。',
                    icon: CupertinoIcons.creditcard,
                  )
                else if (data == null && !_busy && failure == null)
                  const AppleEmptyState(
                    key: Key('campus-card-empty'),
                    title: '查询后在此显示',
                    description: '点按右上角查询；金额只在本页临时显示。',
                    icon: CupertinoIcons.creditcard,
                  )
                else if (data != null)
                  Semantics(
                    container: true,
                    excludeSemantics: true,
                    label: _showBalance ? '当前余额 $_amount' : '当前余额已遮挡',
                    child: Padding(
                      padding: GinkgoSpacing.edgeInsetsBalanceHero,
                      child: Text(
                        _showBalance ? _amount : '¥ ••••',
                        key: const Key('campus-card-balance'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: GinkgoTypography.metricProminentSize,
                          fontWeight: FontWeight.w700,
                          fontFeatures: GinkgoTypography.tabularDigits,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
