import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/query_snapshots.dart';
import 'package:ginkgo_mirror/features/classroom/classroom_page.dart';
import 'package:ginkgo_mirror/features/classroom/classroom_sections.dart';
import 'package:ginkgo_mirror/features/learning/learning_snapshots_page.dart';
import 'package:ginkgo_mirror/features/settings/preferences_pages.dart';
import 'package:ginkgo_mirror/platform/system_settings_service.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';

class ClassroomReads extends Fake implements AcademicGateway {
  final datesRead = Completer<QueryDates>();
  final roomsRead = Completer<ClassroomResponse>();
  int dateCalls = 0;
  @override
  bool get isDemo => true;
  @override
  Future<QueryDates> dates(String instant) {
    dateCalls++;
    return datesRead.future;
  }

  @override
  Future<ClassroomResponse> classrooms(DemoScope scope, ClassroomQuery query) =>
      roomsRead.future;
}

class SnapshotSettings extends Fake implements LearningSnapshotGateway {
  var statusRead = Completer<LearningSnapshotStatus>();
  final saving = Completer<LearningSnapshotStatus>();
  final changes = <bool>[];
  bool failStatus = false;
  @override
  Future<LearningSnapshotStatus> learningSnapshotStatus() async {
    // Create failures in the caller's zone. Device widget callbacks and the
    // test body may use different error zones, across which errors cannot pass.
    if (failStatus) throw StateError('synthetic read failure');
    return statusRead.future;
  }

  @override
  Future<LearningSnapshotStatus> setLearningSnapshotsEnabled(bool enabled) {
    changes.add(enabled);
    return saving.future;
  }
}

class NotificationSettings extends Fake implements SystemSettingsService {
  final reads = <Completer<String>>[];
  final request = Completer<String>();
  @override
  bool get isAndroid => true;
  @override
  Future<String> notificationPermission() {
    final read = Completer<String>();
    reads.add(read);
    return read.future;
  }

  @override
  Future<String> requestNotifications() => request.future;
}

Future<void> snapshotPage(
  WidgetTester tester,
  SnapshotSettings gateway, {
  bool enabled = false,
}) async {
  await tester.pumpWidget(
    CupertinoApp(home: LearningSnapshotsPage(gateway: gateway)),
  );
  gateway.statusRead.complete(
    LearningSnapshotStatus(supported: true, enabled: enabled),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('classroom service replacement discards old school dates', (
    tester,
  ) async {
    final first = ClassroomReads();
    final second = ClassroomReads();
    await tester.pumpWidget(CupertinoApp(home: ClassroomPage(service: first)));
    await tester.pumpWidget(CupertinoApp(home: ClassroomPage(service: second)));
    first.datesRead.complete(
      const QueryDates(today: '2026-10-20', tomorrow: '2026-10-21'),
    );
    second.datesRead.complete(
      const QueryDates(today: '2026-11-03', tomorrow: '2026-11-04'),
    );
    await tester.pumpAndSettle();
    expect(second.dateCalls, 1);
    expect(
      tester
          .widget<ClassroomScopeSection>(find.byType(ClassroomScopeSection))
          .date,
      '2026-11-03',
    );
  });

  testWidgets('classroom old query cannot publish after service replacement', (
    tester,
  ) async {
    final first = ClassroomReads();
    final second = ClassroomReads();
    await tester.pumpWidget(CupertinoApp(home: ClassroomPage(service: first)));
    first.datesRead.complete(
      const QueryDates(today: '2026-11-03', tomorrow: '2026-11-04'),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ClassroomScopeSection>(find.byType(ClassroomScopeSection))
        .onQuery();
    await tester.pump();
    await tester.pumpWidget(CupertinoApp(home: ClassroomPage(service: second)));
    first.roomsRead.complete(
      const ClassroomResponse(
        buildings: [],
        roomCount: 0,
        buildingCount: 0,
        freeSlotCount: 0,
        fromCache: false,
      ),
    );
    second.datesRead.complete(
      const QueryDates(today: '2026-11-03', tomorrow: '2026-11-04'),
    );
    await tester.pumpAndSettle();
    expect(find.text('选择范围后查询'), findsOneWidget);
    expect(find.text('没有符合条件的空教室'), findsNothing);
  });

  testWidgets('snapshot status failure is recoverable without a mutation', (
    tester,
  ) async {
    final gateway = SnapshotSettings()..failStatus = true;
    await tester.pumpWidget(
      CupertinoApp(home: LearningSnapshotsPage(gateway: gateway)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('重新读取存储状态'), findsOneWidget);
    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).onChanged,
      isNull,
    );
    expect(gateway.changes, isEmpty);
  });

  testWidgets('snapshot consent cannot enable a replacement gateway', (
    tester,
  ) async {
    final first = SnapshotSettings();
    final second = SnapshotSettings();
    await snapshotPage(tester, first);
    tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).onChanged!(
      true,
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      CupertinoApp(home: LearningSnapshotsPage(gateway: second)),
    );
    second.statusRead.complete(const LearningSnapshotStatus(supported: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存加密快照'));
    await tester.pumpAndSettle();
    expect(first.changes, isEmpty);
    expect(second.changes, isEmpty);
  });

  testWidgets('snapshot old save cannot overwrite replacement status', (
    tester,
  ) async {
    final first = SnapshotSettings();
    final second = SnapshotSettings();
    await snapshotPage(tester, first, enabled: true);
    tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).onChanged!(
      false,
    );
    await tester.pump();
    await tester.pumpWidget(
      CupertinoApp(home: LearningSnapshotsPage(gateway: second)),
    );
    second.statusRead.complete(const LearningSnapshotStatus(supported: true));
    await tester.pumpAndSettle();
    first.saving.complete(
      const LearningSnapshotStatus(
        supported: true,
        enabled: true,
        message: '旧保存结果',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('旧保存结果'), findsNothing);
    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
      isFalse,
    );
  });

  testWidgets(
    'snapshot save exception retains status and offers a read retry',
    (tester) async {
      final gateway = SnapshotSettings();
      await snapshotPage(tester, gateway, enabled: true);
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).onChanged!(
        false,
      );
      await tester.pump();
      gateway.saving.completeError(StateError('synthetic write failure'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('重新读取存储状态'), findsOneWidget);
      expect(
        tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).onChanged,
        isNull,
      );
      expect(gateway.changes, [false]);
      gateway.statusRead = Completer<LearningSnapshotStatus>();
      await tester.ensureVisible(find.text('重新读取存储状态'));
      await tester.tap(find.text('重新读取存储状态'));
      gateway.statusRead.complete(
        const LearningSnapshotStatus(supported: true, enabled: false),
      );
      await tester.pumpAndSettle();
      expect(find.text('重新读取存储状态'), findsNothing);
      expect(
        tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
        isFalse,
      );
      expect(
        tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).onChanged,
        isNotNull,
      );
      expect(gateway.changes, [false]);
    },
  );

  testWidgets('snapshot enable consent opens once and cancellation unlocks', (
    tester,
  ) async {
    final gateway = SnapshotSettings();
    await snapshotPage(tester, gateway);
    final change = tester
        .widget<CupertinoSwitch>(find.byType(CupertinoSwitch))
        .onChanged!;
    change(true);
    change(true);
    await tester.pumpAndSettle();
    expect(
      find.byType(CupertinoAlertDialog, skipOffstage: false),
      findsOneWidget,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(gateway.changes, isEmpty);
    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).onChanged,
      isNotNull,
    );
  });

  testWidgets(
    'notification service replacement ignores an old permission read',
    (tester) async {
      final first = NotificationSettings();
      final second = NotificationSettings();
      await tester.pumpWidget(
        CupertinoApp(home: SystemPreferencesPage(service: first)),
      );
      await tester.pumpWidget(
        CupertinoApp(home: SystemPreferencesPage(service: second)),
      );
      if (second.reads.isNotEmpty) second.reads.single.complete('granted');
      first.reads.single.complete('denied');
      await tester.pumpAndSettle();
      expect(second.reads, hasLength(1));
      expect(find.text('已允许'), findsOneWidget);
      expect(find.text('未允许，请到系统设置开启'), findsNothing);
    },
  );

  testWidgets('old lifecycle permission read cannot undo a completed request', (
    tester,
  ) async {
    final service = NotificationSettings();
    await tester.pumpWidget(
      CupertinoApp(home: SystemPreferencesPage(service: service)),
    );
    service.reads.first.complete('notRequested');
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.tap(find.text('请求通知权限'));
    service.request.complete('granted');
    await tester.pumpAndSettle();
    service.reads.last.complete('denied');
    await tester.pumpAndSettle();
    expect(find.text('已允许'), findsOneWidget);
  });

  test('late preference read cannot replace a newer local choice', () async {
    final reading = Completer<Map<String, Object?>?>();
    final preferences = AppPreferences(reader: () => reading.future);
    addTearDown(preferences.dispose);
    final restoring = preferences.restore();
    await preferences.update(appearance: AppAppearance.dark);
    reading.complete({'appearance': 'light'});
    await restoring;
    expect(preferences.appearance, AppAppearance.dark);
  });

  test(
    'preference reread waits for a queued save before reading storage',
    () async {
      final writing = Completer<void>();
      Map<String, Object?> disk = {'appearance': 'light'};
      final preferences = AppPreferences(
        reader: () async => disk,
        writer: (value) async {
          await writing.future;
          disk = value;
        },
      );
      addTearDown(preferences.dispose);
      final saving = preferences.update(appearance: AppAppearance.dark);
      final restoring = preferences.restore();
      await Future<void>.delayed(Duration.zero);
      writing.complete();
      await Future.wait([saving, restoring]);
      expect(preferences.appearance, AppAppearance.dark);
    },
  );

  test(
    'older failed preference reread cannot mask a newer successful read',
    () async {
      final reads = <Completer<Map<String, Object?>?>>[];
      final preferences = AppPreferences(
        reader: () {
          final read = Completer<Map<String, Object?>?>();
          reads.add(read);
          return read.future;
        },
      );
      addTearDown(preferences.dispose);
      final first = preferences.restore();
      await Future<void>.delayed(Duration.zero);
      final second = preferences.restore();
      await Future<void>.delayed(Duration.zero);
      reads.last.complete({'appearance': 'dark'});
      await second;
      reads.first.completeError(StateError('synthetic obsolete read failure'));
      await first;
      expect(preferences.appearance, AppAppearance.dark);
      expect(preferences.readFailed, isFalse);
      expect(preferences.saveError, isNull);
    },
  );
}
