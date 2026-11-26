import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/features/today/today_page.dart';
import 'package:ginkgo_mirror/infrastructure/offline_cache_store.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/platform/update_gate.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';

import 'mirror_widget_test.dart' show ControlledService;
import 'session_widget_test.dart' show FakeService, signedOut;

class _OfflineRestoreService extends FakeService {
  _OfflineRestoreService({
    required this.restoreCompleter,
  }) : super(restoreResponse: signedOut, loginResponse: signedOut);

  final Completer<SessionResponse> restoreCompleter;

  @override
  Future<SessionResponse> restoreSession() => restoreCompleter.future;
}

class _MidnightTodayService extends ControlledService {
  int todayCalls = 0;
  String servedDate = '2026-10-19';

  @override
  Future<TodayResponse> today({bool forceRefresh = false}) async {
    todayCalls++;
    return TodayResponse(
      date: servedDate,
      courses: const [
        TodayCourse(name: '数值分析', place: '主M201', time: '08:00–09:35'),
      ],
      fetchedAt: '${servedDate}T07:50:00+08:00',
    );
  }
}

void main() {
  test('OfflineCacheStore persists and isolates snapshots per account', () async {
    final dir = await Directory.systemTemp.createTemp('ginkgo_offline_cache_');
    addTearDown(() => dir.delete(recursive: true));
    final store = OfflineCacheStore(supportDirectory: () async => dir);

    await store.saveSessionHint(
      const OfflineSessionHint(
        account: 'sy2501001',
        name: '李文',
        route: RouteChoice.direct,
      ),
    );
    final hint = await store.readSessionHint();
    expect(hint?.account, 'sy2501001');
    expect(hint?.name, '李文');
    expect(hint?.route, RouteChoice.direct);

    const schedule = ScheduleResponse(
      terms: [ScheduleTerm(id: '20261', name: '2026秋', selected: true)],
      weeks: [
        ScheduleWeek(
          number: 5,
          startDate: '2026-10-12',
          endDate: '2026-10-18',
          current: true,
        ),
      ],
      termId: '20261',
      weekNumber: 5,
      courses: [
        ScheduleCourse(
          id: 'c1',
          name: '高等工程数学',
          day: 1,
          startSection: 1,
          endSection: 2,
          place: '主M301',
        ),
      ],
      exams: [],
      fetchedAt: '2026-10-12T07:30:00+08:00',
    );
    await store.saveSchedule('sy2501001', schedule);
    final hit = await store.readSchedule(
      'sy2501001',
      attachFailure: FailureCode.networkUnreachable,
    );
    expect(hit?.courses.single.name, '高等工程数学');
    expect(hit?.courses.single.place, '主M301');
    expect(hit?.failure, FailureCode.networkUnreachable);
    expect(await store.readSchedule('sy2501002'), isNull);

    await store.clearSessionHint();
    expect(await store.readSessionHint(), isNull);
  });

  testWidgets(
    'GinkgoRoot enters cached workspace without blocking on UpdateGate or offline restore',
    (tester) async {
      final prefs = AppPreferences();
      addTearDown(prefs.dispose);
      final gateCompleter = Completer<UpdateGate?>();
      final restoreCompleter = Completer<SessionResponse>();
      final service = _OfflineRestoreService(restoreCompleter: restoreCompleter);

      await tester.pumpWidget(
        GinkgoRoot(
          liveService: service,
          preferences: prefs,
          initialSessionHint: const OfflineSessionHint(
            account: 'sy2501001',
            name: '李文',
          ),
          loadUpdateGate: () => gateCompleter.future,
        ),
      );
      await tester.pump();
      // Workspace renders immediately without waiting for UpdateGate or restoreSession.
      expect(find.text('今天'), findsWidgets);

      restoreCompleter.complete(
        const SessionResponse(
          state: SessionState.signedOut,
          remembered: true,
          failure: FailureCode.networkUnreachable,
        ),
      );
      gateCompleter.complete(null);
      await tester.pumpAndSettle();

      // Still inside workspace (not kicked to SessionRecoveryPage) with retry affordance.
      expect(find.text('暂未恢复登录状态'), findsNothing);
      expect(find.text('重试连接'), findsOneWidget);
    },
  );

  testWidgets('TodayPage refreshes automatically when resumed across midnight', (
    tester,
  ) async {
    var clock = DateTime.utc(2026, 10, 19, 15, 0); // 23:00 Beijing on Oct 19
    final service = _MidnightTodayService();
    await tester.pumpWidget(
      ginkgoApp(
        home: TodayPage(
          service: service,
          fileActions: const PlatformActions(),
          now: () => clock,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.todayCalls, 1);

    // Next morning 07:55 Beijing (23:55 UTC Oct 19 -> 07:55+08 Oct 20).
    clock = DateTime.utc(2026, 10, 19, 23, 55);
    service.servedDate = '2026-10-20';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(service.todayCalls, 2);
  });
}
