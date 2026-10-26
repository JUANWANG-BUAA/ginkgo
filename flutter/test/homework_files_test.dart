import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/homework_files_panel.dart';
import 'package:ginkgo_mirror/application/homework_files.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/infrastructure/demo_homework_files.dart';

class Files extends DemoHomeworkFiles {
  int uploads = 0, submits = 0, reconciles = 0;
  bool uncertain = false;
  bool pendingFails = false, capabilityFails = false, uploadFails = false;
  String? submitState;
  List<HomeworkPendingSubmission> pending = const [];
  List<HomeworkCapabilityEvidence>? capabilityOverride;
  Completer<HomeworkFileReceipt>? delayedUpload;
  Completer<MutationResponse>? delayedSubmit;
  @override
  Future<List<HomeworkPendingSubmission>> pendingHomeworkSubmissions({
    String? assignmentId,
  }) async {
    if (pendingFails) throw StateError('synthetic unavailable');
    return pending.where((p) => p.assignmentId == assignmentId).toList();
  }

  @override
  Future<List<HomeworkCapabilityEvidence>> homeworkCapabilities(
    String id,
  ) async {
    if (capabilityFails) throw StateError('synthetic unavailable');
    return capabilityOverride ?? super.homeworkCapabilities(id);
  }

  @override
  Future<HomeworkFileReceipt> uploadHomeworkFile(
    String id,
    String name,
    Uint8List bytes,
  ) async {
    uploads++;
    if (uploadFails) throw StateError('synthetic upload failed');
    if (delayedUpload != null) return delayedUpload!.future;
    return super.uploadHomeworkFile(id, name, bytes);
  }

  @override
  Future<MutationResponse> submitHomeworkFile(String handle) async {
    submits++;
    if (delayedSubmit != null) return delayedSubmit!.future;
    if (submitState != null) {
      return MutationResponse(state: submitState!, message: '合成结果');
    }
    return uncertain
        ? const MutationResponse(state: 'uncertain', message: '结果待核实')
        : super.submitHomeworkFile(handle);
  }

  @override
  Future<MutationResponse> reconcileHomeworkFile(String handle) async {
    reconciles++;
    return const MutationResponse(state: 'accepted', message: '回查已确认');
  }
}

Widget panel(
  Files files, {
  Future<XFile?> Function()? picker,
  Future<void> Function(HomeworkFileDownload)? saver,
  String assignmentId = 'fixture',
}) => CupertinoApp(
  home: CupertinoPageScaffold(
    child: SingleChildScrollView(
      child: HomeworkFilesPanel(
        assignmentId: assignmentId,
        title: '合成作业',
        course: '合成课程',
        gateway: files,
        pickFile:
            picker ??
            () => Future.value(
              XFile.fromData(Uint8List.fromList([0, 255]), path: 'answer.pdf'),
            ),
        saveFile: saver ?? (_) => Future.value(),
      ),
    ),
  ),
);
void main() {
  test('business workspace decoding rejects malformed data', () {
    expect(
      () => HomeworkFileWorkspace.fromJson({'assignmentId': 'a'}),
      throwsA(isA<TypeError>()),
    );
  });
  testWidgets(
    'upload is not submit; cancel and explicit confirm are distinct',
    (tester) async {
      final files = Files();
      await tester.pumpWidget(panel(files));
      await tester.pumpAndSettle();
      await tester.tap(find.text('选择并上传文件'));
      await tester.pumpAndSettle();
      expect(files.uploads, 1);
      expect(files.submits, 0);
      expect(find.text('文件已上传，尚未提交作业'), findsOneWidget);
      await tester.ensureVisible(find.text('提交作业'));
      await tester.tap(find.text('提交作业'));
      await tester.pumpAndSettle();
      expect(find.textContaining('answer.pdf').last, findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(files.submits, 0);
      await tester.tap(find.text('提交作业'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认提交'));
      await tester.pumpAndSettle();
      expect(files.submits, 1);
      expect(find.text('演示提交成功（未写入学校系统）'), findsOneWidget);
      expect(find.text('提交作业'), findsNothing);
    },
  );
  testWidgets('unknown submission has only a read reconciliation route', (
    tester,
  ) async {
    final files = Files()..uncertain = true;
    await tester.pumpWidget(panel(files));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择并上传文件'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('提交作业'));
    await tester.tap(find.text('提交作业'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认提交'));
    await tester.pumpAndSettle();
    expect(files.submits, 1);
    expect(find.text('提交作业'), findsNothing);
    await tester.ensureVisible(find.text('仅回查提交结果'));
    await tester.tap(find.text('仅回查提交结果'));
    await tester.pumpAndSettle();
    expect(files.reconciles, 1);
    expect(files.submits, 1);
  });
  testWidgets('cancel picker and rejected extension never upload', (
    tester,
  ) async {
    final files = Files();
    await tester.pumpWidget(panel(files, picker: () => Future.value(null)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择并上传文件'));
    await tester.pumpAndSettle();
    expect(files.uploads, 0);
    await tester.pumpWidget(
      panel(
        files,
        picker: () => Future.value(
          XFile.fromData(Uint8List.fromList([1]), path: 'a.exe'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择并上传文件'));
    await tester.pumpAndSettle();
    expect(files.uploads, 0);
    expect(find.text('不支持此文件格式'), findsOneWidget);
  });
  testWidgets('teacher attachment download is independent from submission', (
    tester,
  ) async {
    final files = Files();
    HomeworkFileDownload? saved;
    await tester.pumpWidget(
      panel(
        files,
        saver: (file) async {
          saved = file;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saved?.name, '合成作业要求.txt');
    expect(saved?.bytes, isNotEmpty);
    expect(files.submits, 0);
  });
  testWidgets('old picker cannot upload after gateway changes', (tester) async {
    final first = Files(), second = Files();
    final pick = Completer<XFile?>();
    await tester.pumpWidget(panel(first, picker: () => pick.future));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择并上传文件'));
    await tester.pump();
    await tester.pumpWidget(panel(second));
    await tester.pumpAndSettle();
    pick.complete(XFile.fromData(Uint8List.fromList([1]), path: 'answer.pdf'));
    await tester.pumpAndSettle();
    expect(first.uploads, 0);
    expect(second.uploads, 0);
  });
}
