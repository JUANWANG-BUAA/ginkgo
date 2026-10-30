import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/school_rules.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';

/// School wall-clock values are never interpreted in the device timezone.
DateTime? schoolInstant(String raw, {String? day}) {
  final text = RegExp(r'^\d{2}:\d{2}(:\d{2})?$').hasMatch(raw) && day != null
      ? '$day $raw'
      : raw;
  return parseSchoolTimestamp(text)?.subtract(const Duration(hours: 8));
}

/// Whether a check-in session accepts a sign-in right now.
///
/// The same domain rule guards the write in the upstream, so the button the
/// page offers and the submission the school accepts cannot disagree. The
/// shared rule table `fixtures/rules/checkin-window-v1.json` pins the
/// implementation against the shared expectations.
bool checkinWindowOpen(CheckInCourse course, String day, DateTime now) =>
    schoolRules.checkinWindowOpen(day, course.beginsAt, course.endsAt, now);
