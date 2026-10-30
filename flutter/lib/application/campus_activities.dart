import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/environment.dart';

class CampusActivity {
  const CampusActivity({
    required this.id,
    required this.title,
    required this.category,
    required this.publishedAt,
    required this.activityTime,
    required this.place,
    required this.url,
  });

  final String id, title, category, publishedAt, activityTime, place, url;
}

class CampusActivities {
  const CampusActivities({
    required this.page,
    required this.activities,
    required this.fetchedAt,
  });

  final int page;
  final String fetchedAt;
  final List<CampusActivity> activities;
}

class CampusActivitiesRead {
  const CampusActivitiesRead({this.data, this.failure});
  final CampusActivities? data;
  final FailureCode? failure;
}

/// Public campus activities; no login, no writes and no background polling.
abstract interface class CampusActivitiesGateway implements MirrorEnvironment {
  Future<CampusActivitiesRead> campusActivities({int page, bool forceRefresh});
}
