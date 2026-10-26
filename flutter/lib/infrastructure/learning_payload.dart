import 'dart:convert';

import '../application/contracts.dart';
import '../application/learning.dart';

/// Decode Rust's business JSON, never an upstream school envelope.
/// Preserve failure metadata when Rust falls back to a previous success.
LearningRead<T> decodeLearningRead<T>(
  ReadOnlyResponse response,
  T Function(Object) decode,
) {
  if (response.payload == null ||
      (response.failure != null && !response.stale)) {
    throw StateError('学习服务读取失败，请重试或前往官网');
  }
  final Object? payload = jsonDecode(response.payload!);
  if (payload == null) throw const FormatException('学习数据为空');
  return LearningRead(
    decode(payload),
    stale: response.stale,
    failure: response.failure,
  );
}

List<LearningCourse> decodeCourses(Object value) => List.unmodifiable(
  (value as List).map((x) {
    final j = x as Map<String, dynamic>;
    return LearningCourse(
      id: j['id'] as String,
      name: j['name'] as String,
      teacher: j['teacher'] as String?,
      term: j['term'] as String?,
      sourceUrl: j['sourceUrl'] as String,
    );
  }),
);

List<CourseAnnouncement> decodeAnnouncements(Object value) => List.unmodifiable(
  (value as List).map((x) {
    final j = x as Map<String, dynamic>;
    return CourseAnnouncement(
      j['id'] as String,
      j['title'] as String,
      j['publishedAt'] as String?,
    );
  }),
);

CourseAnnouncementDetail decodeAnnouncement(Object value) {
  final j = value as Map<String, dynamic>;
  return CourseAnnouncementDetail(
    id: j['id'] as String,
    title: j['title'] as String,
    content: j['content'] as String?,
    attachments: (j['attachments'] as List).map((x) {
      final a = x as Map<String, dynamic>;
      return LearningAttachment(a['id'] as String, a['name'] as String);
    }).toList(),
  );
}

CourseResourcePage decodeResources(Object value) {
  final j = value as Map<String, dynamic>;
  final page = j['page'] as int;
  if (page < 1) throw const FormatException('学习资料页码无效');
  return CourseResourcePage(
    (j['items'] as List).map((x) {
      final a = x as Map<String, dynamic>;
      final folder = a['folder'] as bool;
      final downloadable = a['downloadable'] as bool;
      if (folder && downloadable) {
        throw const FormatException('资料目录不能当作文件下载');
      }
      return CourseResource(
        id: a['id'] as String,
        name: a['name'] as String,
        folder: folder,
        downloadable: downloadable,
        updatedAt: a['updatedAt'] as String?,
        extension: a['extension'] as String?,
      );
    }).toList(),
    page,
    j['hasNext'] as bool,
  );
}

List<CourseAssessment> decodeAssessments(Object value) => List.unmodifiable(
  (value as List).map((x) {
    final j = x as Map<String, dynamic>;
    return CourseAssessment(
      id: j['id'] as String,
      title: j['title'] as String,
      startsAt: j['startsAt'] as String?,
      dueAt: j['dueAt'] as String?,
      score: j['score'] as String?,
      sourceUrl: j['sourceUrl'] as String,
    );
  }),
);

List<LearningColumn> decodeLearningColumns(Object value) {
  final ids = <String>{};
  return List.unmodifiable(
    (value as List).map((x) {
      final j = x as Map<String, dynamic>;
      final id = j['id'] as String, kind = j['kind'] as String;
      if (id.isEmpty ||
          !ids.add(id) ||
          !{'announcement', 'assessment'}.contains(kind)) {
        throw const FormatException('课程栏目身份或类型无效');
      }
      return LearningColumn(id: id, name: j['name'] as String, kind: kind);
    }),
  );
}

LearningCapabilities decodeLearningCapabilities(Object value) {
  final j = value as Map<String, dynamic>;
  String state(String key) {
    final v = j[key] as String;
    if (!{
      'unknown',
      'available',
      'authRequired',
      'temporarilyUnavailable',
      'protocolChanged',
      'accessDenied',
    }.contains(v)) {
      throw const FormatException('学习能力状态无效');
    }
    return v;
  }

  return LearningCapabilities(
    columns: state('columns'),
    announcements: state('announcements'),
    resources: state('resources'),
    assessments: state('assessments'),
    resourceDownload: state('resourceDownload'),
    announcementDownload: state('announcementDownload'),
  );
}
