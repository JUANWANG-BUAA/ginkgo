import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/failure_code.dart';
import 'package:ginkgo_mirror/application/finance.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'finance_visuals.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key, this.gateway});

  final FinanceIncomeGateway? gateway;

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> with WidgetsBindingObserver {
  FinanceIncomeReport? _data;
  FailureCode? _failure;
  bool _busy = false;
  bool _showAmounts = false;
  int _generation = 0;

  void _clear() {
    _generation++;
    _data = null;
    _failure = null;
    _busy = false;
    _showAmounts = false;
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
  void didUpdateWidget(FinancePage oldWidget) {
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
    FinanceIncomeRead result;
    try {
      result = await gateway.loadFinanceIncomes();
    } catch (_) {
      result = const FinanceIncomeRead(failure: FailureCode.serviceUnavailable);
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _busy = false;
      _failure = result.failure;
      if (result.failure == null && result.data != null) {
        _data = result.data;
        _showAmounts = false;
      } else if (result.failure == null) {
        _failure = FailureCode.changedResponse;
      }
    });
  }

  static String _formatMinor(int? minor, {required bool visible}) {
    if (!visible) return '¥ ••••';
    if (minor == null) return '--';
    final cents = minor.abs();
    final whole = cents ~/ 100;
    final fraction = (cents % 100).toString().padLeft(2, '0');
    return '${minor < 0 ? '-' : ''}¥ $whole.$fraction';
  }

  static String _entrySubtitle(
    FinanceIncomeEntry entry, {
    required bool visible,
  }) {
    final firstLine = <String>[];
    final date =
        entry.recordedDate ??
        (entry.year != null && entry.month != null
            ? '${entry.year}-${entry.month}'
            : entry.year);
    if (date != null && date.isNotEmpty) {
      firstLine.add(date);
    }
    if (entry.description != null && entry.description!.isNotEmpty) {
      firstLine.add(entry.description!);
    }
    final base = firstLine.isEmpty ? '单号 ${entry.id}' : firstLine.join(' · ');
    if (!visible) return base;
    final hasDeduction =
        (entry.taxMinor != null && entry.taxMinor! > 0) ||
        (entry.grossMinor != null &&
            entry.netMinor != null &&
            entry.grossMinor != entry.netMinor);
    if (!hasDeduction) return base;
    final taxLine = <String>[
      if (entry.grossMinor != null)
        '应发 ${_formatMinor(entry.grossMinor, visible: true)}',
      if (entry.taxMinor != null)
        '税额 ${_formatMinor(entry.taxMinor, visible: true)}',
      if (entry.taxRate != null && entry.taxRate!.isNotEmpty)
        '税率 ${entry.taxRate}',
    ];
    return taxLine.isEmpty ? base : '$base\n${taxLine.join(' · ')}';
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
        middle: const Text('财务收入'),
        trailing: widget.gateway == null
            ? null
            : CupertinoButton(
                key: const Key('finance-read'),
                padding: EdgeInsets.zero,
                minimumSize: _toolbarTapSize,
                onPressed: _busy ? null : _read,
                child: _busy
                    ? const CupertinoActivityIndicator(radius: 9)
                    : const Icon(
                        CupertinoIcons.refresh,
                        semanticLabel: '查询财务收入',
                      ),
              ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            FinanceInstrumentPanel(
              supported: widget.gateway != null,
              busy: _busy,
              data: data,
              failure: failure,
              showAmounts: _showAmounts,
            ),
            AppleSection(
              header: const Text('隐私与遮挡'),
              footer: Text(
                data == null
                    ? '按需只读查询；不落盘且剥离银行卡与证件号。'
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
                  title: Text(_showAmounts ? '金额当前已显示' : '金额默认遮挡'),
                  subtitle: const Text('离开页面或进入后台后自动清除'),
                  trailing: data == null
                      ? null
                      : CupertinoButton(
                          key: const Key('finance-toggle'),
                          padding: EdgeInsets.zero,
                          minimumSize: _toolbarTapSize,
                          onPressed: () =>
                              setState(() => _showAmounts = !_showAmounts),
                          child: Text(
                            _showAmounts ? '隐藏' : '显示',
                            semanticsLabel: _showAmounts ? '隐藏收入金额' : '显示收入金额',
                          ),
                        ),
                ),
                if (_busy)
                  SectionFeedback(
                    key: const Key('finance-feedback'),
                    loading: true,
                    label: '正在查询财务收入记录',
                    hasData: data != null,
                  )
                else if (failure != null)
                  SectionFeedback(
                    key: const Key('finance-feedback'),
                    loading: false,
                    label: '财务收入',
                    hasData: data != null,
                    error: failureMessage(failure),
                    onRetry: _read,
                  ),
              ],
            ),
            if (widget.gateway == null)
              const AppleSection(
                children: [
                  AppleEmptyState(
                    title: '暂不支持查询',
                    description: '当前服务未提供财务收入查询能力。',
                    icon: CupertinoIcons.money_yen_circle,
                  ),
                ],
              )
            else if (data == null && !_busy && failure == null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    key: const Key('finance-unqueried'),
                    title: '查询后在此显示',
                    description: '按需读取当前账号发放记录，不在磁盘保存。',
                    icon: CupertinoIcons.money_yen_circle,
                    action: '读取收入记录',
                    onAction: _read,
                  ),
                ],
              )
            else if (data != null && data.entries.isEmpty)
              const AppleSection(
                header: Text('收入明细'),
                children: [
                  AppleEmptyState(
                    key: Key('finance-empty-confirmed'),
                    title: '暂无财务收入记录',
                    description: '学校财务查询系统当前未返回录入记录。',
                    icon: CupertinoIcons.doc_text,
                  ),
                ],
              )
            else if (data != null)
              AppleSection(
                header: Text('收入明细（共 ${data.entries.length} 笔）'),
                children: [
                  for (final entry in data.entries)
                    AppleListTile(
                      key: ValueKey('finance-entry-${entry.id}'),
                      leading: const GinkgoIconTile(
                        icon: CupertinoIcons.money_yen_circle_fill,
                        size: 34,
                        iconSize: 18,
                        color: GinkgoColors.resourceTeal,
                      ),
                      leadingSize: 34,
                      title: Text(
                        entry.project?.isNotEmpty == true
                            ? entry.project!
                            : '发放记录',
                      ),
                      subtitle: Text(
                        _entrySubtitle(entry, visible: _showAmounts),
                      ),
                      trailing: Text(
                        _formatMinor(
                          entry.netMinor ?? entry.grossMinor,
                          visible: _showAmounts,
                        ),
                        style: GinkgoTypography.subheadline.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: GinkgoTypography.tabularDigits,
                          color: _showAmounts
                              ? AppleDesign.statusSuccess.resolveFrom(context)
                              : CupertinoColors.label.resolveFrom(context),
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
