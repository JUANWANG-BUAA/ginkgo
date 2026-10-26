import 'dart:convert';
import 'dart:typed_data';

import '../application/contracts.dart';
import '../application/learning.dart';
import '../application/learning_context.dart';

/// Synthetic data only: no school requests, account, cache, or native runtime.
mixin DemoLearning
    implements
        LearningCourseGateway,
        CourseAnnouncementGateway,
        CourseResourceGateway,
        CourseAssessmentGateway,
        CourseLearningContextGateway {
  static const _course = 'demo-learning-course';
  void _checkCourse(String course) {
    if (course != _course) throw StateError('演示课程不存在');
  }

  @override
  Future<LearningRead<List<LearningCourse>>> learningCourses({
    bool forceRefresh = false,
  }) async => const LearningRead([
    LearningCourse(
      id: _course,
      name: '学习服务演示课程',
      teacher: '演示教师',
      term: '演示学期',
      sourceUrl: '',
    ),
  ]);

  @override
  Future<LearningRead<List<CourseAnnouncement>>> courseAnnouncements(
    String course, {
    bool forceRefresh = false,
  }) async {
    _checkCourse(course);
    return const LearningRead([
      CourseAnnouncement('demo-announcement', '课程学习说明（演示）', null),
    ]);
  }

  @override
  Future<CourseAnnouncementDetail> courseAnnouncementDetail(
    String course,
    String id,
  ) async {
    _checkCourse(course);
    if (id != 'demo-announcement') throw StateError('演示公告不存在');
    return CourseAnnouncementDetail(
      id: id,
      title: '课程学习说明（演示）',
      content: '此处是合成演示内容，读取不会标记学校公告已读。',
      attachments: const [LearningAttachment('demo-attachment', '说明.txt')],
    );
  }

  @override
  Future<LearningRead<CourseResourcePage>> courseResources(
    String course, {
    String? folder,
    int page = 1,
    bool forceRefresh = false,
  }) async {
    _checkCourse(course);
    if (page < 1 || (folder != null && folder != 'demo-folder')) {
      throw StateError('演示资料目录不存在');
    }
    return LearningRead(
      CourseResourcePage(
        page > 1
            ? []
            : folder == null
            ? const [
                CourseResource(
                  id: 'demo-folder',
                  name: '课程资料（演示）',
                  folder: true,
                  downloadable: false,
                ),
              ]
            : const [
                CourseResource(
                  id: 'demo-resource',
                  name: '学习说明.txt',
                  folder: false,
                  downloadable: true,
                  extension: 'txt',
                ),
              ],
        page,
        false,
      ),
    );
  }

  @override
  Future<LearningRead<List<CourseAssessment>>> courseAssessments(
    String course, {
    bool forceRefresh = false,
  }) async {
    _checkCourse(course);
    return const LearningRead([
      CourseAssessment(
        id: 'demo-assessment',
        title: '阶段测验（仅展示，演示）',
        sourceUrl: '',
      ),
    ]);
  }

  LearningDownload _file(String name) =>
      LearningDownload(name, Uint8List.fromList(utf8.encode('这是合成的学习服务演示附件。')));

  @override
  Future<LearningDownload> courseResourceDownload(
    String course,
    String id, {
    String? folder,
    int page = 1,
  }) async {
    _checkCourse(course);
    if (id != 'demo-resource' || folder != 'demo-folder' || page != 1) {
      throw StateError('演示资料不存在');
    }
    return _file('学习说明.txt');
  }

  @override
  Future<LearningDownload> courseAnnouncementAttachment(
    String course,
    String id,
    String file,
  ) async {
    _checkCourse(course);
    if (id != 'demo-announcement' || file != 'demo-attachment') {
      throw StateError('演示附件不存在');
    }
    return _file('说明.txt');
  }

  @override
  Future<LearningRead<List<LearningColumn>>> learningColumns(
    String course, {
    bool forceRefresh = false,
  }) async {
    _checkCourse(course);
    return const LearningRead([
      LearningColumn(
        id: 'demo-announcements',
        name: '课程公告（演示）',
        kind: 'announcement',
      ),
      LearningColumn(
        id: 'demo-assessments',
        name: '课程测验（演示）',
        kind: 'assessment',
      ),
    ]);
  }

  @override
  Future<LearningCapabilities> learningCapabilities(String course) async {
    _checkCourse(course);
    return const LearningCapabilities();
  }

  void _column(String column, String expected) {
    if (column != expected) throw StateError('演示栏目不存在');
  }

  @override
  Future<LearningRead<List<CourseAnnouncement>>> courseAnnouncementsIn(
    String course,
    String column, {
    bool forceRefresh = false,
  }) {
    _column(column, 'demo-announcements');
    return courseAnnouncements(course, forceRefresh: forceRefresh);
  }

  @override
  Future<CourseAnnouncementDetail> courseAnnouncementDetailIn(
    String course,
    String column,
    String id,
  ) {
    _column(column, 'demo-announcements');
    return courseAnnouncementDetail(course, id);
  }

  @override
  Future<LearningDownload> courseAnnouncementAttachmentIn(
    String course,
    String column,
    String id,
    String file,
  ) {
    _column(column, 'demo-announcements');
    return courseAnnouncementAttachment(course, id, file);
  }

  @override
  Future<LearningRead<List<CourseAssessment>>> courseAssessmentsIn(
    String course,
    String column, {
    bool forceRefresh = false,
  }) {
    _column(column, 'demo-assessments');
    return courseAssessments(course, forceRefresh: forceRefresh);
  }

  String? _folder(List<String> path) {
    if (path.isEmpty) return null;
    if (path.length == 1 && path.single == 'demo-folder') return path.single;
    throw StateError('演示不支持此目录路径，请返回上一级');
  }

  @override
  Future<LearningRead<CourseResourcePage>> courseResourcesAt(
    String course, {
    List<String> path = const [],
    int page = 1,
    bool forceRefresh = false,
  }) => courseResources(
    course,
    folder: _folder(path),
    page: page,
    forceRefresh: forceRefresh,
  );
  @override
  Future<LearningDownload> courseResourceDownloadAt(
    String course,
    String id, {
    List<String> path = const [],
    int page = 1,
  }) => courseResourceDownload(course, id, folder: _folder(path), page: page);
}
