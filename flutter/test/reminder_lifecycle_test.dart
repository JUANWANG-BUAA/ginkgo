import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/shared/reminders.dart';

const _checkin = CheckInResponse(
  date: '2026-10-22',
  courses: [],
  fromCache: false,
  stale: false,
);

class _Service extends Fake implements MirrorService {
  int checkinReads = 0, homeworkReads = 0;
  Completer<CheckInResponse>? pendingCheckin;
  @override
  bool get isDemo => false;
  @override
  Future<CheckInResponse> checkin({bool forceRefresh = false}) {
    checkinReads++;
    return pendingCheckin?.future ?? Future.value(_checkin);
  }

  @override
  Future<HomeworkResponse> homework({bool forceRefresh = false}) async {
    homeworkReads++;
    return const HomeworkResponse(
      termName: '合成学期',
      termCode: 'synthetic',
      items: [],
    );
  }
}

class _Platform implements ReminderPlatform {
  int replacements = 0;
  @override
  Future<void> replace(List<Map<String, Object>> plans) async {
    replacements++;
  }
}

class _Controller extends ReminderController {
  _Controller(_Service service)
    : super(
        service: service,
        account: 'synthetic',
        visibility: null,
        persist: false,
        platform: _Platform(),
      );
  final restored = Completer<void>();
  Completer<void>? stopping;
  final refreshes = <bool>[];
  int reconciles = 0, reschedules = 0, stops = 0;
  bool disposed = false;

  @override
  Future<void> restore() => restored.future;
  @override
  Future<void> refresh({bool includeHomework = true}) {
    expectSync(
      disposed,
      isFalse,
      reason: 'scope must not refresh a disposed controller',
    );
    refreshes.add(includeHomework);
    return super.refresh(includeHomework: includeHomework);
  }

  @override
  Future<void> reconcile() {
    expectSync(
      disposed,
      isFalse,
      reason: 'scope must not reconcile after dispose',
    );
    reconciles++;
    return super.reconcile();
  }

  @override
  Future<void> reschedule() {
    reschedules++;
    return super.reschedule();
  }

  @override
  Future<void> stop() async {
    stops++;
    if (stopping != null) await stopping!.future;
    await super.stop();
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Service service,
  _Controller c,
) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(
    ReminderScope(
      service: service,
      account: 'synthetic',
      controllerFactory: (_, _, _) => c,
      child: const SizedBox(),
    ),
  );
}

Future<void> _unmount(WidgetTester tester) async {
  // Re-enable frames without resuming reminder work before removing the scope.
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pumpWidget(const SizedBox());
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void main() {
  for (final state in [
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.detached,
  ]) {
    testWidgets(
      'late restore while ${state.name} cannot read or start timers',
      (tester) async {
        final service = _Service();
        final c = _Controller(service);
        await _mount(tester, service, c);
        tester.binding.handleAppLifecycleStateChanged(state);
        c.restored.complete();
        await tester.pump();
        await tester.pump(const Duration(minutes: 4));
        final reads = service.checkinReads;
        final reconciles = c.reconciles;
        await _unmount(tester);
        expect(reads, 0);
        expect(reconciles, 0);
        expect(service.homeworkReads, 0);
      },
    );
  }

  testWidgets('mount in background defers reads until resumed', (tester) async {
    final service = _Service();
    final c = _Controller(service);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpWidget(
      ReminderScope(
        service: service,
        account: 'synthetic',
        controllerFactory: (_, _, _) => c,
        child: const SizedBox(),
      ),
    );
    c.restored.complete();
    await tester.pump(const Duration(minutes: 4));
    expect(service.checkinReads, 0);
    expect(c.reconciles, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.checkinReads, 1);
    expect(service.homeworkReads, 1);
    await _unmount(tester);
  });

  testWidgets(
    'pause and repeated resume during initial read share one activation',
    (tester) async {
      final service = _Service()..pendingCheckin = Completer<CheckInResponse>();
      final c = _Controller(service);
      await _mount(tester, service, c);
      c.restored.complete();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final observer =
          tester.state(find.byType(ReminderScope)) as WidgetsBindingObserver;
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(c.refreshes, [false]);
      service.pendingCheckin!.complete(_checkin);
      await tester.pump();
      final reconciles = c.reconciles;
      await tester.pump(const Duration(seconds: 15));
      expect(c.reconciles, reconciles + 1);
      await tester.pump(const Duration(seconds: 105));
      expect(service.checkinReads, 2);
      expect(service.homeworkReads, 1);
      await _unmount(tester);
    },
  );

  testWidgets('late initial refresh cannot restart timers after pause', (
    tester,
  ) async {
    final service = _Service()..pendingCheckin = Completer<CheckInResponse>();
    final c = _Controller(service);
    await _mount(tester, service, c);
    c.restored.complete();
    await tester.pump();
    expect(service.checkinReads, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    service.pendingCheckin!.complete(_checkin);
    await tester.pump();
    final reconciles = c.reconciles;
    await tester.pump(const Duration(minutes: 4));
    final refreshes = c.refreshes.length;
    final laterReconciles = c.reconciles;
    await _unmount(tester);
    expect(refreshes, 1);
    expect(laterReconciles, reconciles);
    expect(service.homeworkReads, 0);
  });

  testWidgets(
    'resume during restore waits and duplicate resume keeps one timer group',
    (tester) async {
      final service = _Service();
      final c = _Controller(service);
      await _mount(tester, service, c);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      // Direct observer delivery covers repeated resume even when binding deduplicates it.
      final observer =
          tester.state(find.byType(ReminderScope)) as WidgetsBindingObserver;
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      final readsBeforeRestore = service.checkinReads;
      c.restored.complete();
      await tester.pump();
      final readsAfterRestore = service.checkinReads;
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      final readsAfterDuplicates = service.checkinReads;
      final reconciles = c.reconciles;
      await tester.pump(const Duration(seconds: 15));
      expect(c.reconciles, reconciles + 1);
      await tester.pump(const Duration(seconds: 105));
      final readsAfterPoll = service.checkinReads;
      await _unmount(tester);
      expect(readsBeforeRestore, 0);
      expect(readsAfterRestore, 1);
      expect(readsAfterDuplicates, 1);
      expect(readsAfterPoll, 2);
      expect(service.homeworkReads, 1);
    },
  );

  testWidgets(
    'resume after ready refreshes once and stops all nonforeground timers',
    (tester) async {
      final service = _Service();
      final c = _Controller(service);
      await _mount(tester, service, c);
      c.restored.complete();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final before = c.reconciles;
      await tester.pump(const Duration(minutes: 4));
      expect(c.reconciles, before);
      expect(service.checkinReads, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(service.checkinReads, 2);
      expect(service.homeworkReads, 1);
      expect(c.reschedules, 1);
      await _unmount(tester);
    },
  );

  testWidgets(
    'dispose during restore cannot refresh even while stop is pending',
    (tester) async {
      final service = _Service();
      final c = _Controller(service)..stopping = Completer<void>();
      await _mount(tester, service, c);
      await _unmount(tester);
      c.restored.complete();
      await tester.pump(const Duration(minutes: 4));
      expect(c.disposed, isTrue);
      expect(c.stops, 1);
      expect(c.refreshes, isEmpty);
      expect(c.reconciles, 0);
      c.stopping!.complete();
      await tester.pump();
    },
  );

  testWidgets(
    'dispose during refresh ignores late completion and removed observer',
    (tester) async {
      final service = _Service()..pendingCheckin = Completer<CheckInResponse>();
      final c = _Controller(service)..stopping = Completer<void>();
      await _mount(tester, service, c);
      c.restored.complete();
      await tester.pump();
      final observer =
          tester.state(find.byType(ReminderScope)) as WidgetsBindingObserver;
      await _unmount(tester);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      service.pendingCheckin!.complete(_checkin);
      await tester.pump(const Duration(minutes: 4));
      expect(c.refreshes, [false]);
      expect(c.reconciles, 0);
      c.stopping!.complete();
      await tester.pump();
    },
  );

  test('resume before controller creation is safe', () {
    final scope = ReminderScope(
      service: _Service(),
      account: 'synthetic',
      child: const SizedBox(),
    );
    final observer = scope.createState() as WidgetsBindingObserver;
    expect(
      () => observer.didChangeAppLifecycleState(AppLifecycleState.resumed),
      returnsNormally,
    );
  });
}
