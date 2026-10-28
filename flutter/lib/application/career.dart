import 'package:ginkgo_mirror/application/contracts.dart';

/// Public career activities. School status text is preserved verbatim.
class CareerEvent {
  const CareerEvent({
    required this.id,
    required this.title,
    required this.campus,
    required this.place,
    required this.beginsAt,
    required this.endsAt,
    required this.fairType,
    required this.status,
    required this.url,
  });

  final String id,
      title,
      campus,
      place,
      beginsAt,
      endsAt,
      fairType,
      status,
      url;
}

class CareerEvents {
  const CareerEvents({
    required this.month,
    required this.events,
    required this.fetchedAt,
  });

  final String month, fetchedAt;
  final List<CareerEvent> events;
}

class CareerEventsRead {
  const CareerEventsRead({this.data, this.failure});
  final CareerEvents? data;
  final FailureCode? failure;
}
