import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/failure_code.dart';
import 'package:ginkgo_mirror/application/finance.dart';
import 'package:ginkgo_mirror/widgets/liquid_vial_gauge.dart';
import 'package:ginkgo_mirror/widgets/status_chip.dart';
import 'package:ginkgo_mirror/widgets/telemetry_instrument_card.dart';

String formatCompactYuan(int minor) {
  final cents = minor.abs();
  final whole = cents ~/ 100;
  final fraction = (cents % 100).toString().padLeft(2, '0');
  return '${minor < 0 ? '-' : ''}¥$whole.$fraction';
}

String _monthKeyOf(FinanceIncomeEntry entry) {
  final raw = entry.recordedDate?.trim() ?? '';
  if (raw.length >= 7 && raw[4] == '-') {
    return raw.substring(0, 7);
  }
  if (entry.year != null && entry.month != null) {
    return '${entry.year}-${entry.month!.padLeft(2, '0')}';
  }
  return entry.year ?? '近期入账';
}

/// Top instrument panel for [FinancePage]:
/// - When `showAmounts == false`: renders a frosted privacy vault vial (`••`)
///   and monthly record-count bars without leaking monetary ratios.
/// - When `showAmounts == true`: animates the net-to-gross payout vial,
///   net vs tax dual-segment bar, and monthly net income distribution bars.
class FinanceInstrumentPanel extends StatelessWidget {
  const FinanceInstrumentPanel({
    super.key,
    required this.supported,
    required this.busy,
    required this.data,
    required this.failure,
    required this.showAmounts,
  });

  final bool supported;
  final bool busy;
  final FinanceIncomeReport? data;
  final FailureCode? failure;
  final bool showAmounts;

  @override
  Widget build(BuildContext context) {
    final report = data;
    final (statusLabel, statusTone) = !supported
        ? ('暂不支持', StatusTone.uncertain)
        : busy
        ? ('查询中', StatusTone.pending)
        : failure != null
        ? ('读取失败', StatusTone.danger)
        : report != null
        ? ('已读取', StatusTone.success)
        : ('尚未查询', StatusTone.uncertain);

    if (report == null) {
      return TelemetryInstrumentCard(
        vial: const LiquidVialWell(
          code: 'FIN',
          readout: '--',
          fillRatio: null,
          palette: LiquidPalette.violet,
          scaleTicks: ['- 75%', '- 50%', '- 25%'],
          footer: '按需只读',
          semanticLabel: '财务收入实发比例',
        ),
        title: '学生财务发放遥测',
        statusLabel: statusLabel,
        statusTone: statusTone,
        headline: busy
            ? '正在查询财务发放记录…'
            : failure != null
            ? '本次查询未成功'
            : '待读取个人收入流水',
        subheadline: '不落盘保存 · 自动剥离银行卡与证件号',
        meters: const [
          TelemetryMeterData(label: '数据留存', trailing: '仅内存 · 离页清除'),
          TelemetryMeterData(label: '金额保护', trailing: '默认遮挡'),
        ],
      );
    }

    final entries = report.entries;
    if (entries.isEmpty) {
      return TelemetryInstrumentCard(
        vial: const LiquidVialWell(
          code: 'FIN',
          readout: '0笔',
          fillRatio: 0.0,
          palette: LiquidPalette.emerald,
          scaleTicks: ['- 75%', '- 50%', '- 25%'],
          footer: '无记录',
          semanticLabel: '财务收入记录为空',
        ),
        title: '学生财务发放遥测',
        statusLabel: statusLabel,
        statusTone: statusTone,
        headline: '当前无录入记录',
        subheadline: '学校财务系统暂未返回发放流水',
        meters: const [
          TelemetryMeterData(label: '记录笔数', trailing: '0 笔'),
        ],
      );
    }

    if (!showAmounts) {
      final byMonthCounts = <String, int>{};
      for (final e in entries) {
        final m = _monthKeyOf(e);
        byMonthCounts[m] = (byMonthCounts[m] ?? 0) + 1;
      }
      final maxCount = byMonthCounts.values.fold<int>(
        1,
        (prev, v) => v > prev ? v : prev,
      );
      final topMonths = byMonthCounts.entries.take(3).toList(growable: false);

      return TelemetryInstrumentCard(
        vial: LiquidVialWell(
          code: 'FIN',
          readout: '••',
          fillRatio: 0.68,
          frosted: true,
          palette: LiquidPalette.violet,
          scaleTicks: const ['- 高位', '- 中位', '- 基础'],
          footer: '共 ${entries.length} 笔',
          semanticLabel: '财务收入金额已隐私遮挡',
        ),
        title: '学生财务发放遥测',
        statusLabel: statusLabel,
        statusTone: statusTone,
        headline: '已加载 ${entries.length} 笔发放记录',
        subheadline: '金额处于隐私遮挡态 · 点击下方「显示」查看统计',
        sectionTitle: '月度入账频次',
        sectionBadge: '隐私保护',
        sectionBadgeTone: StatusTone.neutral,
        meters: [
          for (final item in topMonths)
            TelemetryMeterData(
              label: item.key,
              ratio: item.value / maxCount,
              trailing: '${item.value} 笔',
              startColor: const Color(0xFF6366F1),
              endColor: const Color(0xFFA855F7),
            ),
        ],
      );
    }

    var totalGross = 0;
    var totalTax = 0;
    var totalNet = 0;
    final byMonthNet = <String, int>{};
    for (final e in entries) {
      final net = e.netMinor ?? e.grossMinor ?? 0;
      final gross = e.grossMinor ?? net;
      final tax = e.taxMinor ?? (gross > net ? gross - net : 0);
      totalGross += gross;
      totalTax += tax;
      totalNet += net;
      final m = _monthKeyOf(e);
      byMonthNet[m] = (byMonthNet[m] ?? 0) + net;
    }

    final denom = totalGross > 0 ? totalGross : (totalNet > 0 ? totalNet : 1);
    final netRatio = (totalNet / denom).clamp(0.0, 1.0);
    final taxRatio = (totalTax / denom).clamp(0.0, 1.0);
    final netPct = (netRatio * 100).round();

    final maxMonthNet = byMonthNet.values.fold<int>(
      1,
      (prev, v) => v > prev ? v : prev,
    );
    final monthEntries = byMonthNet.entries.take(3).toList(growable: false);

    return TelemetryInstrumentCard(
      vial: LiquidVialWell(
        code: 'FIN',
        readout: '$netPct%',
        fillRatio: netRatio,
        palette: LiquidPalette.emerald,
        scaleTicks: [
          '- ${formatCompactYuan((denom * 0.75).round())}',
          '- ${formatCompactYuan((denom * 0.50).round())}',
          '- ${formatCompactYuan((denom * 0.25).round())}',
        ],
        footer: '实发率 $netPct%',
        semanticLabel: '财务收入税后实发比例',
      ),
      title: '学生财务发放遥测',
      statusLabel: statusLabel,
      statusTone: statusTone,
      headline: '累计实发 ${formatCompactYuan(totalNet)}',
      subheadline:
          '共 ${entries.length} 笔 · 应发 ${formatCompactYuan(totalGross)} · 税额 ${formatCompactYuan(totalTax)}',
      segments: [
        BarSegment(
          fraction: netRatio,
          startColor: const Color(0xFF059669),
          endColor: const Color(0xFF34D399),
        ),
        if (taxRatio > 0)
          BarSegment(
            fraction: taxRatio,
            startColor: const Color(0xFFD97706),
            endColor: const Color(0xFFFBBF24),
          ),
      ],
      barLeadingCaption: '实发占比 $netPct%',
      barTrailingCaption: totalTax > 0
          ? '代扣税 ${formatCompactYuan(totalTax)}'
          : '无代扣税额',
      sectionTitle: '月度发放分布',
      sectionBadge: '已解锁',
      sectionBadgeTone: StatusTone.success,
      meters: [
        for (final m in monthEntries)
          TelemetryMeterData(
            label: m.key,
            ratio: (m.value / maxMonthNet).clamp(0.0, 1.0),
            trailing: formatCompactYuan(m.value),
            startColor: const Color(0xFF0B68F5),
            endColor: const Color(0xFF38BDF8),
          ),
      ],
    );
  }
}
