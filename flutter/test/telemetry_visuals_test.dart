import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/network_account/network_account_visuals.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/widgets/liquid_vial_gauge.dart';
import 'package:ginkgo_mirror/widgets/status_chip.dart';
import 'package:ginkgo_mirror/widgets/telemetry_instrument_card.dart';

void main() {
  test('traffic byte parser handles 1024 units, unitless zero, and rejects noise', () {
    expect(parseTrafficBytesForChart('0'), 0.0);
    expect(parseTrafficBytesForChart('0G'), 0.0);
    expect(parseTrafficBytesForChart('1K'), 1024.0);
    expect(parseTrafficBytesForChart('2M'), 2 * 1024.0 * 1024.0);
    expect(
      parseTrafficBytesForChart('12.5G'),
      12.5 * 1024.0 * 1024.0 * 1024.0,
    );
    expect(parseTrafficBytesForChart('123'), isNull);
    expect(parseTrafficBytesForChart('0天'), isNull);
    expect(parseTrafficBytesForChart('-5G'), isNull);
  });

  testWidgets(
    'TelemetryInstrumentCard and LiquidVialWell adapt cleanly across dark mode, 320dp, and 1.8x text',
    (tester) async {
      var activeTab = 0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 760),
            textScaler: TextScaler.linear(1.8),
            disableAnimations: true,
          ),
          child: ginkgoApp(
            brightness: Brightness.dark,
            home: StatefulBuilder(
              builder: (context, setState) => CupertinoPageScaffold(
                child: SingleChildScrollView(
                  child: TelemetryInstrumentCard(
                    vial: const LiquidVialWell(
                      code: 'CTX',
                      readout: '68%',
                      fillRatio: 0.68,
                      palette: LiquidPalette.cobalt,
                      scaleTicks: ['- 384k', '- 256k', '- 128k'],
                      footer: '57.0 tok/s',
                      semanticLabel: '上下文已用比例',
                    ),
                    title: '上下文窗口',
                    statusLabel: '实体试管',
                    statusTone: StatusTone.success,
                    headline: '68% 已用 · 32% 剩余',
                    subheadline: '347K / 512K',
                    segments: const [
                      BarSegment(
                        fraction: 0.48,
                        startColor: Color(0xFF1D4ED8),
                        endColor: Color(0xFF2563EB),
                      ),
                      BarSegment(
                        fraction: 0.20,
                        startColor: Color(0xFF0284C7),
                        endColor: Color(0xFF38BDF8),
                      ),
                    ],
                    barLeadingCaption: '已用配额',
                    barTrailingCaption: '347k / 512k',
                    sectionTitle: '线路配额',
                    sectionBadge: '充裕',
                    switcher: TelemetryModeSwitcher(
                      labels: const ['主线路', '备用线'],
                      selectedIndex: activeTab,
                      onSelected: (idx) => setState(() => activeTab = idx),
                    ),
                    meters: const [
                      TelemetryMeterData(
                        label: '短周期',
                        ratio: 0.72,
                        trailing: '72%',
                      ),
                      TelemetryMeterData(
                        label: '周额度',
                        ratio: 0.92,
                        trailing: '92%',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('68% 已用 · 32% 剩余'), findsOneWidget);
      expect(find.text('实体试管'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('备用线'));
      await tester.pump();
      expect(activeTab, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
