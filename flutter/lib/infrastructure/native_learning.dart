import 'dart:typed_data';

import '../application/contracts.dart';
import '../application/learning.dart';
import '../application/learning_context.dart';
import '../src/rust/api/live.dart' as live;
import 'package:ginkgo_mirror/infrastructure/learning_payload.dart';
import 'package:ginkgo_mirror/infrastructure/learning_snapshot_store.dart';

/// Native business adapter shared by the account-bound workspace service.
mixin NativeLearning
    implements
        LearningCourseGateway,
        CourseAnnouncementGateway,
        CourseResourceGateway,
        CourseAssessmentGateway,
        CourseLearningContextGateway {
  String? get expectedAccount;

  String get _owner {
    final owner = expectedAccount;
    if (owner == null || owner.isEmpty) throw StateError('账号未绑定');
    return owner;
  }

  @override
  Future<LearningRead<List<LearningCourse>>> learningCourses({
    bool forceRefresh = false,
  }) async => decodeLearningRead(
    await learningSnapshots.read(
      _owner,
      () => live.learningCourses(expectedAccount: _owner, force: forceRefresh),
    ),
    decodeCourses,
  );

  @override
  Future<LearningRead<List<CourseAnnouncement>>> courseAnnouncements(
    String course, {
    bool forceRefresh = false,
  }) async => decodeLearningRead(
    await learningSnapshots.read(
      _owner,
      () => live.courseAnnouncements(
        expectedAccount: _owner,
        course: course,
        force: forceRefresh,
      ),
    ),
    decodeAnnouncements,
  );

  @override
  Future<CourseAnnouncementDetail> courseAnnouncementDetail(
    String course,
    String id,
  ) async => decodeLearningRead(
    await live.courseAnnouncementDetail(
      expectedAccount: _owner,
      course: course,
      id: id,
    ),
    decodeAnnouncement,
  ).data;

  @override
  Future<LearningRead<CourseResourcePage>> courseResources(
    String course, {
    String? folder,
    int page = 1,
    bool forceRefresh = false,
  }) async => decodeLearningRead(
    await learningSnapshots.read(
      _owner,
      () => live.courseResources(
        expectedAccount: _owner,
        course: course,
        folder: folder,
        page: page,
        force: forceRefresh,
      ),
    ),
    decodeResources,
  );

  @override
  Future<LearningRead<List<CourseAssessment>>> courseAssessments(
    String course, {
    bool forceRefresh = false,
  }) async => decodeLearningRead(
    await learningSnapshots.read(
      _owner,
      () => live.courseAssessments(
        expectedAccount: _owner,
        course: course,
        force: forceRefresh,
      ),
    ),
    decodeAssessments,
  );

  LearningDownload _download(live.HomeworkFileDownloadResponse r) {
    if (r.failure != null || r.name == null || r.bytes == null) {
      throw StateError('学习附件下载失败，请前往官网');
    }
    return LearningDownload(r.name!, Uint8List.fromList(r.bytes!));
  }

  @override
  Future<LearningDownload> courseResourceDownload(
    String course,
    String id, {
    String? folder,
    int page = 1,
  }) async => _download(
    await live.courseResourceDownload(
      expectedAccount: _owner,
      course: course,
      folder: folder,
      page: page,
      id: id,
    ),
  );

  @override
  Future<LearningDownload> courseAnnouncementAttachment(
    String course,
    String id,
    String file,
  ) async => _download(
    await live.courseAnnouncementAttachment(
      expectedAccount: _owner,
      course: course,
      id: id,
      file: file,
    ),
  );

  @override
  Future<LearningRead<List<LearningColumn>>> learningColumns(
    String course, {
    bool forceRefresh = false,
  }) async => decodeLearningRead(
    await learningSnapshots.read(
      _owner,
      () => live.courseLearningColumns(
        expectedAccount: _owner,
        course: course,
        force: forceRefresh,
      ),
    ),
    decodeLearningColumns,
  );
  @override
  Future<LearningCapabilities> learningCapabilities(String course) async =>
      decodeLearningRead(
        await live.courseLearningCapabilities(
          expectedAccount: _owner,
          course: course,
        ),
        decodeLearningCapabilities,
      ).data;
  @override
  Future<LearningRead<List<CourseAnnouncement>>> courseAnnouncementsIn(
    String course,
    String column, {
    bool forceRefresh = false,
  }) async => decodeLearningRead(
    await learningSnapshots.read(
      _owner,
      () => live.courseAnnouncementsIn(
        expectedAccount: _owner,
        course: course,
        column: column,
        force: forceRefresh,
      ),
    ),
    decodeAnnouncements,
  );
  @override
  Future<CourseAnnouncementDetail> courseAnnouncementDetailIn(
    String course,
    String column,
    String id,
  ) async => decodeLearningRead(
    await live.courseAnnouncementDetailIn(
      expectedAccount: _owner,
      course: course,
      column: column,
      id: id,
    ),
    decodeAnnouncement,
  ).data;
  @override
  Future<LearningDownload> courseAnnouncementAttachmentIn(
    String course,
    String column,
    String id,
    String file,
  ) async => _download(
    await live.courseAnnouncementAttachmentIn(
      expectedAccount: _owner,
      course: course,
      column: column,
      id: id,
      file: file,
    ),
  );
  @override
  Future<LearningRead<List<CourseAssessment>>> courseAssessmentsIn(
    String course,
    String column, {
    bool forceRefresh = false,
  }) async => decodeLearningRead(
    await learningSnapshots.read(
      _owner,
      () => live.courseAssessmentsIn(
        expectedAccount: _owner,
        course: course,
        column: column,
        force: forceRefresh,
      ),
    ),
    decodeAssessments,
  );
  @override
  Future<LearningRead<CourseResourcePage>> courseResourcesAt(
    String course, {
    List<String> path = const [],
    int page = 1,
    bool forceRefresh = false,
  }) async => decodeLearningRead(
    await learningSnapshots.read(
      _owner,
      () => live.courseResourcesAt(
        expectedAccount: _owner,
        course: course,
        path: path,
        page: page,
        force: forceRefresh,
      ),
    ),
    decodeResources,
  );
  @override
  Future<LearningDownload> courseResourceDownloadAt(
    String course,
    String id, {
    List<String> path = const [],
    int page = 1,
  }) async => _download(
    await live.courseResourceDownloadAt(
      expectedAccount: _owner,
      course: course,
      id: id,
      path: path,
      page: page,
    ),
  );
}
