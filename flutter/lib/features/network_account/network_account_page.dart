import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/failure_code.dart';
import 'package:ginkgo_mirror/application/network_account.dart';
import 'package:ginkgo_mirror/application/student_service_links.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/widgets/school_links.dart';

import 'network_account_visuals.dart';

class NetworkAccountPage extends StatefulWidget {
  const NetworkAccountPage({super.key, this.gateway, this.officialLinks});

  final NetworkAccountGateway? gateway;
  final StudentServiceLinksGateway? officialLinks;

  @override
  State<NetworkAccountPage> createState() => _NetworkAccountPageState();
}

class _NetworkAccountPageState extends State<NetworkAccountPage>
    with WidgetsBindingObserver {
  NetworkAccountReport? _data;
  FailureCode? _failure;
  bool _busy = false;
  bool _showBalance = false;
  int _selectedProduct = 0;
  int _generation = 0;

  void _clear() {
    _generation++;
    _data = null;
    _failure = null;
    _busy = false;
    _showBalance = false;
    _selectedProduct = 0;
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
  void didUpdateWidget(NetworkAccountPage oldWidget) {
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
    NetworkAccountRead result;
    try {
      result = await gateway.loadNetworkAccount();
    } catch (_) {
      result = const NetworkAccountRead(
        failure: FailureCode.serviceUnavailable,
      );
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _busy = false;
      _failure = result.failure;
      if (result.failure == null && result.data != null) {
        _data = result.data;
        _showBalance = false;
        _selectedProduct = 0;
      } else if (result.failure == null) {
        _failure = FailureCode.changedResponse;
      }
    });
  }

  String get _netFeeAmount {
    final minor = _data?.netFeeMinor;
    if (minor == null) return '--';
    final cents = minor.abs();
    final whole = cents ~/ 100;
    final fraction = (cents % 100).toString().padLeft(2, '0');
    return '${minor < 0 ? '-' : ''}¥ $whole.$fraction';
  }

  Future<void> _openGuide() async {
    final url = widget.officialLinks?.studentServiceUrl(
      'official-network-guide',
    );
    if (url == null || url.isEmpty) return;
    var opened = false;
    try {
      opened = await openSchoolLink(context, url);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) await showSchoolLinkError(context);
  }

  static const Size _toolbarTapSize = Size(48, 48);

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final failure = _failure;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('网费与流量'),
        trailing: widget.gateway == null
            ? null
            : CupertinoButton(
                key: const Key('network-account-read'),
                padding: EdgeInsets.zero,
                minimumSize: _toolbarTapSize,
                onPressed: _busy ? null : _read,
                child: _busy
                    ? const CupertinoActivityIndicator(radius: 9)
                    : const Icon(
                        CupertinoIcons.refresh,
                        semanticLabel: '查询网费与流量',
                      ),
              ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            NetworkAccountInstrumentPanel(
              supported: widget.gateway != null,
              busy: _busy,
              data: data,
              failure: failure,
              selectedProduct: _selectedProduct,
              onSelectProduct: (idx) => setState(() => _selectedProduct = idx),
            ),
            AppleSection(
              header: const Text('网费余额'),
              footer: Text(
                data == null
                    ? '按需只读读取；不落盘，不接入资金写操作。'
                    : '最近读取 ${schoolClockLabel(data.fetchedAt)}。',
              ),
              children: [
                AppleListTile(
                  leading: const GinkgoIconTile(
                    icon: CupertinoIcons.lock_shield,
                    size: 34,
                    iconSize: 18,
                    color: GinkgoColors.accent,
                  ),
                  leadingSize: 34,
                  title: Text(_showBalance ? '余额当前已显示' : '金额默认遮挡'),
                  subtitle: const Text('离开页面或进入后台后自动清除'),
                  trailing: data?.netFeeMinor == null
                      ? null
                      : CupertinoButton(
                          key: const Key('network-account-toggle'),
                          padding: EdgeInsets.zero,
                          minimumSize: _toolbarTapSize,
                          onPressed: () =>
                              setState(() => _showBalance = !_showBalance),
                          child: Text(
                            _showBalance ? '隐藏' : '显示',
                            semanticsLabel: _showBalance ? '隐藏网费余额' : '显示网费余额',
                          ),
                        ),
                ),
                if (_busy)
                  SectionFeedback(
                    key: const Key('network-account-feedback'),
                    loading: true,
                    label: '正在读取门户指标与流量明细',
                    hasData: data != null,
                  )
                else if (failure != null)
                  SectionFeedback(
                    key: const Key('network-account-feedback'),
                    loading: false,
                    label: '网费与流量',
                    hasData: data != null,
                    error: failureMessage(failure),
                    onRetry: _read,
                  )
                else if (data != null &&
                    data.netFeeMinor == null &&
                    (data.portalFailure ?? data.netFeeFailure) != null)
                  SectionFeedback(
                    key: const Key('network-portal-feedback'),
                    loading: false,
                    label: '网费余额',
                    hasData: false,
                    error: failureMessage(
                      (data.portalFailure ?? data.netFeeFailure)!,
                    ),
                    onRetry: _read,
                  ),
                if (widget.gateway == null)
                  const AppleEmptyState(
                    title: '暂不支持查询',
                    description: '当前服务未提供网费与流量查询能力。',
                    icon: CupertinoIcons.wifi,
                  )
                else if (data == null && !_busy && failure == null)
                  AppleEmptyState(
                    key: const Key('network-account-unqueried'),
                    title: '查询后在此显示',
                    description: '仅在当前页面内存中临时展示网费、流量与门户指标。',
                    icon: CupertinoIcons.wifi,
                    action: '读取账户与流量',
                    onAction: _read,
                  )
                else if (data?.netFeeMinor != null)
                  Semantics(
                    container: true,
                    excludeSemantics: true,
                    label: _showBalance
                        ? '当前网费余额 $_netFeeAmount'
                        : '当前网费余额已遮挡',
                    child: Padding(
                      padding: GinkgoSpacing.edgeInsetsBalanceHero,
                      child: Column(
                        children: [
                          Text(
                            _showBalance ? _netFeeAmount : '¥ ••••',
                            key: const Key('network-fee-balance'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: GinkgoTypography.metricProminentSize,
                              fontWeight: FontWeight.w700,
                              fontFeatures: GinkgoTypography.tabularDigits,
                            ),
                          ),
                          const SizedBox(height: GinkgoSpacing.xs),
                          Text(
                            _showBalance ? '统一门户网费账户余额' : '点击右上角「显示」解锁实时金额',
                            style: GinkgoTypography.caption.copyWith(
                              color: CupertinoColors.secondaryLabel.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (data != null) ...[
              AppleSection(
                header: const Text('校园网流量明细'),
                footer: const Text('免费剩余已按 1024 进制合计套餐可用流量。'),
                children: [
                  if (data.trafficFailure != null)
                    SectionFeedback(
                      key: const Key('network-traffic-feedback'),
                      loading: false,
                      label: '流量明细',
                      hasData: false,
                      error: failureMessage(data.trafficFailure!),
                      onRetry: _read,
                    )
                  else if (data.trafficProducts.isEmpty)
                    const AppleEmptyState(
                      title: '暂无流量产品记录',
                      description: '校园网自助服务当前未返回在用流量产品。',
                      icon: CupertinoIcons.wifi_slash,
                    )
                  else
                    for (var i = 0; i < data.trafficProducts.length; i++)
                      AppleListTile(
                        key: ValueKey('traffic-product-$i'),
                        leading: GinkgoIconTile(
                          icon: CupertinoIcons.wifi,
                          size: 34,
                          iconSize: 18,
                          selected: i == _selectedProduct,
                          color: GinkgoColors.resourceBlue,
                        ),
                        leadingSize: 34,
                        title: Text(
                          data.trafficProducts[i].productName ??
                              '网络产品 ${i + 1}',
                        ),
                        subtitle: Text(
                          '已用 ${data.trafficProducts[i].usedText} · '
                          '免费剩余 ${data.trafficProducts[i].freeRemainingText}\n'
                          '计费剩余 ${data.trafficProducts[i].paidRemainingText}'
                          '${data.trafficProducts[i].packageCount > 0 ? ' · 含 ${data.trafficProducts[i].packageCount} 个套餐' : ''}',
                        ),
                        onTap: data.trafficProducts.length > 1
                            ? () => setState(() => _selectedProduct = i)
                            : null,
                      ),
                ],
              ),
              AppleSection(
                header: const Text('门户个人指标'),
                footer: const Text('仅读取统计数量与剩余容量，不读取内容。'),
                children: [
                  AppleListTile(
                    leading: const GinkgoIconTile(
                      icon: CupertinoIcons.book,
                      size: 34,
                      iconSize: 18,
                      color: GinkgoColors.resourceTeal,
                    ),
                    leadingSize: 34,
                    title: const Text('待还图书'),
                    trailing: Text(data.unreturnedBooks?.displayText ?? '--'),
                  ),
                  AppleListTile(
                    leading: const GinkgoIconTile(
                      icon: CupertinoIcons.mail,
                      size: 34,
                      iconSize: 18,
                      color: GinkgoColors.resourcePurple,
                    ),
                    leadingSize: 34,
                    title: const Text('未读校内邮件'),
                    trailing: Text(data.unreadMail?.displayText ?? '--'),
                  ),
                  if (widget.officialLinks?.studentServiceUrl(
                        'official-network-guide',
                      ) !=
                      null)
                    AppleListTile(
                      leading: const GinkgoIconTile(
                        icon: CupertinoIcons.globe,
                        size: 34,
                        iconSize: 18,
                        color: GinkgoColors.accent,
                      ),
                      leadingSize: 34,
                      title: const Text('网络服务指南'),
                      subtitle: const Text('前往网络信息中心官方说明 ↗'),
                      trailing: const CupertinoListTileChevron(),
                      onTap: _openGuide,
                    ),
                ],
              ),
            ],
            const SizedBox(height: GinkgoSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
