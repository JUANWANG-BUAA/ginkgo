import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/auth/login_credential_field.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('credential hints remain readable in $brightness', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      late BuildContext context;
      await tester.pumpWidget(
        CupertinoApp(
          theme: CupertinoThemeData(brightness: brightness),
          home: Builder(
            builder: (value) {
              context = value;
              return CupertinoPageScaffold(
                child: loginCredentialField(
                  context: value,
                  busy: false,
                  challengeBusy: false,
                  showPassword: false,
                  togglePassword: () {},
                  key: const Key('credential'),
                  controller: controller,
                  placeholder: '学号',
                  label: '学号',
                ),
              );
            },
          ),
        ),
      );
      final field = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      final background = CupertinoColors.secondarySystemGroupedBackground
          .resolveFrom(context);
      final color = CupertinoDynamicColor.resolve(
        (field.placeholderStyle?.color ?? CupertinoColors.placeholderText),
        context,
      );
      final foreground = Color.alphaBlend(color, background);
      final a = foreground.computeLuminance(),
          b = background.computeLuminance();
      expect(
        (math.max(a, b) + .05) / (math.min(a, b) + .05),
        greaterThanOrEqualTo(4.5),
      );
    });
  }
}
