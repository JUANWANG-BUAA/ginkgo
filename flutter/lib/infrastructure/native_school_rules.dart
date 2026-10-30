import '../application/school_rules.dart';

import '../src/rust/api/rules.dart' as native;

/// The domain rules through the bridge. Pure commands, no session or network.
class NativeSchoolRules implements SchoolRules {
  const NativeSchoolRules();

  @override
  HomeworkDeadlineStatus homeworkDeadline(String? dueAt, DateTime now) =>
      native.classifyHomeworkDeadline(
        dueAt: dueAt,
        nowMillis: now.toUtc().millisecondsSinceEpoch,
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
    nowMillis: now.toUtc().millisecondsSinceEpoch,
  );
}
