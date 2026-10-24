import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/course_visibility.dart';

void main() {
  test(
    'a failed read locks editing until an explicit retry succeeds',
    () async {
      var saved = <String>{};
      var shouldFail = true;
      final preferences = CourseVisibility(
        'fixture',
        load: () async {
          if (shouldFail) throw const FormatException('synthetic drift');
          return <String>{};
        },
        save: (value) async => saved = value,
      );
      await preferences.restore();
      expect(preferences.loadFailed, isTrue);
      expect(preferences.ready, isFalse);

      // While the read is failed, changes are refused and nothing is written,
      // so the stored range can never be overwritten by a partial set.
      await preferences.setHidden('iclass', 'course', true);
      expect(preferences.hidden('iclass', 'course'), isFalse);
      expect(saved, isEmpty);

      shouldFail = false;
      await preferences.retryRestore();
      expect(preferences.loadFailed, isFalse);
      expect(preferences.ready, isTrue);
      await preferences.setHidden('iclass', 'course', true);
      expect(preferences.hidden('iclass', 'course'), isTrue);
      expect(saved.single, matches(RegExp(r'^[a-f0-9]{64}$')));
      preferences.dispose();
    },
  );
  test(
    'a late disk restore keeps newer user choices and saves the merged range',
    () async {
      final stored = Completer<Set<String>>();
      Set<String> saved = {};
      final seed = CourseVisibility(
        'fixture',
        save: (value) async => saved = value,
      );
      await seed.setHidden('iclass', 'course', true);
      final previous = Set<String>.of(saved);
      seed.dispose();
      final preferences = CourseVisibility(
        'fixture',
        load: () => stored.future,
        save: (value) async => saved = value,
      );
      final restoring = preferences.restore();
      final saving = preferences.setHidden('iclass', 'course', false);
      stored.complete(previous);
      await Future.wait([restoring, saving]);
      expect(preferences.hidden('iclass', 'course'), isFalse);
      expect(saved, isEmpty);
      preferences.dispose();
    },
  );
  test(
    'course choices persist digests and stay isolated by system and account',
    () async {
      Set<String> saved = {};
      final first = CourseVisibility(
        'synthetic-account',
        save: (value) async {
          saved = value;
        },
      );
      final second = CourseVisibility(
        'other-synthetic-account',
        save: (_) async {},
      );
      await first.restore();
      await first.setHidden('iclass', 'synthetic-id', true);
      expect(first.hidden('iclass', 'synthetic-id'), isTrue);
      expect(first.hidden('spoc', 'synthetic-id'), isFalse);
      expect(second.hidden('iclass', 'synthetic-id'), isFalse);
      expect(saved.single, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(saved.single, isNot(contains('synthetic')));
      await first.setHidden('iclass', 'synthetic-id', false);
      expect(saved, isEmpty);
      first.dispose();
      second.dispose();
    },
  );
}
