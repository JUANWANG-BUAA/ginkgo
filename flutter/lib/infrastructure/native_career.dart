import '../application/career.dart';
import '../application/mirror_service.dart';
import '../application/contracts.dart';
import '../application/service_health.dart';
import '../src/rust/api/live.dart' as live;

import 'package:ginkgo_mirror/infrastructure/native_command.dart';

CareerEventsRead decodeCareerEvents(live.CareerEventsResponse response) {
  final data = response.data;
  if (data == null) {
    return CareerEventsRead(
      failure: response.failure ?? FailureCode.changedResponse,
    );
  }
  return CareerEventsRead(
    data: CareerEvents(
      month: data.month,
      fetchedAt: data.fetchedAt,
      events: List.unmodifiable(
        data.events.map(
          (event) => CareerEvent(
            id: event.id,
            title: event.title,
            campus: event.campus,
            place: event.place,
            beginsAt: event.beginsAt,
            endsAt: event.endsAt,
            fairType: event.fairType,
            status: event.status,
            url: event.url,
          ),
        ),
      ),
    ),
    failure: response.failure,
  );
}

mixin NativeCareer implements CareerEventsGateway {
  @override
  Future<CareerEventsRead> careerEvents({
    required String month,
    bool forceRefresh = false,
  }) => ServiceHealthTracker.shared.observe(
    ServiceEndpointId.careerEvents,
    () async => decodeCareerEvents(
      await boundedNativeRead(
        () => live.loadCareerEvents(month: month, forceRefresh: forceRefresh),
      ),
    ),
    failureOf: (r) => r.failure,
    staleOf: (r) => r.failure != null && r.data != null,
  );
}
