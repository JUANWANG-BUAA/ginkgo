import 'package:ginkgo_mirror/application/failures.dart';

export 'package:ginkgo_mirror/application/failures.dart'
    show HomeworkDeadlineStatus;

/// The school rules the presentation layer needs. The domain owns them; a page
/// asks this port and never re-implements a rule.
abstract interface class SchoolRules {
  /// Classify a school deadline against the Beijing wall clock.
  HomeworkDeadlineStatus homeworkDeadline(String? dueAt, DateTime now);

  /// Whether a check-in session accepts a sign-in at `now`.
  bool checkinWindowOpen(
    String date,
    String beginsAt,
    String endsAt,
    DateTime now,
  );
}

/// The composition root installs the implementation: the app installs the
/// native one at startup, and the unit tests install the Dart double in
/// `flutter_test_config.dart`, which the shared rule tables pin against the
/// domain implementation.
late SchoolRules schoolRules;
