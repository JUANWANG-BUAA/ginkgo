import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/infrastructure/native_learning.dart';

void main() {
  test(
    'failed learning collection keeps its typed failure without a snapshot',
    () {
      final read = projectLearningRead<List<LearningCourse>>(
        failure: FailureCode.captchaRequired,
        data: const [],
      );
      expect(read.data, isEmpty);
      expect(read.failure, FailureCode.captchaRequired);
      expect(read.stale, isTrue);
    },
  );
}
