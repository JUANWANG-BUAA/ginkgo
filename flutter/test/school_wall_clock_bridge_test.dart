import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/school_rules.dart';
import 'package:ginkgo_mirror/infrastructure/native_school_rules.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

void main() {
  final library = Platform.environment['GINKGO_HOST_BRIDGE'];
  test(
    'native rules interpret the Beijing wall clock once',
    () async {
      await RustLib.init(externalLibrary: ExternalLibrary.open(library!));
      const rules = NativeSchoolRules();
      final wall = DateTime.utc(2026, 11, 1, 23, 20);
      expect(
        rules.homeworkDeadline('2026-11-02 00:00:00', wall),
        HomeworkDeadlineStatus.active,
      );
      expect(
        rules.checkinWindowOpen('2026-11-01', '23:25', '23:55', wall),
        isTrue,
      );
      expect(
        rules.checkinWindowOpen(
          '2026-11-01',
          '23:25',
          '23:55',
          DateTime.utc(2026, 11, 1, 23, 55),
        ),
        isFalse,
      );
    },
    skip: library == null
        ? 'Requires an explicitly built local host bridge'
        : false,
  );
}
