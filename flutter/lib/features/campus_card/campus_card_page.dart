import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:ginkgo_mirror/application/campus_card.dart';
import 'package:ginkgo_mirror/application/contracts.dart'
    show CampusCardBalanceResponse, FailureCode;
import 'package:ginkgo_mirror/application/session_memory_cache.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/liquid_vial_gauge.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/widgets/telemetry_instrument_card.dart';

class CampusCardPage extends StatefulWidget {
  const CampusCardPage({super.key, this.gateway});
  final CampusCardGateway? gateway;

  @override
  State<CampusCardPage> createState() => _CampusCardPageState();
}

class _CampusCardPageState extends State<CampusCardPage> {
  CampusCardBalanceResponse? _data;
  FailureCode? _failure;
  bool _busy = false;
  bool _showBalance = true;
  bool _prefLoaded = false;
  int _generation = 0;

  void _resetForGateway() {
    _generation++;
    final gateway = widget.gateway;
    _data = gateway == null
        ? null
        : SessionMemoryCache.shared.readCampusCard(gateway);
    _failure = null;
    _busy = false;
  }

  @override
  void initState() {
    super.initState();
    _resetForGateway();
    if (widget.gateway != null && _data == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _data == null && !_busy) unawaited(_read());
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prefLoaded) {
      _prefLoaded = true;
      _showBalance = AppPreferencesScope.of(context).revealSensitiveAmounts;
    }
  }

  @override
  void didUpdateWidget(CampusCardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.gateway, widget.gateway)) {
      _resetForGateway();
      if (widget.gateway != null && _data == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _data == null && !_busy) unawaited(_read());
        });
      }
    }
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
        SessionMemoryCache.shared.writeCampusCard(gateway, result);
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
          ? '余额'
          : _showBalance
          ? (lowBalance ? '余额偏低' : '余额充裕')
          : '已隐藏',
      semanticLabel: '校园卡日常水位参考',
    );

    return TelemetryInstrumentCard(
      vial: vial,
      title: '北航校园一卡通',
      statusLabel: statusLabel,
      statusTone: statusTone,
      headline: data == null
          ? (_busy ? '正在查询余额…' : '待读取余额')
          : _showBalance
          ? (lowBalance ? '余额偏低' : '日常消费充裕')
          : '余额已隐藏',
      subheadline: data == null ? '' : '以 ¥200 日常参考线估算',
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
      meters: const [],
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
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (data != null)
                    CupertinoButton(
                      key: const Key('campus-card-toggle'),
                      padding: EdgeInsets.zero,
                      minimumSize: _toolbarTapSize,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        final next = !_showBalance;
                        setState(() => _showBalance = next);
                        unawaited(
                          AppPreferencesScope.of(
                            context,
                          ).setRevealSensitiveAmounts(next),
                        );
                      },
                      child: Icon(
                        _showBalance
                            ? CupertinoIcons.eye_slash
                            : CupertinoIcons.eye,
                        semanticLabel: _showBalance ? '隐藏校园卡余额' : '显示校园卡余额',
                      ),
                    ),
                  CupertinoButton(
                    key: const Key('campus-card-read'),
                    padding: EdgeInsets.zero,
                    minimumSize: _toolbarTapSize,
                    onPressed: _busy ? null : _read,
                    child: _busy
                        ? const CupertinoActivityIndicator(radius: 9)
                        : const Icon(
                            CupertinoIcons.refresh,
                            semanticLabel: '查询余额',
                          ),
                  ),
                ],
              ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            _buildInstrument(data, failure),
            AppleSection(
              header: const Text('校园卡余额'),
              footer: data == null
                  ? null
                  : Text(
                      failure != null
                          ? '上次读取 ${schoolClockLabel(data.fetchedAt)}；当前余额可能过期。'
                          : '更新于 ${schoolClockLabel(data.fetchedAt)}',
                    ),
              children: [
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
                    description: '点击下方按钮读取当前余额。',
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
            const SizedBox(height: GinkgoSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
