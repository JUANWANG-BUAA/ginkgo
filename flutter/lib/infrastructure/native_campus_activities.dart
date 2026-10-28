import 'dart:convert';

import '../application/campus_activities.dart';
import '../application/contracts.dart';
import '../src/rust/api/live.dart' as live;

CampusActivitiesRead decodeCampusActivities(live.ReadOnlyResponse response) {
  if (response.failure != null) {
    return CampusActivitiesRead(failure: response.failure);
  }
  if (response.payload == null) {
    return const CampusActivitiesRead(failure: FailureCode.changedResponse);
  }
  try {
    return CampusActivitiesRead(
      data: CampusActivities.fromJson(
        jsonDecode(response.payload!) as Map<String, dynamic>,
      ),
    );
  } catch (_) {
    return const CampusActivitiesRead(failure: FailureCode.changedResponse);
  }
}

mixin NativeCampusActivities implements CampusActivitiesGateway {
  @override
  Future<CampusActivitiesRead> campusActivities({
    int page = 1,
    bool forceRefresh = false,
  }) async => decodeCampusActivities(
    await live.loadCampusActivities(page: page, forceRefresh: forceRefresh),
  );
}
