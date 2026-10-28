import 'package:ginkgo_mirror/application/learning.dart';
import 'package:ginkgo_mirror/application/learning_context.dart';

/// The learning ports a service offers, resolved once.
///
/// A service may expose the context-aware ports, the plain per-course ports,
/// or both. Pages branch on which port is present instead of probing the
/// service themselves.
class LearningPorts {
  const LearningPorts({
    this.context,
    this.announcements,
    this.resources,
    this.assessments,
    this.courses,
  });

  factory LearningPorts.resolve(Object? service) => LearningPorts(
    context: service is CourseLearningContextGateway
        ? service
        : null,
    announcements: service is CourseAnnouncementGateway ? service : null,
    resources: service is CourseResourceGateway ? service : null,
    assessments: service is CourseAssessmentGateway ? service : null,
    courses: service is LearningCourseGateway ? service : null,
  );

  final CourseLearningContextGateway? context;
  final CourseAnnouncementGateway? announcements;
  final CourseResourceGateway? resources;
  final CourseAssessmentGateway? assessments;
  final LearningCourseGateway? courses;
}
