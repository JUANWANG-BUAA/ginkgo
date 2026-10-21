// Explicitly opt-in. Credentials arrive once over adb reverse from a temporary
// loopback server; never place them in dart-defines, fixtures or test output.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/bykc_page.dart';
import 'package:ginkgo_mirror/cgyy_page.dart';
import 'package:ginkgo_mirror/checkin_page.dart';
import 'package:ginkgo_mirror/classroom_page.dart';
import 'package:ginkgo_mirror/graduate_page.dart';
import 'package:ginkgo_mirror/grades_page.dart';
import 'package:ginkgo_mirror/homework_page.dart';
import 'package:ginkgo_mirror/library_history_page.dart';
import 'package:ginkgo_mirror/library_page.dart';
import 'package:ginkgo_mirror/library_stats_page.dart';
import 'package:ginkgo_mirror/login_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/maintenance_service.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/notices_page.dart';
import 'package:ginkgo_mirror/settings_page.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' as live;
import 'package:ginkgo_mirror/src/rust/api/mirror.dart' as dto;
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';
import 'package:ginkgo_mirror/tasks_page.dart';
import 'package:ginkgo_mirror/today_page.dart';
import 'package:ginkgo_mirror/schedule_page.dart';

import 'support.dart';

const enabled = bool.fromEnvironment('GINKGO_LIVE_ACCEPTANCE');
const endpoint = String.fromEnvironment(
  'GINKGO_LIVE_ENDPOINT',
  defaultValue: 'http://127.0.0.1:18764',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'authorized real-account interface, visual and latency audit',
    (tester) async {
      await RustLib.init();
      const service = NativeMirrorService();
      // The harness channel is deliberately loopback-only and does not change
      // the application's production HTTPS or Android network policy.
      final channel = Uri.parse(endpoint);
      if (channel.host != '127.0.0.1' || channel.scheme != 'http') {
        throw StateError('Acceptance channel must be loopback');
      }
      Future<List<int>> exchange(
        String method,
        String path,
        List<int> body,
      ) async {
        final socket = await Socket.connect(
          channel.host,
          channel.port,
          timeout: const Duration(seconds: 10),
        );
        socket.add(
          ascii.encode(
            '$method $path HTTP/1.0\r\nHost: 127.0.0.1\r\nContent-Length: ${body.length}\r\nConnection: close\r\n\r\n',
          ),
        );
        socket.add(body);
        await socket.flush();
        final response = <int>[];
        await for (final chunk in socket.timeout(const Duration(seconds: 15))) {
          response.addAll(chunk);
        }
        socket.destroy();
        final split = response.indexOf(13);
        if (split < 0) {
          throw StateError('Acceptance channel closed without a response');
        }
        final status = ascii.decode(response.sublist(0, split));
        if (!status.contains(method == 'GET' ? ' 200 ' : ' 204 ')) {
          throw StateError('Acceptance channel request failed');
        }
        for (var i = 0; i + 3 < response.length; i++) {
          if (response[i] == 13 &&
              response[i + 1] == 10 &&
              response[i + 2] == 13 &&
              response[i + 3] == 10) {
            return response.sublist(i + 4);
          }
        }
        return [];
      }

      final measurements = <Map<String, dynamic>>[];
      var screenshotReady = false;

      Future<void> publish(String path, List<int> bytes) async {
        await exchange('POST', Uri(path: '/$path').toString(), bytes);
      }

      Future<T?> measure<T>(
        String name,
        Future<T> Function() action,
        Map<String, dynamic> Function(T) summarize,
      ) async {
        final watch = Stopwatch()..start();
        try {
          final result = await tester.runAsync(
            () => action().timeout(const Duration(seconds: 65)),
          );
          if (result == null) throw StateError('No result');
          final summary = summarize(result);
          final record = {
            'name': name,
            'ms': watch.elapsedMilliseconds,
            ...summary,
          };
          measurements.add(record);
          // Only names, counts, known error codes and timing leave the device.
          // ignore: avoid_print
          print('LIVE_AUDIT ${jsonEncode(record)}');
          await tester.runAsync(
            () => publish('report', utf8.encode(jsonEncode(measurements))),
          );
          return result;
        } catch (_) {
          final record = {
            'name': name,
            'ms': watch.elapsedMilliseconds,
            'exception': true,
          };
          measurements.add(record);
          // ignore: avoid_print
          print('LIVE_AUDIT ${jsonEncode(record)}');
          return null;
        }
      }

      Map<String, dynamic> readSummary(live.ReadOnlyResponse result) => {
        'failure': result.failure?.name,
        'stale': result.stale,
        'hasPayload': result.payload != null,
        if (result.payload != null) 'bytes': result.payload!.length,
      };
      Future<void> capture(String name) async {
        if (!screenshotReady) {
          await binding.convertFlutterSurfaceToImage();
          screenshotReady = true;
        }
        await tester.pump();
        final bytes = await binding.takeScreenshot(name);
        binding.reportData?.remove('screenshots');
        await tester.runAsync(() => publish('screenshot/$name', bytes));
        expect(tester.takeException(), isNull);
      }

      Future<void> ready(String name) async {
        final watch = Stopwatch()..start();
        var stableFrames = 0;
        while (watch.elapsed < const Duration(seconds: 50)) {
          await tester.pump(const Duration(milliseconds: 100));
          final loading = find
              .byWidgetPredicate(
                (widget) =>
                    widget is CupertinoActivityIndicator && widget.animating,
              )
              .evaluate()
              .isNotEmpty;
          stableFrames = loading ? 0 : stableFrames + 1;
          if (stableFrames >= 5) break;
        }
        measurements.add({
          'name': 'ui-$name',
          'readyMs': watch.elapsedMilliseconds,
          'ready': stableFrames >= 5,
        });
        expect(
          stableFrames,
          greaterThanOrEqualTo(5),
          reason: 'UI load exceeded 50 seconds',
        );
        expect(tester.takeException(), isNull);
      }

      Future<void> page(
        String name,
        Widget child, {
        Brightness brightness = Brightness.light,
        double textScale = 1,
      }) async {
        await tester.pumpWidget(
          KeyedSubtree(
            key: UniqueKey(),
            child: ginkgoApp(
              brightness: brightness,
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(textScale),
                    disableAnimations: textScale > 1,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
        await ready(name);
        await capture(name);
        await tester.runAsync(
          () => publish('report', utf8.encode(jsonEncode(measurements))),
        );
      }

      try {
        final credentials = await tester.runAsync(() async {
          return jsonDecode(
            utf8.decode(await exchange('GET', '/credentials', [])),
          ) as Map<String, dynamic>;
        });
        expect(credentials, isNotNull);
        // Exercise the actual login form, rather than substituting a login result.
        live.SessionResponse? session;
        final loginWatch = Stopwatch()..start();
        await tester.pumpWidget(
          ginkgoApp(
            home: LoginPage(
              service: service,
              onSignedIn: (value) => session = value,
              onDemo: () {},
            ),
          ),
        );
        await settle(tester, frames: 4);
        await tester.enterText(
          find.byKey(const Key('login-account')),
          credentials!['account'] as String,
        );
        await tester.enterText(
          find.byKey(const Key('login-password')),
          credentials['password'] as String,
        );
        credentials.clear();
        await tester.tap(find.byKey(const Key('login-submit')));
        final loginWait = Stopwatch()..start();
        while (session == null &&
            loginWait.elapsed < const Duration(seconds: 90)) {
          if (find.text('继续使用').evaluate().isNotEmpty) {
            await tester.tap(find.text('继续使用'));
          }
          await tester.pump(const Duration(milliseconds: 100));
          final submit = find.byKey(const Key('login-submit'));
          if (session == null &&
              find.text('继续使用').evaluate().isEmpty &&
              submit.evaluate().isNotEmpty &&
              tester.widget<CupertinoButton>(submit).onPressed != null) {
            // A completed, rejected login already has an actionable UI error.
            // Do not wait for the deadline or silently retry real credentials.
            break;
          }
        }
        measurements.add({
          'name': 'login-form',
          'ms': loginWatch.elapsedMilliseconds,
          'signedIn': session?.state == live.SessionState.signedIn,
          'remembered': session?.remembered,
        });
        expect(
          session?.state,
          live.SessionState.signedIn,
          reason: 'Real login must succeed',
        );
        // Remove password controllers immediately after successful login.
        await tester.pumpWidget(ginkgoApp(home: const SizedBox.shrink()));
        await settle(tester, frames: 2);

        final dates = await service.dates(
          DateTime.now().toUtc().toIso8601String(),
        );
        final today = dates.today;
        final previous = DateTime.parse(today)
            .subtract(const Duration(days: 1))
            .toIso8601String()
            .split('T')
            .first;
        await measure(
          'today',
          () => service.today(forceRefresh: true),
          (r) => {'failure': r.failure?.name, 'count': r.courses.length},
        );
        final schedule = await measure(
          'schedule',
          () => service.schedule(forceRefresh: true),
          (r) => {
            'failure': r.failure?.name,
            'count': r.courses.length,
            'terms': r.terms.length,
            'weeks': r.weeks.length,
            'exams': r.exams.length,
          },
        );
        if (schedule != null && schedule.weeks.length > 1) {
          final week = schedule.weeks
              .where((week) => week.number != schedule.weekNumber)
              .first;
          await measure(
            'schedule-other-week',
            () => service.schedule(
              termId: schedule.termId,
              week: week.number,
              forceRefresh: true,
            ),
            (r) => {'failure': r.failure?.name, 'count': r.courses.length},
          );
        }
        await measure(
          'grade-terms',
          service.gradeTerms,
          (r) => {'failure': r.failure?.name, 'count': r.terms.length},
        );
        await measure(
          'grades',
          () => service.grades(forceRefresh: true),
          (r) => {'failure': r.failure?.name, 'count': r.courses.length},
        );
        for (var campus = 1; campus <= 3; campus++) {
          await measure(
            'classrooms-$campus',
            () => service.classrooms(
              dto.DemoScope(campus: campus, date: today, forceRefresh: true),
              const dto.ClassroomQuery(
                search: '',
                section: 0,
                minimumFreeSections: 0,
                minimumConsecutiveSections: 0,
                sort: dto.ClassroomSort.name,
              ),
            ),
            (r) => {
              'failure': r.failure?.name,
              'count': r.roomCount,
              'buildings': r.buildingCount,
            },
          );
        }
        await measure(
          'checkin-today',
          () => service.checkin(forceRefresh: true),
          (r) => {'failure': r.failure?.name, 'count': r.courses.length},
        );
        await measure(
          'checkin-history',
          () => service.checkinOnDate(previous, forceRefresh: true),
          (r) => {'failure': r.failure?.name, 'count': r.courses.length},
        );
        final homework = await measure(
          'homework',
          () => service.homework(forceRefresh: true),
          (r) => {'failure': r.failure?.name, 'count': r.items.length},
        );
        if (homework?.items.isNotEmpty == true) {
          await measure(
            'homework-detail',
            () => service.homeworkDetail(
              homework!.items.first.id.replaceFirst('spoc:', ''),
              forceRefresh: true,
            ),
            (r) => {
              'failure': r.failure?.name,
              'hasContent': r.content != null,
              'hasPublished': r.publishedAt != null,
              'hasDue': r.dueAt != null,
              'hasScore': r.score != null,
              'hasSubmitted': r.submittedAt != null,
            },
          );
        }
        await measure(
          'bykc-catalog',
          () => live.loadBykc(forceRefresh: true),
          readSummary,
        );
        await measure(
          'bykc-chosen',
          () => live.loadBykcChosen(forceRefresh: true),
          readSummary,
        );
        await measure(
          'bykc-statistics',
          () => live.loadBykcStatistics(forceRefresh: true),
          readSummary,
        );
        await measure(
          'graduate-status',
          () => live.loadGraduatePart(report: false, forceRefresh: true),
          readSummary,
        );
        await measure(
          'graduate-report',
          () => live.loadGraduatePart(report: true, forceRefresh: true),
          readSummary,
        );
        await measure(
          'library-public',
          () => service.libraryStats(forceRefresh: true),
          readSummary,
        );
        final venues = await measure(
          'library-venues',
          () => service.libraryVenues(forceRefresh: true),
          (r) => {'failure': r.failure?.name, 'count': r.venues.length},
        );
        await measure(
          'library-bookings',
          () => service.libraryBookings(forceRefresh: true),
          (r) => {'failure': r.failure?.name, 'count': r.bookings.length},
        );
        final history = await measure(
          'library-history',
          () => service.libraryHistory(1, forceRefresh: true),
          (r) => {
            'failure': r.failure?.name,
            'count': r.bookings.length,
            'hasNext': r.hasNext,
          },
        );
        if (history?.hasNext == true) {
          await measure(
            'library-history-next',
            () => service.libraryHistory(2, forceRefresh: true),
            (r) => {
              'failure': r.failure?.name,
              'count': r.bookings.length,
              'hasNext': r.hasNext,
            },
          );
        }
        dto.LibraryVenue? visualVenue;
        dto.LibraryArea? visualArea;
        dto.LibrarySlot? visualSlot;
        dto.LibrarySeat? visualSeat;
        if (venues?.venues.isNotEmpty == true) {
          visualVenue = venues!.venues.first;
          final areas = await measure(
            'library-areas',
            () => service.libraryAreas(visualVenue!.id),
            (r) => {'failure': r.failure?.name, 'count': r.areas.length},
          );
          if (areas?.areas.isNotEmpty == true) {
            final area =
                areas!.areas.where((a) => a.free > 0).firstOrNull ??
                areas.areas.first;
            visualArea = area;
            final slots = await measure(
              'library-slots',
              () => service.librarySlots(area.id),
              (r) => {'failure': r.failure?.name, 'count': r.slots.length},
            );
            if (slots?.slots.isNotEmpty == true) {
              visualSlot = slots!.slots.first;
              final seats = await measure(
                'library-seats',
                () => service.librarySeats(
                  areaId: area.id,
                  slot: slots.slots.first,
                ),
                (r) => {'failure': r.failure?.name, 'count': r.seats.length},
              );
              visualSeat = seats?.seats.where((s) => s.available).firstOrNull;
            }
          }
        }
        await measure(
          'notices',
          () => live.loadNotices(forceRefresh: true),
          readSummary,
        );
        final sites = await measure(
          'cgyy-venues',
          () => live.loadCgyy(
            kind: 'venues',
            siteId: 0,
            date: today,
            forceRefresh: true,
          ),
          readSummary,
        );
        if (sites?.payload != null) {
          final list = jsonDecode(sites!.payload!) as List;
          if (list.isNotEmpty) {
            await measure(
              'cgyy-day',
              () => live.loadCgyy(
                kind: 'day',
                siteId: (list.first as Map)['id'] as int,
                date: today,
                forceRefresh: true,
              ),
              readSummary,
            );
          }
        }
        await measure(
          'cgyy-orders',
          () => live.loadCgyy(
            kind: 'orders',
            siteId: 0,
            date: today,
            forceRefresh: true,
          ),
          readSummary,
        );
        const maintenance = NativeMaintenanceService();
        await measure(
          'diagnostic-bridge',
          maintenance.checkBridge,
          (r) => {'passed': r},
        );
        await measure(
          'diagnostic-storage',
          maintenance.checkStorage,
          (r) => {'passed': r},
        );
        await measure(
          'diagnostic-vault',
          maintenance.checkVault,
          (r) => {'passed': r},
        );
        await measure(
          'update',
          () => maintenance.checkUpdate('0.1.0-alpha.2'),
          (r) => {'latest': r.latest, 'apkAvailable': r.apkAvailable},
        );
        await measure(
          'schedule-cache',
          service.schedule,
          (r) => {'failure': r.failure?.name, 'count': r.courses.length},
        );
        await measure(
          'homework-cache',
          service.homework,
          (r) => {'failure': r.failure?.name, 'count': r.items.length},
        );
        await measure(
          'graduate-report-cache',
          () => live.loadGraduatePart(report: true, forceRefresh: false),
          readSummary,
        );

        // Real-data pages, including independent tabs and navigation, are rendered
        // on the Android engine. Images go only to the private temporary server.
        await page('today', const TodayPage(service: service));
        await page('schedule', const SchedulePage(service: service));
        await page('grades', const GradesPage(service: service));
        await page('checkin', const CheckInPage(service: service));
        await page(
          'checkin-history',
          const CheckInPage(service: service, history: true),
        );
        await page('homework', const HomeworkPage(service: service));
        if (homework?.items.isNotEmpty == true) {
          final item = homework!.items.first;
          final row = find.byKey(Key('homework-${item.id}'));
          await show(tester, row, scrollKey: 'homework-scroll');
          await tester.tap(row);
          await ready('homework-detail');
          await capture('homework-detail');
          await tester.tap(find.byType(CupertinoNavigationBarBackButton).first);
          await ready('homework-return');
        }
        await page('bykc', const BykcPage());
        await tester.tap(find.text('已选课程'));
        await ready('bykc-chosen');
        await capture('bykc-chosen');
        await tester.tap(find.text('完成统计'));
        await ready('bykc-statistics');
        await capture('bykc-statistics');
        await page('graduate', const GraduatePage());
        await tester.tap(find.text('课程'));
        await ready('graduate-courses');
        await capture('graduate-courses');
        await tester.tap(find.text('学籍'));
        await ready('graduate-profile');
        await capture('graduate-profile');
        await page('library', const LibraryPage(service: service));
        if (visualVenue != null && visualArea != null && visualSlot != null) {
          final venueRow = find.byKey(Key('library-venue-${visualVenue.id}'));
          await show(tester, venueRow, scrollKey: 'library-scroll');
          await tester.tap(venueRow);
          await ready('library-areas');
          await capture('library-areas');
          final areaRow = find.byKey(Key('library-area-${visualArea.id}'));
          await show(tester, areaRow, scrollKey: 'library-areas-scroll');
          await tester.tap(areaRow);
          await ready('library-slots');
          await capture('library-slots');
          final slotRow = find.byKey(Key('library-slot-${visualSlot.id}'));
          await show(tester, slotRow, scrollKey: 'library-slots-scroll');
          await tester.tap(slotRow);
          await ready('library-seats');
          await capture('library-seats');
          if (visualSeat != null) {
            final reserve = find.byKey(Key('library-reserve-${visualSeat.id}'));
            await show(tester, reserve, scrollKey: 'library-seats-scroll');
            await tester.tap(reserve);
            await settle(tester, frames: 5);
            expect(find.text('确认预约？'), findsOneWidget);
            await capture('library-confirmation');
            // Only dismiss the confirmation. Never submit an upstream booking.
            await tester.tap(
              find
                  .descendant(
                    of: find.byType(CupertinoAlertDialog),
                    matching: find.byWidgetPredicate(
                      (widget) =>
                          widget is CupertinoDialogAction &&
                          !widget.isDefaultAction,
                    ),
                  )
                  .first,
            );
            await settle(tester, frames: 5);
            expect(find.text('确认预约？'), findsNothing);
          }
        }
        await page(
          'library-history',
          const LibraryHistoryPage(service: service),
        );
        await page('library-public', const LibraryStatsPage(service: service));
        await page('classroom', const ClassroomPage(service: service));
        await tap(tester, '查询空教室', scrollKey: 'classroom-scroll');
        await capture('classroom-results');
        await page('notices', const NoticesPage());
        await page('cgyy', const CgyyPage());
        final siteRows = find.text('我的预约记录');
        if (siteRows.evaluate().isNotEmpty) {
          await tester.tap(siteRows);
          await ready('cgyy-orders');
          await capture('cgyy-orders');
        }
        await page('tasks', const TasksPage());
        final taskDirectory = await tester.runAsync(
          () => Directory.systemTemp.createTemp('ginkgo-acceptance-tasks'),
        );
        try {
          await page(
            'tasks-empty',
            TasksPage(storageRoot: taskDirectory!.path),
          );
          await tester.tap(find.bySemanticsLabel('新增待办'));
          await settle(tester, frames: 5);
          await tester.enterText(
            find.byKey(const Key('task-title')),
            '设备验收临时待办',
          );
          await tester.tap(find.text('保存'));
          await ready('tasks-created');
          expect(find.text('设备验收临时待办'), findsOneWidget);
          await tester.tap(find.text('设备验收临时待办'));
          await settle(tester, frames: 5);
          await tester.enterText(
            find.byKey(const Key('task-title')),
            '设备验收临时待办已编辑',
          );
          await tester.tap(find.text('保存'));
          await ready('tasks-edited');
          await tester.tap(find.byIcon(CupertinoIcons.circle));
          await ready('tasks-completed');
          await capture('tasks-completed');
          await tester.tap(find.byIcon(CupertinoIcons.trash));
          await settle(tester, frames: 5);
          await tester.tap(find.text('删除'));
          await ready('tasks-deleted');
          expect(find.text('暂无待办'), findsOneWidget);
        } finally {
          await tester.pumpWidget(ginkgoApp(home: const SizedBox.shrink()));
          await tester.runAsync(() async {
            if (taskDirectory != null) {
              await taskDirectory.delete(recursive: true);
            }
          });
        }
        await page(
          'settings',
          SettingsPage(service: service, onSignOut: () async {}),
        );
        // Complete end-to-end shell acceptance without exposing an account name.
        await tester.pumpWidget(const GinkgoApp(service: service));
        await settle(tester);
        await capture('workspace');
        for (final tab in ['签到', '课表', '作业', '预约']) {
          await tapTab(tester, tab);
          await capture('tab-${['签到', '课表', '作业', '预约'].indexOf(tab)}');
        }
        await page(
          'library-dark-large',
          const LibraryPage(service: service),
          brightness: Brightness.dark,
          textScale: 1.8,
        );
        await page(
          'homework-dark-large',
          const HomeworkPage(service: service),
          brightness: Brightness.dark,
          textScale: 1.8,
        );
        await page(
          'bykc-dark-large',
          const BykcPage(),
          brightness: Brightness.dark,
          textScale: 1.8,
        );
        await tester.pumpWidget(
          ginkgoApp(
            brightness: Brightness.dark,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.8),
                  disableAnimations: true,
                ),
                child: const GraduatePage(),
              ),
            ),
          ),
        );
        await settle(tester);
        await capture('graduate-dark-large');
        await tester.pumpWidget(
          ginkgoApp(
            brightness: Brightness.dark,
            home: const CheckInPage(service: service),
          ),
        );
        await settle(tester);
        await capture('checkin-dark');
        expect(measurements.where((r) => r['exception'] == true), isEmpty);
        expect(measurements.where((r) => r['failure'] != null), isEmpty);
      } finally {
        await tester.pumpWidget(ginkgoApp(home: const SizedBox.shrink()));
        await settle(tester, frames: 2);
        await tester.runAsync(() async {
          final result = await service.signOut();
          expect(result.state, live.SessionState.signedOut);
          final restored = await service.restoreSession();
          expect(restored.state, live.SessionState.signedOut);
          expect(restored.remembered, isFalse);
          binding.reportData?.remove('screenshots');
          measurements.add({
            'name': 'signout',
            'signedOut': result.state == live.SessionState.signedOut,
          });
          await publish('report', utf8.encode(jsonEncode(measurements)));
        });
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 18)),
  );
}
