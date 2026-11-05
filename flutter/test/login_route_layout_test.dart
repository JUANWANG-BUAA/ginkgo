import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/features/auth/login_route_selector.dart';

void main() {
  testWidgets(
    'narrow large type exposes complete route labels and original selection',
    (tester) async {
      RouteChoice? selected;
      await tester.pumpWidget(
        CupertinoApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Center(
              child: SizedBox(
                width: 288,
                child: LoginRouteSelector(
                  route: RouteChoice.automatic,
                  onChanged: (value) => selected = value,
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        find.byType(CupertinoSlidingSegmentedControl<String>),
        findsNothing,
      );
      expect(find.text('仅 WebVPN'), findsOneWidget);
      await tester.tap(find.text('仅 WebVPN'));
      expect(selected, RouteChoice.webVpn);
      expect(tester.takeException(), isNull);
    },
  );
}
