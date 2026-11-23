import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/checkin_qr.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/features/checkin/checkin_page.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/features/library/library_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

import 'mirror_widget_test.dart'
    show ControlledService, checkInFixture, libraryBookingsFixture;

class WriteService extends ControlledService {
  int writes = 0, readbacks = 0;
  bool markSignedOnReadback = false;
  final qrCalls = <(String, bool)>[];
  final pending = Completer<MutationResponse>();
  @override
  bool get isDemo => false;
  @override
  Future<CheckInResponse> checkin({bool forceRefresh = false}) async {
    if (forceRefresh) readbacks++;
    if (markSignedOnReadback && forceRefresh) {
      return CheckInResponse(
        date: checkInFixture.date,
        courses: [
          for (final c in checkInFixture.courses)
            CheckInCourse(
              id: c.id,
              courseName: c.courseName,
              beginsAt: c.beginsAt,
              endsAt: c.endsAt,
              status: CheckInStatus.signed,
              classroomName: c.classroomName,
              teacherName: c.teacherName,
              mergedRecordCount: c.mergedRecordCount,
              conflicting: c.conflicting,
              signInAllowed: c.signInAllowed,
            ),
        ],
        fromCache: false,
        stale: false,
      );
    }
    return checkInFixture;
  }

  @override
  Future<CheckInQrResponse> prepareCheckinQr(
    String courseId, {
    bool revalidateCourse = true,
  }) async {
    qrCalls.add((courseId, revalidateCourse));
    return CheckInQrResponse(
      courseId: courseId,
      fetchedAt: '2026-10-20T08:00:05+08:00',
      refreshSeconds: 4,
      matrixSize: 21,
      modules: List<bool>.generate(21 * 21, (i) => i.isEven),
      demo: false,
    );
  }

  @override
  Future<MutationResponse> reserveLibrarySeat({
    required String areaId,
    required String seatId,
    required LibrarySlot slot,
  }) {
    writes++;
    return pending.future;
  }

  @override
  Future<LibraryBookingsResponse> libraryBookings({bool forceRefresh = false}) {
    if (forceRefresh) readbacks++;
    return Future.value(
      writes == 0
          ? const LibraryBookingsResponse(
              bookings: [],
              fromCache: false,
              stale: false,
            )
          : libraryBookingsFixture,
    );
  }
}

class RepeatedCourseService extends ControlledService {
  @override
  Future<CheckInResponse> checkin({bool forceRefresh = false}) async {
    CheckInCourse target(
      String id,
      String name,
      String begin,
      String end,
      String classroom,
    ) => CheckInCourse(
      id: id,
      courseName: name,
      beginsAt: begin,
      endsAt: end,
      status: CheckInStatus.notSigned,
      classroomName: classroom,
      mergedRecordCount: 1,
      conflicting: false,
      signInAllowed: true,
    );
    return CheckInResponse(
      date: '2026-10-20',
      courses: [
        target('101', '机器人控制技术', '09:50', '12:15', 'B228'),
        target('102', '机器人控制技术', '09:50', '12:15', 'B229'),
        target('201', '嵌入式系统', '14:00', '15:35', 'C101'),
        target('202', '嵌入式系统', '14:00', '15:35', 'C102'),
      ],
      fromCache: false,
      stale: false,
    );
  }
}

void main() {
  testWidgets(
    'checkin opens live QR sheet, saves PNG to gallery and verifies status readback',
    (tester) async {
      final service = WriteService();
      Uint8List? savedPng;
      tester.view.physicalSize = const Size(430, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ginkgoApp(
          home: CheckInPage(
            service: service,
            platformActions: PlatformActions(
              checkinQrSaver: (bytes, {required isCurrent}) async {
                expect(isCurrent(), isTrue);
                savedPng = bytes;
                return CheckinQrSaveStatus.savedToGallery;
              },
            ),
            clock: () => DateTime.parse('2026-10-20T08:00:00+08:00'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('checkin-submit-501'));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('checkin-qr-sheet')), findsOneWidget);
      expect(find.byKey(const Key('checkin-qr-canvas')), findsOneWidget);
      expect(service.qrCalls, [('501', true)]);

      // Render and save QR PNG inside test binding (runAsync for ui.Image.toByteData).
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('checkin-qr-save')));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(savedPng, isNotNull);
      expect(savedPng!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(service.qrCalls, [('501', true), ('501', false)]);
      expect(find.textContaining('已存至系统相册首张'), findsOneWidget);

      service.markSignedOnReadback = true;
      await tester.tap(find.byKey(const Key('checkin-qr-verify')));
      await tester.pumpAndSettle();
      expect(service.readbacks, 1);
      expect(find.byKey(const Key('checkin-qr-confirmed')), findsOneWidget);
      expect(find.text('签到已确认'), findsOneWidget);
      await tester.tap(find.byKey(const Key('checkin-qr-close')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'split teaching-class targets keep session totals and sign-in actions',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ginkgoApp(
          home: CheckInPage(
            service: RepeatedCourseService(),
            clock: () => DateTime.parse('2026-10-20T09:45:00+08:00'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今天 4 节课'), findsOneWidget);
      expect(find.text('已签到 0 · 未签到 4'), findsOneWidget);
      expect(find.text('待签 4'), findsOneWidget);
      for (final id in ['101', '102', '201', '202']) {
        expect(find.byKey(Key('checkin-submit-$id')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unsigned status resolves its contrast in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.dark),
        home: CheckInPage(service: WriteService()),
      ),
    );
    await tester.pumpAndSettle();
    final label = find.text('未签到');
    final expected = AppleDesign.statusInactive.resolveFrom(
      tester.element(label),
    );
    expect(tester.widget<Text>(label).style!.color, expected);
    final footer = find.textContaining('保存至相册后在智慧北航扫一扫完成签到');
    await tester.scrollUntilVisible(
      footer,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.widget<Text>(footer).style!.color,
      CupertinoColors.secondaryLabel.resolveFrom(tester.element(footer)),
    );
  });

  testWidgets(
    'seat reservation confirms exact date and seat and rechecks bookings',
    (tester) async {
      final service = WriteService();
      tester.view.physicalSize = const Size(430, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ginkgoApp(home: LibraryPage(service: service)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('library-find-seats')));
      await tester.pumpAndSettle();
      for (final key in [
        'library-venue-v1',
        'library-area-a1',
        'library-slot-2026-10-20/t1',
      ]) {
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('library-reserve-s1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('A-01\n2026-10-20'), findsOneWidget);
      expect(service.writes, 0);
      await tester.tap(find.text('确认预约'));
      await tester.pump();
      expect(service.writes, 1);
      service.pending.complete(
        const MutationResponse(state: 'accepted', message: '测试：学校已受理'),
      );
      await tester.pumpAndSettle();
      expect(service.readbacks, 1);
      expect(find.text('查看预约'), findsOneWidget);
      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const Key('library-reserve-s1')),
            )
            .onPressed,
        isNull,
      );
      // The original route must receive the readback, not only a new page.
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library-scroll')), findsOneWidget);
      expect(find.text('当前没有进行中的预约'), findsNothing);
      expect(
        find.text(libraryBookingsFixture.bookings.single.title),
        findsOneWidget,
      );
      expect(service.readbacks, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
