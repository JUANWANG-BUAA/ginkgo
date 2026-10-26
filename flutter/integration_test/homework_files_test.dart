import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' as live;
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await RustLib.init();
  });
  testWidgets(
    'homework file FRB commands reject unbound accounts without network',
    (tester) async {
      final read = await live.homeworkFileWorkspace(
        expectedAccount: '__fixture__',
        assignmentId: 'fixture',
      );
      expect(read.failure, FailureCode.sessionExpired);
      expect(read.payload, isNull);
      final upload = await live.uploadHomeworkFile(
        expectedAccount: '__fixture__',
        assignmentId: 'fixture',
        name: 'fixture.pdf',
        bytes: Uint8List.fromList([0, 255, 13, 10]),
      );
      expect(upload.failure, FailureCode.sessionExpired);
      final submit = await live.submitHomeworkFile(
        expectedAccount: '__fixture__',
        handle: 'fixture',
        confirmed: true,
      );
      expect(submit.state, 'notSubmitted');
      final reconcile = await live.reconcileHomeworkFile(
        expectedAccount: '__fixture__',
        handle: 'fixture',
      );
      expect(reconcile.state, 'notSubmitted');
      final download = await live.downloadHomeworkFile(
        expectedAccount: '__fixture__',
        assignmentId: 'fixture',
        attachmentId: 'fixture',
      );
      expect(download.failure, FailureCode.sessionExpired);
      expect(download.bytes, isNull);
    },
  );
}
