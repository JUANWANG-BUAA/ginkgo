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

  factory CareerEvent.fromJson(Map<String, dynamic> json) => CareerEvent(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    campus: json['campus'] as String? ?? '',
    place: json['place'] as String? ?? '',
    beginsAt: json['beginsAt'] as String? ?? '',
    endsAt: json['endsAt'] as String? ?? '',
    fairType: json['fairType'] as String? ?? '',
    status: json['status'] as String? ?? '',
    url: json['url'] as String? ?? '',
  );

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

  factory CareerEvents.fromJson(Map<String, dynamic> json) => CareerEvents(
    month: json['month'] as String? ?? '',
    events: (json['events'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(CareerEvent.fromJson)
        .toList(growable: false),
    fetchedAt: json['fetchedAt'] as String? ?? '',
  );

  final String month, fetchedAt;
  final List<CareerEvent> events;
}

class CareerEventsRead {
  const CareerEventsRead({this.data, this.failure});
  final CareerEvents? data;
  final FailureCode? failure;
}
