import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ginkgo_mirror/application/cgyy_commands.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/application/bykc.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/maintenance.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/query_snapshots.dart';
import 'package:ginkgo_mirror/infrastructure/demo_mirror_service.dart';
import 'package:ginkgo_mirror/features/academic/rules_page.dart';
import 'package:ginkgo_mirror/features/auth/login_page.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_booking_page.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_captcha_page.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_day_page.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_lock_code_page.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_models.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_order_detail_page.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_review_page.dart';
import 'package:ginkgo_mirror/features/homework/homework_detail_page.dart';
import 'package:ginkgo_mirror/features/learning/learning_announcement_page.dart';
import 'package:ginkgo_mirror/features/learning/learning_course_page.dart';
import 'package:ginkgo_mirror/features/learning/learning_snapshots_page.dart';
import 'package:ginkgo_mirror/features/library/library_area_page.dart';
import 'package:ginkgo_mirror/features/library/library_books_page.dart';
import 'package:ginkgo_mirror/features/library/library_history_page.dart';
import 'package:ginkgo_mirror/features/library/library_holdings_page.dart';
import 'package:ginkgo_mirror/features/library/library_seat_page.dart';
import 'package:ginkgo_mirror/features/library/library_slot_page.dart';
import 'package:ginkgo_mirror/features/library/library_stats_page.dart';
import 'package:ginkgo_mirror/features/schedule/course_range_page.dart';
import 'package:ginkgo_mirror/features/settings/network_diagnostics_page.dart';
import 'package:ginkgo_mirror/features/settings/maintenance_pages.dart';
import 'package:ginkgo_mirror/features/settings/preferences_pages.dart';
import 'package:ginkgo_mirror/platform/system_settings_service.dart';
import 'package:ginkgo_mirror/features/bykc/bykc_detail_page.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';
import 'package:ginkgo_mirror/shared/course_visibility.dart';
import 'package:ginkgo_mirror/shared/query_cache_scope.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';
import 'package:ginkgo_mirror/workspace/workspace_catalog.dart';
import 'package:ginkgo_mirror/workspace/workspace_shell.dart';

import 'support.dart' show settle;

const captureToHost = bool.fromEnvironment('GINKGO_VISUAL_CAPTURE');
const largeText = bool.fromEnvironment('GINKGO_VISUAL_LARGE');
const onlyPageIds = String.fromEnvironment('GINKGO_VISUAL_ONLY');

class _VisualSnapshotGateway implements LearningSnapshotGateway {
  @override
  Future<LearningSnapshotStatus> learningSnapshotStatus() async =>
      const LearningSnapshotStatus(supported: false);

  @override
  Future<LearningSnapshotStatus> setLearningSnapshotsEnabled(
    bool enabled,
  ) async => const LearningSnapshotStatus(supported: false);
}

/// This fixture serves only the read commands needed to paint CGYY pages.
/// Any booking, cancellation or acknowledgement command fails closed.
class _VisualCgyyGateway implements CgyyBookingGateway {
  @override
  Future<CgyyActionResult> executeCgyy(CgyyCommand command) async {
    if (command is CgyyOptionsCommand) {
      return CgyyActionResult.of(
        state: 'options',
        options: const CgyyBookingOptions(
          choices: [
            CgyyBookingChoice(
              spaceId: 1,
              spaceName: '合成研讨室 201',
              timeId: 1,
              time: '09:00–10:00',
            ),
          ],
          purposes: [CgyyPurpose(id: 1, name: '学术交流')],
          usesFallbackPurposes: false,
        ),
      );
    }
    if (command is CgyyReviewCommand) {
      return CgyyActionResult.of(
        state: 'reviewRequired',
        review: const CgyyReviewSnapshot(
          id: '__visual_review__',
          orders: [
            CgyyOrder(
              id: 9001,
              place: '合成研讨室 201',
              date: '2026-11-02',
              time: '09:00–10:00',
              status: '待核实',
            ),
          ],
        ),
      );
    }
    if (command is CgyyStatusCommand) {
      return CgyyActionResult.fromState('ready', '仅用于视觉检查');
    }
    throw StateError('视觉检查夹具不会执行写入命令');
  }
}

class _VisualMaintenanceService implements MaintenanceService {
  @override
  bool get supportsUpdates => false;

  @override
  Future<bool> checkPublicService(MirrorService service) async => false;

  @override
  Future<InstalledVersion> version() async =>
      const InstalledVersion('0.1.0-visual', '1');

  @override
  Future<UpdateResult> checkUpdate(String current) async =>
      const UpdateResult(latest: null, available: false, apkAvailable: false);

  @override
  Future<bool> openReleases(String? page) async => false;

  @override
  Future<bool> checkBridge() async => true;

  @override
  Future<bool> checkStorage() async => true;

  @override
  Future<bool> checkVault() async => true;
}

class _VisualSystemSettings implements SystemSettingsService {
  @override
  bool get isAndroid => true;

  @override
  Future<String> notificationPermission() async => 'granted';

  @override
  Future<String> requestNotifications() async => 'granted';

  @override
  Future<bool> openNotifications() async => false;

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> shareProject() async => false;
}

Future<String> _syntheticPng(int width, int height, Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = color,
  );
  canvas.drawCircle(
    ui.Offset(width * 0.65, height * 0.5),
    height * 0.22,
    ui.Paint()..color = CupertinoColors.white,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return base64Encode(data!.buffer.asUint8List());
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RustLib.init();
  });

  testWidgets('workspace destinations and synthetic subroutes render', (
    tester,
  ) async {
    await binding.convertFlutterSurfaceToImage();
    final root = await getTemporaryDirectory();
    final directory = Directory('${root.path}/all-pages-visual')
      ..createSync(recursive: true);
    final service = DemoMirrorService();
    final context = WorkspaceContext(
      service: service,
      platformActions: const PlatformActions(),
      mobile: true,
      accountName: '合成演示账号',
      accountId: '__visual_review__',
      openFeature: (_) {},
      openSettings: () {},
      onSignOut: () async {},
    );
    final rangePreferences = CourseVisibility(
      '__visual_review__',
      save: (_) async {},
      load: () async => <String>{},
    );
    await rangePreferences.restore();
    const venue = LibraryVenue(
      id: 'visual-venue',
      name: '合成图书馆',
      free: 20,
      total: 40,
    );
    const area = LibraryArea(
      id: 'visual-area',
      name: '合成阅览区',
      free: 5,
      total: 10,
    );
    const slot = LibrarySlot(
      id: '2026-11-02/visual',
      day: '11月2日',
      start: '09:00',
      end: '11:00',
    );
    const course = LearningCourse(
      id: 'demo-learning-course',
      name: '合成课程：系统设计与实践',
      sourceUrl: '',
      teacher: '示例教师',
      term: '2026 秋季学期',
    );
    const announcement = CourseAnnouncement(
      'demo-announcement',
      '课程学习说明（合成）',
      '2026-10-28',
    );
    const homework = HomeworkItem(
      id: 'demo-assignment',
      courseId: 'demo-course',
      courseName: '合成课程：系统设计与实践',
      title: '合成作业：整理课程要点',
      publishedAt: '2026-10-25 09:00',
      dueAt: '2026-11-05 23:59',
      status: HomeworkStatus.pending,
    );
    final cgyyGateway = _VisualCgyyGateway();
    final maintenanceService = _VisualMaintenanceService();
    final captcha = CgyyChallenge(
      id: '__visual_challenge__',
      background: await _syntheticPng(300, 150, const Color(0xff5a88b6)),
      jigsaw: await _syntheticPng(60, 150, const Color(0xffbc7137)),
    );
    final extraPages = <({String id, Widget Function() build})>[
      (
        id: 'bykc-detail',
        build: () => const BykcDetailPage(
          course: BykcCourse(
            id: 9001,
            name: '合成课程：计算机系统导论与实践',
            teacher: '示例教师',
            position: '合成教学楼 201',
            category: '自然科学',
            subcategory: '信息技术',
            details: BykcCourseDetails(
              start: '2026-10-20 08:00:00',
              end: '2026-10-20 09:35:00',
              selectStart: '2026-09-01 08:00:00',
              selectEnd: '2026-09-05 18:00:00',
              cancelEnd: '2026-09-04 18:00:00',
              capacity: 40,
              enrolled: 28,
              campuses: ['学院路校区'],
              summary: '用于设备视觉检查的合成课程说明。内容包含时间、地点、人数与较长课程简介。',
              selected: true,
              hasSignConfig: false,
            ),
          ),
          chosenRecord: BykcChosenRecord(
            id: 9001,
            course: BykcCourse(
              id: 9001,
              name: '合成课程：计算机系统导论与实践',
              category: '自然科学',
            ),
            selectedAt: '2026-09-02 10:00:00',
            checkin: 1,
            passed: 1,
            score: 92,
          ),
        ),
      ),
      (
        id: 'cgyy-captcha',
        build: () => CgyyCaptchaPage(
          gateway: cgyyGateway,
          challenge: captcha,
          summary: '合成场馆 · 11月2日 · 09:00–10:00',
          consumedChallenges: <String>{},
        ),
      ),
      (
        id: 'login',
        build: () =>
            LoginPage(service: service, onSignedIn: (_) {}, onDemo: () {}),
      ),
      (id: 'rules', build: () => RulesPage(service: service)),
      (
        id: 'homework-detail',
        build: () => HomeworkDetailPage(
          item: homework,
          fileActions: context.platformActions,
          service: service,
        ),
      ),
      (
        id: 'course-range',
        build: () => CourseRangePage(
          preferences: rangePreferences,
          system: 'spoc',
          courses: const {'visual-1': '合成课程：系统设计与实践', 'visual-2': '合成课程：数据库原理'},
        ),
      ),
      (
        id: 'learning-course',
        build: () => LearningCoursePage(
          course: course,
          service: service,
          accountId: '__visual_review__',
          saveFile: null,
          isOwnerCurrent: () => true,
        ),
      ),
      (
        id: 'learning-announcement',
        build: () => LearningAnnouncementPage(
          service: service,
          course: course.id,
          column: 'demo-announcements',
          announcement: announcement,
          isCurrent: () => true,
        ),
      ),
      (
        id: 'learning-snapshots',
        build: () => LearningSnapshotsPage(gateway: _VisualSnapshotGateway()),
      ),
      (
        id: 'library-area',
        build: () => LibraryAreaPage(
          service: service,
          venue: venue,
          onReservationChanged: () async {},
          onViewReservations: () {},
        ),
      ),
      (
        id: 'library-slot',
        build: () => LibrarySlotPage(
          service: service,
          area: area,
          onReservationChanged: () async {},
          onViewReservations: () {},
        ),
      ),
      (
        id: 'library-seat',
        build: () => LibrarySeatPage(
          service: service,
          area: area,
          slot: slot,
          onReservationChanged: () async {},
          onViewReservations: () {},
        ),
      ),
      (id: 'library-books', build: () => LibraryBooksPage(service: service)),
      (
        id: 'library-holdings',
        build: () => LibraryHoldingsPage(
          service: service,
          bibId: 'VISUAL-BOOK-1',
          title: '合成书目馆藏',
        ),
      ),
      (
        id: 'library-history',
        build: () => LibraryHistoryPage(service: service),
      ),
      (id: 'library-stats', build: () => LibraryStatsPage(service: service)),
      (
        id: 'cgyy-day',
        build: () => CgyyDayPage(
          demo: true,
          site: const CgyySite(id: 1, name: '合成研讨楼', campus: '学院路校区'),
          service: service,
        ),
      ),
      (
        id: 'cgyy-booking',
        build: () => CgyyBookingPage(
          gateway: cgyyGateway,
          siteId: 1,
          siteName: '合成研讨楼',
          date: '2026-11-02',
        ),
      ),
      (
        id: 'cgyy-order-detail',
        build: () =>
            CgyyOrderDetailPage(demo: true, service: service, orderId: 9001),
      ),
      (
        id: 'cgyy-lock-code',
        build: () => CgyyLockCodePage(demo: true, service: service),
      ),
      (id: 'cgyy-review', build: () => CgyyReviewPage(gateway: cgyyGateway)),
      (
        id: 'network-diagnostics',
        build: () => NetworkDiagnosticsPage(service: service),
      ),
      (
        id: 'system-preferences',
        build: () => SystemPreferencesPage(service: _VisualSystemSettings()),
      ),
      (id: 'appearance', build: () => const AppearancePage()),
      (id: 'privacy', build: () => const PrivacyPage()),
      (id: 'about', build: () => const AboutPage()),
      (
        id: 'software-update',
        build: () => SoftwareUpdatePage(
          service: maintenanceService,
          initialVersion: const InstalledVersion('0.1.0-visual', '1'),
        ),
      ),
      (
        id: 'diagnostics',
        build: () =>
            DiagnosticsPage(service: maintenanceService, mirror: service),
      ),
    ];

    Future<void> capture(String name) async {
      await settle(tester, frames: 12);
      expect(tester.takeException(), isNull, reason: 'rendering $name');
      final bytes = await binding.takeScreenshot(name);
      binding.reportData?.remove('screenshots');
      if (captureToHost) {
        await tester.runAsync(() async {
          final socket = await Socket.connect(
            '127.0.0.1',
            18765,
            timeout: const Duration(seconds: 5),
          );
          socket.add(
            'POST /$name.png HTTP/1.0\r\nHost: 127.0.0.1\r\nContent-Length: ${bytes.length}\r\n\r\n'
                .codeUnits,
          );
          socket.add(bytes);
          await socket.flush();
          await socket.drain<void>();
          socket.destroy();
        });
      }
      await File('${directory.path}/$name.png')
          .writeAsBytes(bytes, flush: true);
    }

    final pageFilter = onlyPageIds
        .split(',')
        .where((value) => value.isNotEmpty)
        .toSet();
    final shellOnly = pageFilter.contains('shell');
    final requestedPageIds = pageFilter
        .where((value) => value != 'shell')
        .toSet();
    final pages = <({String id, Widget Function() build})>[
      for (final destination in workspaceDestinations)
        (id: destination.id, build: () => destination.build(context)),
      ...extraPages,
    ];
    final selectedPages = pages
        .where(
          (page) =>
              requestedPageIds.isEmpty || requestedPageIds.contains(page.id),
        )
        .toList(growable: false);
    expect(workspaceDestinations, hasLength(21));
    if (pageFilter.isNotEmpty && !shellOnly) {
      expect(selectedPages.map((page) => page.id).toSet(), requestedPageIds);
    }

    for (final brightness in [Brightness.light, Brightness.dark]) {
      final mode = brightness == Brightness.light ? 'light' : 'dark';
      if (shellOnly) {
        final preferences = AppPreferences(writer: (_) async {});
        await preferences.update(textSize: largeText ? 1.6 : 1.0);
        await tester.pumpWidget(
          GinkgoApp(
            key: UniqueKey(),
            service: service,
            platformActions: context.platformActions,
            brightness: brightness,
            preferences: preferences,
            accountName: context.accountName,
            accountId: context.accountId,
            onSignOut: context.onSignOut,
          ),
        );
        await settle(tester, frames: 40);
        await capture('shell-today-$mode${largeText ? '-large' : ''}');
        for (final label in ['课表', '作业', '图书馆', '更多']) {
          await tester.tap(
            find.descendant(
              of: find.byType(CupertinoTabBar),
              matching: find.text(label),
            ),
          );
          await settle(tester, frames: 40);
          final id = switch (label) {
            '课表' => 'schedule',
            '作业' => 'homework',
            '图书馆' => 'library',
            _ => 'more',
          };
          await capture('shell-$id-$mode${largeText ? '-large' : ''}');
        }
        continue;
      }
      for (final route in selectedPages) {
        final preferences = AppPreferences(writer: (_) async {});
        await preferences.update(textSize: largeText ? 1.6 : 1.0);
        final page = CourseVisibilityScope(
          account: '__visual_review__',
          child: QueryCacheScope(child: route.build()),
        );
        final registeredDestination = workspaceDestinations.any(
          (destination) => destination.id == route.id,
        );
        final needsNavigationStack =
            !registeredDestination && route.id != 'login';
        await tester.pumpWidget(
          KeyedSubtree(
            key: UniqueKey(),
            child: ginkgoApp(
              home: needsNavigationStack
                  ? const CupertinoPageScaffold(
                      navigationBar: CupertinoNavigationBar(
                        middle: Text('工作区'),
                      ),
                      child: SizedBox.shrink(),
                    )
                  : page,
              brightness: brightness,
              preferences: preferences,
            ),
          ),
        );
        if (needsNavigationStack) {
          final navigator = tester.state<NavigatorState>(
            find.byType(Navigator).first,
          );
          unawaited(
            navigator.push<void>(
              CupertinoPageRoute<void>(builder: (_) => page),
            ),
          );
          await settle(tester, frames: 40);
        }
        if (route.id == 'library-loans') {
          expect(
            find.byKey(const Key('library-loans-read')),
            findsNothing,
            reason: 'the first read is offered in the page content',
          );
          expect(
            find.byKey(const Key('library-loans-first-read')),
            findsOneWidget,
          );
        }
        await capture('${route.id}-$mode${largeText ? '-large' : ''}');
      }
    }
    rangePreferences.dispose();
  });
}
