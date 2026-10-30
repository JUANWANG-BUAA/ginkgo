import 'dart:async';

import 'package:ginkgo_mirror/application/school_rules.dart';

import 'test/school_rules_double.dart';

/// The unit tests cannot load the native library, so the school rules are
/// installed from the Dart double. The shared rule tables in `fixtures/rules/`
/// pin that double against the domain implementation.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  schoolRules = const DartSchoolRules();
  await testMain();
}
