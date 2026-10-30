import 'dart:typed_data';

import '../application/contracts.dart';
import '../application/learning.dart';
import '../application/learning_context.dart';
import '../src/rust/api/live.dart' as live;

import 'package:ginkgo_mirror/infrastructure/learning_snapshot_store.dart';
import 'package:ginkgo_mirror/infrastructure/native_command.dart';

/// Projects typed bridge responses. A failure may accompany data only as a
/// previous successful snapshot; a failure without data is a hard error.
LearningRead<T> _read<T>({required FailureCode? failure, required T? data}) {
  if (data == null) throw StateError('学习服务读取失败，请重试或前往官网');
  return LearningRead(data, stale: failure != null, failure: failure);
}

List<LearningCourse> _courses(live.LearningCoursesResponse r) =>
    List.unmodifiable(
      (r.data ?? const []).map(
        (x) => LearningCourse(
          id: x.id,
          name: x.name,
          teacher: x.teacher,
          term: x.term,
          sourceUrl: x.sourceUrl,
        ),
      ),
    );

List<CourseAnnouncement> _announcements(live.CourseAnnouncementsResponse r) =>
    List.unmodifiable(
      (r.data ?? const []).map(
        (x) => CourseAnnouncement(x.id, x.title, x.publishedAt),
      ),
    );

CourseAnnouncementDetail _detail(live.CourseAnnouncementDetailResponse r) {
  final d = r.data!;
  return CourseAnnouncementDetail(
    id: d.id,
    title: d.title,
    content: d.content,
    attachments: d.attachments
        .map((a) => LearningAttachment(a.id, a.name))
        .toList(),
  );
}

CourseResourcePage _resources(live.CourseResourcePageResponse r) {
  final d = r.data!;
  return CourseResourcePage(
    d.items.map((a) {
      if (a.folder && a.downloadable) {
        throw const FormatException('资料目录不能当作文件下载');
      }
      return CourseResource(
        id: a.id,
        name: a.name,
        folder: a.folder,
        downloadable: a.downloadable,
        updatedAt: a.updatedAt,
        extension: a.extension_,
      );
    }).toList(),
    d.page,
    d.hasNext,
  );
}

List<CourseAssessment> _assessments(live.CourseAssessmentsResponse r) =>
    List.unmodifiable(
      (r.data ?? const []).map(
        (x) => CourseAssessment(
          id: x.id,
          title: x.title,
          startsAt: x.startsAt,
          dueAt: x.dueAt,
          score: x.score,
          sourceUrl: x.sourceUrl,
        ),
      ),
    );

List<LearningColumn> _columns(live.LearningColumnsResponse r) {
  final ids = <String>{};
  return List.unmodifiable(
    (r.data ?? const []).map((x) {
      final kind = switch (x.kind) {
        live.LearningColumnKindDto.announcement => 'announcement',
        live.LearningColumnKindDto.assessment => 'assessment',
      };
      if (x.id.isEmpty || !ids.add(x.id)) {
        throw const FormatException('课程栏目身份或类型无效');
      }
      return LearningColumn(id: x.id, name: x.name, kind: kind);
    }),
  );
}

LearningCapabilities _capabilities(live.LearningCapabilitiesResponse r) {
  String state(live.LearningCapabilityStateDto value) => switch (value) {
    live.LearningCapabilityStateDto.unknown => 'unknown',
    live.LearningCapabilityStateDto.available => 'available',
    live.LearningCapabilityStateDto.authRequired => 'authRequired',
    live.LearningCapabilityStateDto.temporarilyUnavailable =>
      'temporarilyUnavailable',
    live.LearningCapabilityStateDto.protocolChanged => 'protocolChanged',
    live.LearningCapabilityStateDto.accessDenied => 'accessDenied',
  };
  final d = r.data!;
  return LearningCapabilities(
    columns: state(d.columns),
    announcements: state(d.announcements),
    resources: state(d.resources),
    assessments: state(d.assessments),
    resourceDownload: state(d.resourceDownload),
    announcementDownload: state(d.announcementDownload),
  );
}

mixin NativeLearning
    implements
        LearningCourseGateway,
        CourseAnnouncementGateway,
        CourseResourceGateway,
        CourseAssessmentGateway,
        CourseLearningContextGateway {
  String? get _owner => expectedAccount;

  String? get expectedAccount;

  @override
  Future<LearningRead<List<LearningCourse>>> learningCourses({
    bool forceRefresh = false,
  }) async {
    final r = await learningSnapshots.read(
      _owner!,
      () => boundedNativeRead(
        () =>
            live.learningCourses(expectedAccount: _owner!, force: forceRefresh),
      ),
      (r) => r.failure,
    );
    return _read(failure: r.failure, data: r.data == null ? null : _courses(r));
  }

  @override
  Future<LearningRead<List<CourseAnnouncement>>> courseAnnouncements(
    String course, {
    bool forceRefresh = false,
  }) async {
    final r = await learningSnapshots.read(
      _owner!,
      () => boundedNativeRead(
        () => live.courseAnnouncements(
          expectedAccount: _owner!,
          course: course,
          force: forceRefresh,
        ),
      ),
      (r) => r.failure,
    );
    return _read(
      failure: r.failure,
      data: r.data == null ? null : _announcements(r),
    );
  }

  @override
  Future<CourseAnnouncementDetail> courseAnnouncementDetail(
    String course,
    String id,
  ) async => _detail(
    await boundedNativeRead(
      () => live.courseAnnouncementDetail(
        expectedAccount: _owner!,
        course: course,
        id: id,
      ),
    ),
  );

  @override
  Future<LearningRead<CourseResourcePage>> courseResources(
    String course, {
    String? folder,
    int page = 1,
    bool forceRefresh = false,
  }) async {
    final r = await learningSnapshots.read(
      _owner!,
      () => boundedNativeRead(
        () => live.courseResources(
          expectedAccount: _owner!,
          course: course,
          folder: folder,
          page: page,
          force: forceRefresh,
        ),
      ),
      (r) => r.failure,
    );
    return _read(
      failure: r.failure,
      data: r.data == null ? null : _resources(r),
    );
  }

  @override
  Future<LearningRead<List<CourseAssessment>>> courseAssessments(
    String course, {
    bool forceRefresh = false,
  }) async {
    final r = await learningSnapshots.read(
      _owner!,
      () => boundedNativeRead(
        () => live.courseAssessments(
          expectedAccount: _owner!,
          course: course,
          force: forceRefresh,
        ),
      ),
      (r) => r.failure,
    );
    return _read(
      failure: r.failure,
      data: r.data == null ? null : _assessments(r),
    );
  }

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
    await boundedNativeWrite(
      () => live.courseResourceDownload(
        expectedAccount: _owner!,
        course: course,
        folder: folder,
        page: page,
        id: id,
      ),
    ),
  );

  @override
  Future<LearningDownload> courseAnnouncementAttachment(
    String course,
    String id,
    String file,
  ) async => _download(
    await boundedNativeWrite(
      () => live.courseAnnouncementAttachment(
        expectedAccount: _owner!,
        course: course,
        id: id,
        file: file,
      ),
    ),
  );

  @override
  Future<LearningRead<List<LearningColumn>>> learningColumns(
    String course, {
    bool forceRefresh = false,
  }) async {
    final r = await learningSnapshots.read(
      _owner!,
      () => boundedNativeRead(
        () => live.courseLearningColumns(
          expectedAccount: _owner!,
          course: course,
          force: forceRefresh,
        ),
      ),
      (r) => r.failure,
    );
    return _read(failure: r.failure, data: r.data == null ? null : _columns(r));
  }

  @override
  Future<LearningCapabilities> learningCapabilities(String course) async =>
      _capabilities(
        await boundedNativeRead(
          () => live.courseLearningCapabilities(
            expectedAccount: _owner!,
            course: course,
          ),
        ),
      );

  @override
  Future<LearningRead<List<CourseAnnouncement>>> courseAnnouncementsIn(
    String course,
    String column, {
    bool forceRefresh = false,
  }) async {
    final r = await learningSnapshots.read(
      _owner!,
      () => boundedNativeRead(
        () => live.courseAnnouncementsIn(
          expectedAccount: _owner!,
          course: course,
          column: column,
          force: forceRefresh,
        ),
      ),
      (r) => r.failure,
    );
    return _read(
      failure: r.failure,
      data: r.data == null ? null : _announcements(r),
    );
  }

  @override
  Future<CourseAnnouncementDetail> courseAnnouncementDetailIn(
    String course,
    String column,
    String id,
  ) async => _detail(
    await boundedNativeRead(
      () => live.courseAnnouncementDetailIn(
        expectedAccount: _owner!,
        course: course,
        column: column,
        id: id,
      ),
    ),
  );

  @override
  Future<LearningRead<List<CourseAssessment>>> courseAssessmentsIn(
    String course,
    String column, {
    bool forceRefresh = false,
  }) async {
    final r = await learningSnapshots.read(
      _owner!,
      () => boundedNativeRead(
        () => live.courseAssessmentsIn(
          expectedAccount: _owner!,
          course: course,
          column: column,
          force: forceRefresh,
        ),
      ),
      (r) => r.failure,
    );
    return _read(
      failure: r.failure,
      data: r.data == null ? null : _assessments(r),
    );
  }

  @override
  Future<LearningRead<CourseResourcePage>> courseResourcesAt(
    String course, {
    List<String> path = const [],
    int page = 1,
    bool forceRefresh = false,
  }) async {
    final r = await learningSnapshots.read(
      _owner!,
      () => boundedNativeRead(
        () => live.courseResourcesAt(
          expectedAccount: _owner!,
          course: course,
          path: path,
          page: page,
          force: forceRefresh,
        ),
      ),
      (r) => r.failure,
    );
    return _read(
      failure: r.failure,
      data: r.data == null ? null : _resources(r),
    );
  }

  @override
  Future<LearningDownload> courseResourceDownloadAt(
    String course,
    String id, {
    List<String> path = const [],
    int page = 1,
  }) async => _download(
    await boundedNativeWrite(
      () => live.courseResourceDownloadAt(
        expectedAccount: _owner!,
        course: course,
        path: path,
        page: page,
        id: id,
      ),
    ),
  );

  @override
  Future<LearningDownload> courseAnnouncementAttachmentIn(
    String course,
    String column,
    String id,
    String file,
  ) async => _download(
    await boundedNativeWrite(
      () => live.courseAnnouncementAttachmentIn(
        expectedAccount: _owner!,
        course: course,
        column: column,
        id: id,
        file: file,
      ),
    ),
  );
}
