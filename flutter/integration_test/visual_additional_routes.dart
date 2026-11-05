import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:ginkgo_mirror/application/auth_challenge.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/graduate.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/library_loans.dart';
import 'package:ginkgo_mirror/features/library/library_loans_page.dart';
import 'package:ginkgo_mirror/features/auth/session_recovery_page.dart';
import 'package:ginkgo_mirror/features/checkin/checkin_page.dart';
import 'package:ginkgo_mirror/features/classroom/classroom_detail.dart';
import 'package:ginkgo_mirror/features/graduate/graduate_course_widgets.dart';
import 'package:ginkgo_mirror/features/graduate/graduate_credit_map_page.dart';
import 'package:ginkgo_mirror/features/graduate/graduate_page.dart';
import 'package:ginkgo_mirror/features/library/library_controller.dart';
import 'package:ginkgo_mirror/features/library/library_venue_selection_page.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_course_detail.dart';
import 'package:ginkgo_mirror/features/settings/gateway_challenge_page.dart';
import 'package:ginkgo_mirror/features/tasks/task_editor.dart';
import 'package:ginkgo_mirror/platform/update_gate.dart';

class VisualGatewayChallenge implements GatewayVerificationGateway {
  VisualGatewayChallenge(this.image);
  final List<int> image;
  @override
  Future<LoginChallenge?> gatewayChallenge({
    String? expectedId,
    bool refresh = false,
  }) async => LoginChallenge(
    id: 'synthetic-challenge',
    kind: 'text',
    textSupported: true,
    image: image,
  );
  @override
  Future<void> answerGatewayChallenge({
    required String expectedId,
    required String answer,
  }) async => throw StateError('合成视觉检查不提交认证');
}

class VisualLoanFailure implements LibraryLoansGateway {
  const VisualLoanFailure(this.failure);
  final FailureCode failure;
  @override
  Future<LibraryLoansRead> libraryLoans({int page = 1}) async =>
      LibraryLoansRead(failure: failure);
}

List<({String id, Widget Function() build})> additionalVisualRoutes(
  MirrorService service,
  LibraryController library,
  List<int> challengeImage,
) => [
  (
    id: 'update-required',
    build: () => UpdateRequiredPage(
      gate: const UpdateGate(minBuild: 20, message: '合成更新提示：请安装兼容版本后继续使用。'),
      installedVersion: '合成旧版本',
      onRetry: () async {},
    ),
  ),
  for (final failure in [
    FailureCode.sessionExpired,
    FailureCode.accessPolicyDenied,
    FailureCode.redirectLimit,
    FailureCode.serviceUnavailable,
  ])
    (
      id: 'library-loans-${failure.name.toLowerCase()}',
      build: () => LibraryLoansPage(gateway: VisualLoanFailure(failure)),
    ),
  (
    id: 'session-recovery',
    build: () => SessionRecoveryPage(
      message: '合成恢复失败：本机安全存储暂不可用，请稍后重试。',
      onRetry: () {},
      onLogin: () {},
    ),
  ),
  (
    id: 'gateway-challenge',
    build: () =>
        GatewayChallengePage(gateway: VisualGatewayChallenge(challengeImage)),
  ),
  (
    id: 'checkin-history',
    build: () => CheckInPage(service: service, history: true),
  ),
  (
    id: 'graduate-courses',
    build: () =>
        GraduatePage(service: service, initialView: GraduateView.courses),
  ),
  (
    id: 'graduate-profile',
    build: () =>
        GraduatePage(service: service, initialView: GraduateView.profile),
  ),
  (
    id: 'graduate-map-detail',
    build: () => GraduateCreditMapPage(
      service: service is GraduateCreditMapGateway
          ? service as GraduateCreditMapGateway
          : null,
      accountId: '__visual_review__',
    ),
  ),
  (
    id: 'graduate-course-detail',
    build: () => const GraduateCourseDetails(
      entry: GraduateCourseEntry(
        '专业课程',
        GraduateRow(
          title: '合成课程：高等计算机系统设计与实践',
          detail: '合成执行报告：本课程尚在修读，结果未确认',
          isCourse: true,
          completed: false,
          credit: 3,
          semester: '2026 秋季学期',
        ),
      ),
    ),
  ),
  (
    id: 'task-editor',
    build: () => TaskEditor(
      title: '合成待办：整理本周课程笔记',
      due: '2026-11-05 18:00',
      onSave: (_) async => false,
    ),
  ),
  (
    id: 'library-venues',
    build: () => LibraryVenueSelectionPage(
      controller: library,
      onOpenStats: () {},
      onSelectVenue: (_) {},
    ),
  ),
  (
    id: 'schedule-course-detail',
    build: () => ScheduleCourseDetailPage(
      course: const ScheduleCourse(
        id: 'visual',
        name: '合成课程：算法设计与复杂系统分析',
        day: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:35',
        teacher: '示例教师',
        place: '合成教学楼 A201',
      ),
      termName: '2026 秋季学期',
      weekNumber: 7,
      week: null,
      dayTitle: '10月19日 星期一',
      onOpenCheckIn: () {},
    ),
  ),
  (
    id: 'classroom-detail',
    build: () => ClassroomDetail(
      building: '合成教学楼',
      room: ClassroomRow(
        id: 'visual',
        name: 'A201',
        floor: '2',
        sections: Int32List.fromList([1, 2, 5, 6]),
        longestRun: 2,
        sectionStates: List.generate(
          12,
          (index) => SectionState(
            number: index + 1,
            available: [1, 2, 5, 6].contains(index + 1),
          ),
        ),
      ),
    ),
  ),
];
