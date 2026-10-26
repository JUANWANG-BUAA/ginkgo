import 'dart:typed_data';

/// Business values only. School fields and authentication stay in Rust.
class LearningCourse {
  const LearningCourse({
    required this.id,
    required this.name,
    required this.sourceUrl,
    this.teacher,
    this.term,
  });
  final String id, name, sourceUrl;
  final String? teacher, term;
}

class CourseAnnouncement {
  const CourseAnnouncement(this.id, this.title, this.publishedAt);
  final String id, title;
  final String? publishedAt;
}

class LearningAttachment {
  const LearningAttachment(this.id, this.name);
  final String id, name;
}

class CourseAnnouncementDetail {
  CourseAnnouncementDetail({
    required this.id,
    required this.title,
    required this.content,
    required List<LearningAttachment> attachments,
  }) : attachments = List.unmodifiable(attachments);
  final String id, title;
  final String? content;
  final List<LearningAttachment> attachments;
}

class CourseResource {
  const CourseResource({
    required this.id,
    required this.name,
    required this.folder,
    required this.downloadable,
    this.updatedAt,
    this.extension,
  });
  final String id, name;
  final bool folder, downloadable;
  final String? updatedAt, extension;
}

class CourseResourcePage {
  CourseResourcePage(List<CourseResource> items, this.page, this.hasNext)
    : items = List.unmodifiable(items);
  final List<CourseResource> items;
  final int page;
  final bool hasNext;
}

class CourseAssessment {
  const CourseAssessment({
    required this.id,
    required this.title,
    required this.sourceUrl,
    this.startsAt,
    this.dueAt,
    this.score,
  });
  final String id, title, sourceUrl;
  final String? startsAt, dueAt, score;
}

class LearningDownload {
  LearningDownload(this.name, Uint8List bytes)
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();
  final String name;
  final Uint8List bytes;
}
