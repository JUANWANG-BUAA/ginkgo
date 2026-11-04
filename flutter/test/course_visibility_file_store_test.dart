import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/infrastructure/course_visibility_file_store.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ginkgo-course-range-');
  });
  tearDown(() => directory.delete(recursive: true));

  File legacyFile(String account) {
    final digest = sha256.convert(utf8.encode(account));
    return File('${directory.path}/course-visibility-$digest.json');
  }

  CourseVisibilityFileStore store(String account) => CourseVisibilityFileStore(
    account,
    supportDirectory: () async => directory,
  );

  test(
    'reads the legacy filename and filters invalid digest entries',
    () async {
      final digest = sha256
          .convert(utf8.encode('spoc:synthetic-course'))
          .toString();
      final file = legacyFile('synthetic-account');
      final original = jsonEncode([digest, 'not-a-digest', 42, digest]);
      await file.writeAsString(original);
      final controller = store('synthetic-account').createController();
      addTearDown(controller.dispose);
      await controller.restore();
      expect(controller.ready, isTrue);
      expect(controller.hidden('spoc', 'synthetic-course'), isTrue);
      expect(controller.hidden('iclass', 'synthetic-course'), isFalse);
      expect(await file.readAsString(), original);
    },
  );

  test('round trips atomically without touching another account', () async {
    final first = store('synthetic-first').createController();
    final second = store('synthetic-second').createController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await Future.wait([first.restore(), second.restore()]);
    await first.setHidden('spoc', 'synthetic-course', true);
    await second.setHidden('iclass', 'synthetic-other', true);
    final otherBytes = await legacyFile('synthetic-second').readAsString();
    final restored = store('synthetic-first').createController();
    addTearDown(restored.dispose);
    await restored.restore();
    expect(restored.hidden('spoc', 'synthetic-course'), isTrue);
    expect(restored.hidden('iclass', 'synthetic-other'), isFalse);
    await restored.setHidden('spoc', 'synthetic-course', false);
    expect(await store('synthetic-first').read(), isEmpty);
    expect(await legacyFile('synthetic-second').readAsString(), otherBytes);
    expect(
      await File('${legacyFile('synthetic-first').path}.tmp').exists(),
      isFalse,
    );
  });

  test(
    'failed restore leaves corrupt bytes untouched until explicit retry',
    () async {
      final file = legacyFile('synthetic-account');
      const original = '{"unexpected":"object"}';
      await file.writeAsString(original);
      final controller = store('synthetic-account').createController();
      addTearDown(controller.dispose);
      final restoring = controller.restore();
      final saving = controller.setHidden('spoc', 'synthetic-course', true);
      await Future.wait([restoring, saving]);
      expect(controller.loadFailed, isTrue);
      expect(await file.readAsString(), original);
      expect(await File('${file.path}.tmp').exists(), isFalse);
      await file.writeAsString('[]');
      await controller.retryRestore();
      expect(controller.ready, isTrue);
      await controller.setHidden('spoc', 'synthetic-course', true);
      expect(await store('synthetic-account').read(), hasLength(1));
    },
  );
}
