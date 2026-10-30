import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/library/library_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';
import 'package:ginkgo_mirror/application/library_stats.dart';

import 'library_stats_fixture.dart';

class StatsService implements MirrorService {
  final requests = <Completer<LibraryStatsRead>>[];
  final forces = <bool>[];
  @override
  bool get isDemo => false;
  @override
  Future<LibraryStatsRead> libraryStats({bool forceRefresh = false}) {
    forces.add(forceRefresh);
    final request = Completer<LibraryStatsRead>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<LibraryVenuesResponse> libraryVenues({
    bool forceRefresh = false,
  }) async => const LibraryVenuesResponse(
    venues: [],
    fromCache: false,
    stale: false,
    failure: FailureCode.sessionExpired,
  );
  @override
  Future<LibraryBookingsResponse> libraryBookings({
    bool forceRefresh = false,
  }) async => const LibraryBookingsResponse(
    bookings: [],
    fromCache: false,
    stale: false,
    failure: FailureCode.sessionExpired,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'public stats remain reachable after booking failure and preserve snapshot',
    (tester) async {
      final service = StatsService();
      final fixture = jsonDecode(
        File('../fixtures/library/stats-normal-v1.json').readAsStringSync(),
      ) as Map;
      await tester.pumpWidget(ginkgoApp(home: LibraryPage(service: service)));
      await tester.pumpAndSettle();
      expect(find.textContaining('学校会话已失效'), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('library-public-stats')));
      await tester.pump();
      service.requests.single.complete(
        statsRead({
          'campuses': fixture['expected'],
          'fetchedAt': '2026-10-20T02:03:00Z',
          'fromCache': false,
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('120 人', findRichText: true), findsOneWidget);
      expect(find.textContaining('10:03（北京时间）'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('刷新公共统计').first);
      await tester.pump();
      service.requests.last.complete(
        const LibraryStatsRead(failure: FailureCode.serviceUnavailable),
      );
      await tester.pumpAndSettle();
      expect(service.forces, [false, true]);
      expect(find.textContaining('保留上次人数与实际更新时间'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('沙河校区'),
        240,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('library-stats-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('官网未提供数量'), findsWidgets);
      expect(find.text('个可用 · 共 6 个'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('desktop-page-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library-public-stats')), findsOneWidget);
    },
  );
}
