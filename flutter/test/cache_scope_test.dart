import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/query_cache_scope.dart';
import 'package:ginkgo_mirror/settings_page.dart';

import 'mirror_widget_test.dart' show ControlledService;

class ClearService extends ControlledService {
  int calls = 0;
  bool succeeds = false;
  @override
  Future<bool> clearCache() async {
    calls++;
    return succeeds;
  }
}

void main() {
  testWidgets(
    'successful clear discards retained page state; failure preserves it',
    (tester) async {
      final service = ClearService();
      await tester.pumpWidget(
        ginkgoApp(
          home: QueryCacheScope(
            child: SettingsPage(service: service, onSignOut: () async {}),
          ),
        ),
      );
      final before = tester.state(find.byType(SettingsPage));
      Future<void> clear() async {
        await tester.scrollUntilVisible(
          find.text('清除查询快照'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('清除查询快照'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('继续'));
        await tester.pumpAndSettle();
      }

      await clear();
      expect(
        identical(tester.state(find.byType(SettingsPage)), before),
        isTrue,
      );
      service.succeeds = true;
      await clear();
      expect(service.calls, 2);
      expect(before.mounted, isFalse);
      expect(
        identical(tester.state(find.byType(SettingsPage)), before),
        isFalse,
      );
    },
  );
}
