import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';

double contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'state labels meet AA on $brightness grouped and tinted surfaces',
      (tester) async {
        await tester.pumpWidget(
          CupertinoApp(
            theme: CupertinoThemeData(brightness: brightness),
            home: Builder(
              builder: (context) {
                final surfaces = [
                  CupertinoColors.systemBackground.resolveFrom(context),
                  CupertinoColors.systemGroupedBackground.resolveFrom(context),
                  CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
                    context,
                  ),
                ];
                for (final token in [
                  AppleDesign.statusSuccess,
                  AppleDesign.statusPending,
                  AppleDesign.statusUncertain,
                  AppleDesign.statusDanger,
                  AppleDesign.statusInactive,
                ]) {
                  final color = token.resolveFrom(context);
                  for (final surface in surfaces) {
                    expect(contrast(color, surface), greaterThanOrEqualTo(4.5));
                    for (final alpha in [0.08, 0.12, 0.2]) {
                      final badge = Color.alphaBlend(
                        color.withValues(alpha: alpha),
                        surface,
                      );
                      expect(contrast(color, badge), greaterThanOrEqualTo(4.5));
                    }
                  }
                }
                return const SizedBox();
              },
            ),
          ),
        );
      },
    );
  }
}
