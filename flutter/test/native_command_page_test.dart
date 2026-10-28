import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/career.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/features/career/career_events_page.dart';
import 'package:ginkgo_mirror/infrastructure/native_command.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

/// A read that never answers, and a read that fails the way the native
/// budget fails: the command surfaces an error instead of hanging.
class HangingService extends Fake
    implements MirrorService, CareerEventsGateway {
  HangingService({this.neverAnswers = true});

  final bool neverAnswers;
  int reads = 0;

  @override
  bool get isDemo => true;

  @override
  Future<CareerEventsRead> careerEvents({
    required String month,
    bool forceRefresh = false,
  }) {
    reads++;
    if (neverAnswers) {
      return boundedNative(
        () => Completer<CareerEventsRead>().future,
        const Duration(milliseconds: 50),
      );
    }
    return boundedNative(
      () async => throw TimeoutException('native command budget expired'),
      const Duration(milliseconds: 50),
    );
  }
}

Widget host(CareerEventsGateway service) =>
    CupertinoApp(home: CareerEventsPage(service: service));

void main() {
  testWidgets(
    'a read that fails the native budget leaves the page in a failure state',
    (tester) async {
      final fake = HangingService(neverAnswers: false);
      await tester.pumpWidget(host(fake));
      await tester.pumpAndSettle();
      expect(fake.reads, greaterThan(0));
      // The page must leave the loading state and explain the failure
      // instead of spinning forever. A thrown native error is reported as
      // "local service unavailable", the same text a missing service uses.
      expect(find.byType(GinkgoActivity), findsNothing);
      expect(find.textContaining('本地服务暂时不可用'), findsWidgets);
      expect(find.text('重试'), findsWidgets);
    },
  );

  testWidgets(
    'a read that never answers does not leave the page loading forever',
    (tester) async {
      final fake = HangingService();
      await tester.pumpWidget(host(fake));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      // The read is still in flight: the page shows the loading state, and the
      // native budget is what eventually turns it into a failure.
      expect(fake.reads, 1);
      expect(find.byType(GinkgoActivity), findsWidgets);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(GinkgoActivity), findsNothing);
      expect(find.textContaining('本地服务暂时不可用'), findsWidgets);
      expect(find.text('重试'), findsWidgets);
    },
  );
}
