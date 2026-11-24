import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/checkin_qr.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/features/checkin/checkin_qr_sheet.dart';

class _FakeCheckInGateway extends Fake implements CheckInGateway {
  final List<(String courseId, bool revalidate, int offsetMs)> qrCalls = [];

  @override
  bool get isDemo => false;

  @override
  Future<CheckInQrResponse> prepareCheckinQr(
    String courseId, {
    bool revalidateCourse = true,
    int offsetMs = 0,
  }) async {
    qrCalls.add((courseId, revalidateCourse, offsetMs));
    return CheckInQrResponse(
      courseId: courseId,
      fetchedAt: '2026-11-24T08:00:05+08:00',
      refreshSeconds: 0,
      matrixSize: 21,
      modules: List<bool>.filled(21 * 21, true),
      demo: false,
    );
  }
}

class _FakeQuickHelper implements CheckinQrQuickHelper {
  _FakeQuickHelper({
    this.host = CheckinScannerHost.ibuaa,
    this.notificationStatus = CheckinQuickNotificationStatus.shown,
  });

  final CheckinScannerHost host;
  final CheckinQuickNotificationStatus notificationStatus;
  int launchCount = 0;
  int dismissCount = 0;
  final List<String?> notificationTexts = [];
  Future<void> Function()? refreshHandler;

  @override
  Future<CheckinScannerHost> probeScannerApp() async => host;

  @override
  Future<CheckinScannerHost> launchScannerApp() async {
    launchCount++;
    return host;
  }

  @override
  Future<CheckinQuickNotificationStatus> showQuickNotification({
    String? statusText,
  }) async {
    notificationTexts.add(statusText);
    return notificationStatus;
  }

  @override
  Future<void> dismissQuickNotification() async {
    dismissCount++;
  }

  @override
  void setRefreshFromNotificationHandler(Future<void> Function()? handler) {
    refreshHandler = handler;
  }
}

const _sampleCourse = CheckInCourse(
  id: 'sched-501',
  courseName: '计算机组成',
  beginsAt: '08:00',
  endsAt: '09:35',
  classroomName: '新主楼A101',
  status: CheckInStatus.notSigned,
  signInAllowed: true,
  mergedRecordCount: 1,
  conflicting: false,
);

void main() {
  testWidgets(
    'save with scanner host applies +2s offset, launches host, and supports notification refresh',
    (tester) async {
      final service = _FakeCheckInGateway();
      final helper = _FakeQuickHelper();
      final savedImages = <Uint8List>[];
      Completer<void>? nextSave;
      var signed = false;

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: CheckinQrSheet(
              course: _sampleCourse,
              dateLabel: '2026-11-24',
              service: service,
              platformActions: PlatformActions(
                checkinQrSaver: (bytes, {required isCurrent}) async {
                  savedImages.add(bytes);
                  final pending = nextSave;
                  if (pending != null && !pending.isCompleted) {
                    pending.complete();
                  }
                  return CheckinQrSaveStatus.savedToGallery;
                },
                checkinQrHelper: helper,
              ),
              isContextValid: () => true,
              onVerifySigned: () async => signed,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(service.qrCalls, [('sched-501', true, 0)]);
      expect(find.text('存相册并打开智慧北航'), findsOneWidget);
      expect(find.byKey(const Key('checkin-qr-quick-helper-banner')), findsOneWidget);
      expect(helper.notificationTexts.length, 1);
      expect(helper.refreshHandler, isNotNull);

      Future<void> waitForSave(Completer<void> done) async {
        for (var i = 0; i < 100 && !done.isCompleted; i++) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
        }
        expect(done.isCompleted, isTrue);
        await tester.pumpAndSettle();
      }

      // Primary action saves with +2000ms buffer and launches 智慧北航.
      final firstSave = Completer<void>();
      nextSave = firstSave;
      await tester.tap(find.byKey(const Key('checkin-qr-save')));
      await waitForSave(firstSave);
      expect(service.qrCalls.last, ('sched-501', false, kCheckinQrSaveOffsetMs));
      expect(savedImages.length, 1);
      expect(helper.launchCount, 1);

      // Secondary action saves with +2000ms buffer without launching scanner.
      final secondSave = Completer<void>();
      nextSave = secondSave;
      await tester.tap(find.byKey(const Key('checkin-qr-save-only')));
      await waitForSave(secondSave);
      expect(service.qrCalls.last, ('sched-501', false, kCheckinQrSaveOffsetMs));
      expect(savedImages.length, 2);
      expect(helper.launchCount, 1);

      // Notification shade refresh triggers background fetch+save+status update.
      await tester.runAsync(() async {
        await helper.refreshHandler!.call();
      });
      await tester.pumpAndSettle();
      expect(service.qrCalls.last, ('sched-501', false, kCheckinQrSaveOffsetMs));
      expect(savedImages.length, 3);
      expect(helper.notificationTexts.last, contains('刷新相册首图'));

      // Confirming sign-in dismisses the ongoing quick notification.
      signed = true;
      await tester.tap(find.byKey(const Key('checkin-qr-verify')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('checkin-qr-confirmed')), findsOneWidget);
      expect(helper.dismissCount, greaterThanOrEqualTo(1));

      // Disposing cleans up handler.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(helper.refreshHandler, isNull);
    },
  );

  testWidgets('permission denied notification shows non-blocking hint', (
    tester,
  ) async {
    final service = _FakeCheckInGateway();
    final helper = _FakeQuickHelper(
      host: CheckinScannerHost.none,
      notificationStatus: CheckinQuickNotificationStatus.permissionDenied,
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: CheckinQrSheet(
            course: _sampleCourse,
            dateLabel: '2026-11-24',
            service: service,
            platformActions: PlatformActions(
              checkinQrSaver: (bytes, {required isCurrent}) async =>
                  CheckinQrSaveStatus.savedToGallery,
              checkinQrHelper: helper,
            ),
            isContextValid: () => true,
            onVerifySigned: () async => false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('保存到相册（单机扫码）'), findsOneWidget);
    expect(find.textContaining('开启系统通知权限后'), findsOneWidget);
  });
}
