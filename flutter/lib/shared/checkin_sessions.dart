import 'package:ginkgo_mirror/application/contracts.dart';

String checkinSessionKey(CheckInCourse course) => course.id;

List<CheckInCourse> uniqueCheckinSessions(Iterable<CheckInCourse> courses) {
  final seen = <String>{};
  return [
    for (final course in courses)
      if (seen.add(checkinSessionKey(course))) course,
  ];
}
