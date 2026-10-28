import 'package:ginkgo_mirror/application/campus_activities.dart';
import 'package:ginkgo_mirror/application/graduate_credit_map.dart';
import 'package:ginkgo_mirror/application/learning.dart';
import 'package:ginkgo_mirror/application/learning_context.dart';
import 'package:ginkgo_mirror/application/library_loans.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/query_snapshots.dart';
import 'package:ginkgo_mirror/application/reminder_planning.dart';

/// Optional capabilities of the injected service, resolved once.
///
/// The composition root owns this matrix, so pages receive a typed port (or an
/// explicit `null`) instead of probing the service at runtime. A `null` is the
/// product state "this service does not offer that capability".
class ServiceCapabilities {
  const ServiceCapabilities({
    this.academic,
    this.careerEvents,
    this.campusActivities,
    this.courseAnnouncement,
    this.courseAssessment,
    this.courseLearningContext,
    this.courseResource,
    this.cgyyBooking,
    this.graduateCreditMap,
    this.learningCourse,
    this.learningSnapshots,
    this.libraryLoans,
    this.libraryLoansOfficial,
    this.campusCard,
    this.reminderPlanning,
    this.studentServiceLinks,
  });

  factory ServiceCapabilities.of(MirrorService service) => ServiceCapabilities(
    academic: service,
    careerEvents: service is CareerEventsGateway
        ? service as CareerEventsGateway
        : null,
    campusActivities: service is CampusActivitiesGateway
        ? service as CampusActivitiesGateway
        : null,
    courseAnnouncement: service is CourseAnnouncementGateway
        ? service as CourseAnnouncementGateway
        : null,
    courseAssessment: service is CourseAssessmentGateway
        ? service as CourseAssessmentGateway
        : null,
    courseLearningContext: service is CourseLearningContextGateway
        ? service as CourseLearningContextGateway
        : null,
    courseResource: service is CourseResourceGateway
        ? service as CourseResourceGateway
        : null,
    cgyyBooking: service is CgyyBookingGateway
        ? service as CgyyBookingGateway
        : null,
    graduateCreditMap: service is GraduateCreditMapGateway
        ? service as GraduateCreditMapGateway
        : null,
    learningCourse: service is LearningCourseGateway
        ? service as LearningCourseGateway
        : null,
    learningSnapshots: service is LearningSnapshotGateway
        ? service as LearningSnapshotGateway
        : null,
    libraryLoans: service is LibraryLoansGateway
        ? service as LibraryLoansGateway
        : null,
    libraryLoansOfficial: service is LibraryLoansOfficialGateway
        ? service as LibraryLoansOfficialGateway
        : null,
    campusCard: service is CampusCardGateway ? service as CampusCardGateway : null,
    reminderPlanning: service is ReminderPlanningGateway
        ? service as ReminderPlanningGateway
        : null,
    studentServiceLinks: service is StudentServiceLinksGateway
        ? service as StudentServiceLinksGateway
        : null,
  );

  /// The composition root resolves every optional capability exactly once, so
  /// no page has to probe the service at runtime.
  static ServiceCapabilities resolve(MirrorService service) =>
      ServiceCapabilities.of(service);

  final AcademicGateway? academic;
  final CareerEventsGateway? careerEvents;
  final CampusActivitiesGateway? campusActivities;
  final CourseAnnouncementGateway? courseAnnouncement;
  final CourseAssessmentGateway? courseAssessment;
  final CourseLearningContextGateway? courseLearningContext;
  final CourseResourceGateway? courseResource;
  final CgyyBookingGateway? cgyyBooking;
  final GraduateCreditMapGateway? graduateCreditMap;
  final LearningCourseGateway? learningCourse;
  final LearningSnapshotGateway? learningSnapshots;
  final LibraryLoansGateway? libraryLoans;
  final LibraryLoansOfficialGateway? libraryLoansOfficial;
  final CampusCardGateway? campusCard;
  final ReminderPlanningGateway? reminderPlanning;
  final StudentServiceLinksGateway? studentServiceLinks;
}
