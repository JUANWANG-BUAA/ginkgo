import 'dart:convert';

import '../application/career.dart';
import '../application/mirror_service.dart';
import '../application/contracts.dart';
import '../src/rust/api/live.dart' as live;

CareerEventsRead decodeCareerEvents(live.ReadOnlyResponse response) {
  if (response.failure != null) {
    return CareerEventsRead(failure: response.failure);
  }
  if (response.payload == null) {
    return const CareerEventsRead(failure: FailureCode.changedResponse);
  }
  try {
    return CareerEventsRead(
      data: CareerEvents.fromJson(
        jsonDecode(response.payload!) as Map<String, dynamic>,
      ),
    );
  } catch (_) {
    return const CareerEventsRead(failure: FailureCode.changedResponse);
  }
}

mixin NativeCareer implements CareerEventsGateway {
  @override
  Future<CareerEventsRead> careerEvents({
    required String month,
    bool forceRefresh = false,
  }) async => decodeCareerEvents(
    await live.loadCareerEvents(month: month, forceRefresh: forceRefresh),
  );
}
