import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/campus_card.dart';
import 'package:ginkgo_mirror/application/contracts.dart'
    show CampusCardBalanceResponse, FailureCode;
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';
import 'package:ginkgo_mirror/widgets/liquid_vial_gauge.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/widgets/telemetry_instrument_card.dart';

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

  Widget _buildInstrument(CampusCardBalanceResponse? data, FailureCode? failure) {
    final supported = widget.gateway != null;
    final (statusLabel, statusTone) = !supported
        ? ('暂不支持', StatusTone.uncertain)
        : _busy
        ? ('查询中', StatusTone.pending)
        : failure != null
        ? ('读取失败', StatusTone.danger)
        : data != null
        ? ('已读取', StatusTone.success)
        : ('尚未查询', StatusTone.uncertain);

    final minor = data?.balanceMinor;
    // Reference ¥200 comfort gauge when unmasked; frosted when masked.
    const refMinor = 20000.0;
    final unmaskedRatio = (minor != null && _showBalance)
        ? (minor / refMinor).clamp(0.0, 1.0)
        : null;
    final lowBalance = minor != null && _showBalance && minor < 3000;

    final vial = LiquidVialWell(
      code: 'CARD',
      readout: data == null
          ? '--'
          : !_showBalance
          ? '••'
          : '${((unmaskedRatio ?? 0) * 100).round()}%',
      fillRatio: data == null ? null : (_showBalance ? unmaskedRatio : 0.62),
      frosted: data != null && !_showBalance,
      palette: data == null
          ? LiquidPalette.cobalt
          : !_showBalance
          ? LiquidPalette.violet
          : lowBalance
          ? LiquidPalette.amber
          : LiquidPalette.emerald,
      scaleTicks: _showBalance && data != null
          ? const ['- ¥150', '- ¥100', '- ¥50']
          : const ['- 高位', '- 常规', '- 预警'],
      footer: data == null
          ? '按需只读'
          : _showBalance
          ? (lowBalance ? '建议留意余额' : '日常充裕')
          : '隐私锁定',
      semanticLabel: '校园卡日常水位参考',
    );

    return TelemetryInstrumentCard(
      vial: vial,
      title: '北航校园一卡通',
      statusLabel: statusLabel,
      statusTone: statusTone,
      headline: data == null
          ? (_busy ? '正在查询航财通余额…' : '待读取校园卡实时余额')
          : _showBalance
          ? (lowBalance ? '当前水位偏低' : '当前日常消费充裕')
          : '余额已读取（默认遮挡）',
      subheadline: data == null
          ? '仅内存按需查询 · 离开页面自动清除'
          : '以 ¥200 日常参考线映射试管液位',
      segments: _showBalance && unmaskedRatio != null
          ? [
              BarSegment(
                fraction: unmaskedRatio,
                startColor: lowBalance
                    ? const Color(0xFFD97706)
                    : const Color(0xFF059669),
                endColor: lowBalance
                    ? const Color(0xFFFBBF24)
                    : const Color(0xFF34D399),
              ),
            ]
          : const [],
      barLeadingCaption: _showBalance && unmaskedRatio != null
          ? '日常参考水位（满格 ¥200）'
          : null,
      meters: const [
        TelemetryMeterData(label: '数据留存', trailing: '仅内存 · 不落盘'),
        TelemetryMeterData(label: '安全边界', trailing: '纯只读 · 无写操作'),
      ],
    );
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
        middle: const Text('校园卡'),
        trailing: widget.gateway == null
            ? null
            : CupertinoButton(
                key: const Key('campus-card-read'),
                padding: EdgeInsets.zero,
                minimumSize: _toolbarTapSize,
                onPressed: _busy ? null : _read,
                child: _busy
                    ? const CupertinoActivityIndicator(radius: 9)
                    : const Icon(CupertinoIcons.refresh, semanticLabel: '查询余额'),
              ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            _buildInstrument(data, failure),
            AppleSection(
              header: const Text('校园卡余额'),
              footer: Text(
                data == null
                    ? '按需只读查询；不写入磁盘，不接入资金卡务写操作。'
                    : failure != null
                    ? '上次成功读取 ${schoolClockLabel(data.fetchedAt)}；当前余额可能过期。'
                    : '最近成功读取 ${schoolClockLabel(data.fetchedAt)}。',
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
                  subtitle: const Text('离开页面或进入后台后清除'),
                  trailing: data == null
                      ? null
                      : CupertinoButton(
                          key: const Key('campus-card-toggle'),
                          padding: EdgeInsets.zero,
                          minimumSize: _toolbarTapSize,
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
                    description: '当前模式未提供校园卡余额查询。',
                    icon: CupertinoIcons.creditcard,
                  )
                else if (data == null && !_busy && failure == null)
                  AppleEmptyState(
                    key: const Key('campus-card-unqueried'),
                    title: '查询后在此显示',
                    description: '点击右上角读取当前登录账号的校园卡余额。',
                    icon: CupertinoIcons.creditcard,
                    action: '读取当前余额',
                    onAction: _read,
                  )
                else if (data != null)
                  Semantics(
                    container: true,
                    excludeSemantics: true,
                    label: _showBalance ? '当前校园卡余额 $_amount' : '当前校园卡余额已遮挡',
                    child: Padding(
                      padding: GinkgoSpacing.edgeInsetsBalanceHero,
                      child: Column(
                        children: [
                          Text(
                            _showBalance ? _amount : '¥ ••••',
                            key: const Key('campus-card-balance'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: GinkgoTypography.metricProminentSize,
                              fontWeight: FontWeight.w700,
                              fontFeatures: GinkgoTypography.tabularDigits,
                            ),
                          ),
                          const SizedBox(height: GinkgoSpacing.xs),
                          Text(
                            _showBalance ? '航财通实时账户余额' : '点击上方「显示」查看具体余额',
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
            const SizedBox(height: GinkgoSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
