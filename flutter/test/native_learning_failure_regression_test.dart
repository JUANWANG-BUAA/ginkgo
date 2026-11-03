import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/infrastructure/native_mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

class _RefusedLearningApi extends Fake implements RustLibApi {
  FailureCode failure = FailureCode.captchaRequired;

  void check(String account) => expect(account, 'sy2501001');

  @override
  Future<LearningCoursesResponse> crateApiLiveLearningCourses({
    required String expectedAccount,
    required bool force,
  }) async {
    check(expectedAccount);
    return LearningCoursesResponse(failure: failure);
  }

  @override
  Future<CourseAnnouncementsResponse> crateApiLiveCourseAnnouncements({
    required String expectedAccount,
    required String course,
    required bool force,
  }) async {
    check(expectedAccount);
    return CourseAnnouncementsResponse(failure: failure);
  }

  @override
  Future<CourseResourcePageResponse> crateApiLiveCourseResources({
    required String expectedAccount,
    required String course,
    String? folder,
    required int page,
    required bool force,
  }) async {
    check(expectedAccount);
    return CourseResourcePageResponse(failure: failure);
  }

  @override
  Future<CourseAssessmentsResponse> crateApiLiveCourseAssessments({
    required String expectedAccount,
    required String course,
    required bool force,
  }) async {
    check(expectedAccount);
    return CourseAssessmentsResponse(failure: failure);
  }

  @override
  Future<LearningColumnsResponse> crateApiLiveCourseLearningColumns({
    required String expectedAccount,
    required String course,
    required bool force,
  }) async {
    check(expectedAccount);
    return LearningColumnsResponse(failure: failure);
  }
}

void main() {
  test(
    'native learning collections preserve upstream refusal without data',
    () async {
      final api = _RefusedLearningApi();
      RustLib.initMock(api: api);
      const service = NativeMirrorService(expectedAccount: 'sy2501001');
      for (final code in [
        FailureCode.captchaRequired,
        FailureCode.networkUnreachable,
        FailureCode.changedResponse,
        FailureCode.sessionExpired,
      ]) {
        api.failure = code;
        final courses = await service.learningCourses();
        expect(courses.failure, code);
        expect(courses.stale, isTrue);
        expect(courses.data, isEmpty);
        final announcements = await service.courseAnnouncements('synthetic');
        expect(announcements.failure, code);
        expect(announcements.data, isEmpty);
        final resources = await service.courseResources('synthetic');
        expect(resources.failure, code);
        expect(resources.data.items, isEmpty);
        final assessments = await service.courseAssessments('synthetic');
        expect(assessments.failure, code);
        expect(assessments.data, isEmpty);
        final columns = await service.learningColumns('synthetic');
        expect(columns.failure, code);
        expect(columns.data, isEmpty);
      }
    },
  );
}
