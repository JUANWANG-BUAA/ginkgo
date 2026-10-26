import 'package:ginkgo_mirror/application/learning.dart';
import 'package:ginkgo_mirror/application/learning_models.dart';

/// Explicit, server-validated navigation contexts. No school URLs or tokens.
abstract interface class CourseLearningContextGateway {
  Future<LearningRead<List<LearningColumn>>> learningColumns(
    String course, {
    bool forceRefresh = false,
  });
  Future<LearningCapabilities> learningCapabilities(String course);
  Future<LearningRead<List<CourseAnnouncement>>> courseAnnouncementsIn(
    String course,
    String column, {
    bool forceRefresh = false,
  });
  Future<CourseAnnouncementDetail> courseAnnouncementDetailIn(
    String course,
    String column,
    String id,
  );
  Future<LearningDownload> courseAnnouncementAttachmentIn(
    String course,
    String column,
    String id,
    String file,
  );
  Future<LearningRead<List<CourseAssessment>>> courseAssessmentsIn(
    String course,
    String column, {
    bool forceRefresh = false,
  });
  Future<LearningRead<CourseResourcePage>> courseResourcesAt(
    String course, {
    List<String> path = const [],
    int page = 1,
    bool forceRefresh = false,
  });
  Future<LearningDownload> courseResourceDownloadAt(
    String course,
    String id, {
    List<String> path = const [],
    int page = 1,
  });
}

class LearningColumn {
  const LearningColumn({
    required this.id,
    required this.name,
    required this.kind,
  });
  final String id, name, kind;
}

/// Observations of this session, never an instruction to probe an endpoint.
class LearningCapabilities {
  const LearningCapabilities({
    this.columns = 'unknown',
    this.announcements = 'unknown',
    this.resources = 'unknown',
    this.assessments = 'unknown',
    this.resourceDownload = 'unknown',
    this.announcementDownload = 'unknown',
  });
  final String columns,
      announcements,
      resources,
      assessments,
      resourceDownload,
      announcementDownload;
}
