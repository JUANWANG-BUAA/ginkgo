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
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      navigationBar: const CupertinoNavigationBar(middle: Text('校园卡')),
      child: SafeArea(
        child: ListView(
          children: [
            AppleSection(
              header: const Text('校园卡余额'),
              footer: const Text('仅在本页临时查看，不保存到磁盘；不提供充值、挂失或消费明细。'),
              children: [
                AppleListTile(
                  leading: const Icon(CupertinoIcons.lock_shield),
                  title: const Text('金额默认遮挡'),
                  subtitle: const Text('离开页面或进入后台后清除'),
                ),
                if (widget.gateway == null)
                  const Padding(
                    padding: GinkgoSpacing.edgeInsetsCard,
                    child: Text('当前服务未提供校园卡余额查询能力。'),
                  )
                else
                  CupertinoButton(
                    key: const Key('campus-card-read'),
                    onPressed: _busy ? null : _read,
                    child: Text(data == null ? '查询余额' : '刷新余额'),
                  ),
                if (_busy) const Center(child: GinkgoActivity(size: 24)),
                if (failure != null)
                  Padding(
                    padding: GinkgoSpacing.edgeInsetsCard,
                    child: Text(
                      '${failureMessage(failure)}${data == null ? '' : ' 保留本页上次结果，可能过期。'}',
                    ),
                  ),
                if (data != null) ...[
                  AppleListTile(
                    title: const Text('当前余额'),
                    subtitle: Text(
                      '最近成功读取 ${schoolClockLabel(data.fetchedAt)}',
                    ),
                    trailing: CupertinoButton(
                      key: const Key('campus-card-toggle'),
                      padding: EdgeInsets.zero,
                      onPressed: () =>
                          setState(() => _showBalance = !_showBalance),
                      child: Text(_showBalance ? '隐藏' : '显示'),
                    ),
                  ),
                  Padding(
                    padding: GinkgoSpacing.edgeInsetsDesktopPage,
                    child: Center(
                      child: Semantics(
                        label: _showBalance ? '校园卡余额 $_amount' : '校园卡余额已遮挡',
                        child: Text(
                          _showBalance ? _amount : '¥ ••••',
                          key: const Key('campus-card-balance'),
                          style: GinkgoTypography.title,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
