import '../application/school_rules.dart';

import '../shared/today_time.dart';
import '../src/rust/api/rules.dart' as native;

/// The domain rules through the bridge. Pure commands, no session or network.
///
/// The port speaks the Beijing wall clock; the bridge takes absolute instants.
/// [schoolWallClockMillis] is the single place that converts between them.
class NativeSchoolRules implements SchoolRules {
  const NativeSchoolRules();

  @override
  HomeworkDeadlineStatus homeworkDeadline(String? dueAt, DateTime now) =>
      native.classifyHomeworkDeadline(
        dueAt: dueAt,
        nowMillis: schoolWallClockMillis(now),
      );

  @override
  bool checkinWindowOpen(
    String date,
    String beginsAt,
    String endsAt,
    DateTime now,
  ) => native.checkinSignInWindow(
    date: date,
    beginsAt: beginsAt,
    endsAt: endsAt,
    nowMillis: schoolWallClockMillis(now),
  );
}
