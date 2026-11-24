import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/failure_code.dart';
import 'package:ginkgo_mirror/application/network_account.dart';
import 'package:ginkgo_mirror/widgets/liquid_vial_gauge.dart';
import 'package:ginkgo_mirror/widgets/status_chip.dart';
import 'package:ginkgo_mirror/widgets/telemetry_instrument_card.dart';

/// Pure presentation parser converting human traffic text (e.g. `12.5G`, `512M`, `0`)
/// into 1024-based bytes for ratio and tick visualization; returns `null` when unknown.
double? parseTrafficBytesForChart(String raw) {
  final compact = raw.replaceAll(' ', '').replaceAll(',', '');
  if (compact.isEmpty || compact.startsWith('-')) return null;
  final match = RegExp(r'^(\d+(?:\.\d+)?)([a-zA-Z]*)$').firstMatch(compact);
  if (match == null) return null;
  final value = double.tryParse(match.group(1)!);
  if (value == null || !value.isFinite) return null;
  final unit = (match.group(2) ?? '').toLowerCase();
  if (unit.isEmpty) return value == 0 ? 0.0 : null;
  final scale = switch (unit) {
    'b' || 'byte' || 'bytes' => 1.0,
    'k' || 'kb' || 'kib' => 1024.0,
    'm' || 'mb' || 'mib' => 1024.0 * 1024.0,
    'g' || 'gb' || 'gib' => 1024.0 * 1024.0 * 1024.0,
    't' || 'tb' || 'tib' => 1024.0 * 1024.0 * 1024.0 * 1024.0,
    _ => -1.0,
  };
  return scale < 0 ? null : value * scale;
}

String formatTrafficScaleTick(double bytes) {
  const gb = 1024.0 * 1024.0 * 1024.0;
  const mb = 1024.0 * 1024.0;
  if (bytes >= gb) {
    final g = bytes / gb;
    final text = g >= 10 || (g - g.roundToDouble()).abs() < 0.05
        ? g.round().toString()
        : g.toStringAsFixed(1);
    return '- ${text}G';
  }
  if (bytes >= mb) {
    final m = (bytes / mb).round();
    return '- ${m}M';
  }
  return '- ${(bytes / 1024.0).round()}K';
}

String formatTrafficTotal(double bytes) {
  const gb = 1024.0 * 1024.0 * 1024.0;
  const mb = 1024.0 * 1024.0;
  if (bytes >= gb) {
    final g = bytes / gb;
    return '${g.toStringAsFixed(1)}G';
  }
  if (bytes >= mb) {
    return '${(bytes / mb).toStringAsFixed(0)}M';
  }
  return '${(bytes / 1024.0).toStringAsFixed(0)}K';
}

/// Top instrument panel for [NetworkAccountPage]: renders a 3D glass liquid
/// vial of campus traffic consumption alongside multi-segment quota bars.
class NetworkAccountInstrumentPanel extends StatelessWidget {
  const NetworkAccountInstrumentPanel({
    super.key,
    required this.supported,
    required this.busy,
    required this.data,
    required this.failure,
    required this.selectedProduct,
    required this.onSelectProduct,
  });

  final bool supported;
  final bool busy;
  final NetworkAccountReport? data;
  final FailureCode? failure;
  final int selectedProduct;
  final ValueChanged<int> onSelectProduct;

  @override
  Widget build(BuildContext context) {
    final report = data;
    final hasPartialIssue =
        report != null &&
        (report.portalFailure != null ||
            report.trafficFailure != null ||
            report.netFeeFailure != null);

    final (statusLabel, statusTone) = !supported
        ? ('暂不支持', StatusTone.uncertain)
        : busy
        ? ('查询中', StatusTone.pending)
        : failure != null
        ? ('读取失败', StatusTone.danger)
        : hasPartialIssue
        ? ('部分可用', StatusTone.pending)
        : report != null
        ? ('实体试管', StatusTone.success)
        : ('尚未查询', StatusTone.uncertain);

    final products = report?.trafficProducts ?? const [];
    final safeIdx = products.isEmpty
        ? 0
        : selectedProduct.clamp(0, products.length - 1);
    final active = products.isEmpty ? null : products[safeIdx];

    final usedBytes = active == null
        ? null
        : parseTrafficBytesForChart(active.usedText);
    final freeBytes = active == null
        ? null
        : parseTrafficBytesForChart(active.freeRemainingText);
    final paidBytes = active == null
        ? null
        : parseTrafficBytesForChart(active.paidRemainingText);

    final totalBytes =
        (usedBytes != null && freeBytes != null && paidBytes != null)
        ? usedBytes + freeBytes + paidBytes
        : null;
    final hasValidPool = totalBytes != null && totalBytes > 0;
    final usedRatio = hasValidPool
        ? (usedBytes! / totalBytes).clamp(0.0, 1.0)
        : null;
    final freeRatio = hasValidPool
        ? (freeBytes! / totalBytes).clamp(0.0, 1.0)
        : null;
    final paidRatio = hasValidPool
        ? (paidBytes! / totalBytes).clamp(0.0, 1.0)
        : null;

    final usedPct = usedRatio == null ? null : (usedRatio * 100).round();
    final remPct = usedPct == null ? null : (100 - usedPct).clamp(0, 100);
    final tightQuota = usedRatio != null && usedRatio >= 0.82;

    final scaleTicks = hasValidPool
        ? [
            formatTrafficScaleTick(totalBytes * 0.75),
            formatTrafficScaleTick(totalBytes * 0.50),
            formatTrafficScaleTick(totalBytes * 0.25),
          ]
        : const ['- 75%', '- 50%', '- 25%'];

    final vial = LiquidVialWell(
      code: 'NET',
      readout: usedPct != null ? '$usedPct%' : '--',
      fillRatio: usedRatio,
      palette: tightQuota ? LiquidPalette.amber : LiquidPalette.cobalt,
      scaleTicks: scaleTicks,
      footer: active != null ? '已用 ${active.usedText}' : '按需只读',
      semanticLabel: '校园网流量已用比例',
    );

    if (report == null) {
      return TelemetryInstrumentCard(
        vial: vial,
        title: '校园网流量与门户遥测',
        statusLabel: statusLabel,
        statusTone: statusTone,
        headline: busy
            ? '正在读取门户与网关流量…'
            : failure != null
            ? '本次读取未成功'
            : '待读取实时流量池',
        subheadline: '数据仅留存当前页面内存 · 离页自动清除',
        meters: const [
          TelemetryMeterData(label: '数据策略', trailing: '仅内存 · 不落盘'),
          TelemetryMeterData(label: '写操作边界', trailing: '纯只读 · 无充值'),
        ],
      );
    }

    final headline = usedPct != null && remPct != null
        ? '$usedPct% 已用 · $remPct% 剩余'
        : active != null
        ? '已用 ${active.usedText}'
        : report.trafficFailure != null
        ? '流量池暂不可用'
        : '暂无在用流量产品';

    final subheadline = hasValidPool && active != null
        ? '${active.usedText} / ${formatTrafficTotal(totalBytes)} 总配额池'
        : active != null
        ? '免费剩余 ${active.freeRemainingText} · 计费剩余 ${active.paidRemainingText}'
        : '门户个人统计已同步';

    final cloudVal = double.tryParse(report.cloudDriveFree?.value ?? '');
    final cloudIsGb =
        (report.cloudDriveFree?.unit ?? '').toUpperCase().startsWith('G');
    final cloudRatio = (cloudVal != null && cloudIsGb && cloudVal >= 0)
        ? (cloudVal / 100.0).clamp(0.0, 1.0)
        : null;

    return TelemetryInstrumentCard(
      vial: vial,
      title: '校园网流量池',
      statusLabel: statusLabel,
      statusTone: statusTone,
      headline: headline,
      subheadline: subheadline,
      segments: hasValidPool
          ? [
              BarSegment(
                fraction: usedRatio!,
                startColor: const Color(0xFF1D4ED8),
                endColor: const Color(0xFF0EA5E9),
              ),
              if (paidRatio != null && paidRatio > 0)
                BarSegment(
                  fraction: paidRatio,
                  startColor: const Color(0xFF6366F1),
                  endColor: const Color(0xFFA855F7),
                ),
            ]
          : const [],
      barLeadingCaption: active == null
          ? null
          : '已用 ${active.usedText} · 免费余 ${active.freeRemainingText}',
      barTrailingCaption: hasValidPool
          ? '${active!.usedText} / ${formatTrafficTotal(totalBytes)}'
          : null,
      sectionTitle: active != null ? '配额水位' : null,
      sectionBadge: usedRatio == null
          ? null
          : tightQuota
          ? '偏紧'
          : '充裕',
      sectionBadgeTone: tightQuota ? StatusTone.pending : StatusTone.success,
      switcher: products.length > 1
          ? TelemetryModeSwitcher(
              labels: [
                for (var i = 0; i < products.length; i++)
                  products[i].productName ?? '产品${i + 1}',
              ],
              selectedIndex: safeIdx,
              onSelected: onSelectProduct,
            )
          : null,
      meters: [
        if (active != null && freeRatio != null)
          TelemetryMeterData(
            label: '免费剩余',
            ratio: freeRatio,
            trailing: '${(freeRatio * 100).round()}% · ${active.freeRemainingText}',
            startColor: const Color(0xFF0B68F5),
            endColor: const Color(0xFF38BDF8),
          ),
        if (active != null && paidRatio != null)
          TelemetryMeterData(
            label: '计费剩余',
            ratio: paidRatio,
            trailing: active.paidRemainingText,
            startColor: const Color(0xFF4F46E5),
            endColor: const Color(0xFF818CF8),
          ),
        if (report.cloudDriveFree != null)
          TelemetryMeterData(
            label: '云盘空间',
            ratio: cloudRatio,
            trailing: report.cloudDriveFree!.displayText,
            startColor: const Color(0xFF0D9488),
            endColor: const Color(0xFF2DD4BF),
          ),
      ],
    );
  }
}
