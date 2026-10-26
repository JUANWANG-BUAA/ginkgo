import 'package:ginkgo_mirror/application/contracts.dart';

/// Separate, read-only capabilities: implementing one never grants writes.
abstract interface class LearningCourseGateway {
  Future<LearningRead<List<LearningCourse>>> learningCourses({
    bool forceRefresh = false,
  });
}

abstract interface class CourseAnnouncementGateway {
  Future<LearningRead<List<CourseAnnouncement>>> courseAnnouncements(
    String course, {
    bool forceRefresh = false,
  });
  Future<CourseAnnouncementDetail> courseAnnouncementDetail(
    String course,
    String id,
  );
  Future<LearningDownload> courseAnnouncementAttachment(
    String course,
    String id,
    String file,
  );
}

abstract interface class CourseResourceGateway {
  Future<LearningRead<CourseResourcePage>> courseResources(
    String course, {
    String? folder,
    int page = 1,
    bool forceRefresh = false,
  });
  Future<LearningDownload> courseResourceDownload(
    String course,
    String id, {
    String? folder,
    int page = 1,
  });
}

abstract interface class CourseAssessmentGateway {
  Future<LearningRead<List<CourseAssessment>>> courseAssessments(
    String course, {
    bool forceRefresh = false,
  });
}

/// An old successful value and a refresh failure must travel together.
class LearningRead<T> {
  const LearningRead(this.data, {this.stale = false, this.failure});
  final T data;
  final bool stale;
  final FailureCode? failure;
}
