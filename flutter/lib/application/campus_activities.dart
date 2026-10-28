import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';

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

  factory CampusActivity.fromJson(Map<String, dynamic> json) => CampusActivity(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    category: json['category'] as String? ?? '',
    publishedAt: json['publishedAt'] as String? ?? '',
    activityTime: json['activityTime'] as String? ?? '',
    place: json['place'] as String? ?? '',
    url: json['url'] as String? ?? '',
  );

  final String id, title, category, publishedAt, activityTime, place, url;
}

class CampusActivities {
  const CampusActivities({
    required this.page,
    required this.activities,
    required this.fetchedAt,
  });

  factory CampusActivities.fromJson(Map<String, dynamic> json) =>
      CampusActivities(
        page: json['page'] as int? ?? 0,
        activities: (json['activities'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(CampusActivity.fromJson)
            .toList(growable: false),
        fetchedAt: json['fetchedAt'] as String? ?? '',
      );

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
