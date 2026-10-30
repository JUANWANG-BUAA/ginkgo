import '../application/campus_activities.dart';
import '../application/contracts.dart';
import '../src/rust/api/live.dart' as live;

import 'package:ginkgo_mirror/infrastructure/native_command.dart';

CampusActivitiesRead decodeCampusActivities(
  live.CampusActivitiesResponse response,
) {
  final data = response.data;
  if (data == null) {
    return CampusActivitiesRead(
      failure: response.failure ?? FailureCode.changedResponse,
    );
  }
  return CampusActivitiesRead(
    data: CampusActivities(
      page: data.page,
      fetchedAt: data.fetchedAt,
      activities: List.unmodifiable(
        data.activities.map(
          (activity) => CampusActivity(
            id: activity.id,
            title: activity.title,
            category: activity.category,
            publishedAt: activity.publishedAt,
            activityTime: activity.activityTime,
            place: activity.place,
            url: activity.url,
          ),
        ),
      ),
    ),
    failure: response.failure,
  );
}

mixin NativeCampusActivities implements CampusActivitiesGateway {
  @override
  Future<CampusActivitiesRead> campusActivities({
    int page = 1,
    bool forceRefresh = false,
  }) async => decodeCampusActivities(
    await boundedNativeRead(
      () => live.loadCampusActivities(page: page, forceRefresh: forceRefresh),
    ),
  );
}
