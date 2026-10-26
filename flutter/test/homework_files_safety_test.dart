import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/homework_files.dart';

import 'homework_files_test.dart' as fixture;

Future<void> upload(WidgetTester tester) async {
  await tester.ensureVisible(find.text('选择并上传文件'));
  await tester.tap(find.text('选择并上传文件'));
  await tester.pumpAndSettle();
}

Future<void> confirm(WidgetTester tester) async {
  await tester.ensureVisible(find.text('提交作业'));
  await tester.tap(find.text('提交作业'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('确认提交'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('reopened page restores pending as read-only', (tester) async {
    final files = fixture.Files()
      ..pending = const [HomeworkPendingSubmission('sent', 'fixture')];
    await tester.pumpWidget(fixture.panel(files));
    await tester.pumpAndSettle();
    expect(find.text('回查待确认提交 1'), findsOneWidget);
    await upload(tester);
    expect(files.uploads, 0);
    await tester.ensureVisible(find.text('回查待确认提交 1'));
    await tester.tap(find.text('回查待确认提交 1'));
    await tester.pumpAndSettle();
    expect(files.reconciles, 1);
    expect(files.submits, 0);
    expect(find.text('回查已确认'), findsOneWidget);
  });

  testWidgets(
    'pending read failure blocks writes not downloads; retry recovers',
    (tester) async {
      final files = fixture.Files()..pendingFails = true;
      var saved = 0;
      await tester.pumpWidget(
        fixture.panel(
          files,
          saver: (_) async {
            saved++;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('未能核对本机待确认'), findsOneWidget);
      await upload(tester);
      expect(files.uploads, 0);
      await tester.ensureVisible(find.text('保存'));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(saved, 1);
      files.pendingFails = false;
      await tester.ensureVisible(find.text('刷新'));
      await tester.tap(find.text('刷新'));
      await tester.pumpAndSettle();
      await upload(tester);
      expect(files.uploads, 1);
    },
  );

  testWidgets(
    'unknown file capability blocks upload; unsupported text does not',
    (tester) async {
      final files = fixture.Files()..capabilityFails = true;
      await tester.pumpWidget(fixture.panel(files));
      await tester.pumpAndSettle();
      expect(find.textContaining('提交能力状态尚未确认'), findsOneWidget);
      await upload(tester);
      expect(files.uploads, 0);
      files.capabilityFails = false;
      await tester.ensureVisible(find.text('刷新'));
      await tester.tap(find.text('刷新'));
      await tester.pumpAndSettle();
      // This file-only task does not need unrelated text-submit diagnostics.
      expect(find.textContaining('textSubmit'), findsNothing);
      expect(find.textContaining('文本作答尚未接入'), findsNothing);
      await upload(tester);
      expect(files.uploads, 1);
    },
  );

  testWidgets('protocol changed capability warns and disables file action', (
    tester,
  ) async {
    final files = fixture.Files()
      ..capabilityOverride = const [
        HomeworkCapabilityEvidence(
          capability: 'fileSubmit',
          state: 'protocolChanged',
          reason: '合成协议变化',
          evidence: 'synthetic',
        ),
      ];
    await tester.pumpWidget(fixture.panel(files));
    await tester.pumpAndSettle();
    expect(find.textContaining('学校协议已变化'), findsOneWidget);
    await upload(tester);
    expect(files.uploads, 0);
  });

  testWidgets(
    'late upload from old assignment cannot appear in new assignment',
    (tester) async {
      final files = fixture.Files()
        ..delayedUpload = Completer<HomeworkFileReceipt>();
      await tester.pumpWidget(fixture.panel(files));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('选择并上传文件'));
      await tester.tap(find.text('选择并上传文件'));
      await tester.pump();
      await tester.pumpWidget(fixture.panel(files, assignmentId: 'other'));
      await tester.pumpAndSettle();
      files.delayedUpload!.complete(
        const HomeworkFileReceipt('old', 'old.pdf', 2),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('old.pdf'), findsNothing);
      expect(find.text('提交作业'), findsNothing);
    },
  );

  testWidgets('old confirmation cannot submit after gateway changes', (
    tester,
  ) async {
    final first = fixture.Files(), second = fixture.Files();
    await tester.pumpWidget(fixture.panel(first));
    await tester.pumpAndSettle();
    await upload(tester);
    await tester.ensureVisible(find.text('提交作业'));
    await tester.tap(find.text('提交作业'));
    await tester.pumpAndSettle();
    expect(find.textContaining('最终文件：answer.pdf'), findsOneWidget);
    expect(find.textContaining('课程：合成课程'), findsOneWidget);
    await tester.pumpWidget(fixture.panel(second));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认提交'));
    await tester.pumpAndSettle();
    expect(first.submits, 0);
    expect(second.submits, 0);
  });

  testWidgets('unknown future result state permits only reconciliation', (
    tester,
  ) async {
    final files = fixture.Files()..submitState = 'futureUnknown';
    await tester.pumpWidget(fixture.panel(files));
    await tester.pumpAndSettle();
    await upload(tester);
    await confirm(tester);
    expect(files.submits, 1);
    expect(find.text('提交作业'), findsNothing);
    expect(find.text('仅回查提交结果'), findsOneWidget);
  });

  testWidgets('definitive rejection consumes receipt and exposes failure', (
    tester,
  ) async {
    final files = fixture.Files()..submitState = 'rejected';
    await tester.pumpWidget(fixture.panel(files));
    await tester.pumpAndSettle();
    await upload(tester);
    await confirm(tester);
    expect(find.text('合成结果'), findsOneWidget);
    expect(find.text('提交作业'), findsNothing);
    expect(files.submits, 1);
  });

  testWidgets('upload failure is visible and never becomes receipt', (
    tester,
  ) async {
    final files = fixture.Files()..uploadFails = true;
    await tester.pumpWidget(fixture.panel(files));
    await tester.pumpAndSettle();
    await upload(tester);
    expect(find.textContaining('上传未完成，作业尚未提交'), findsOneWidget);
    expect(find.text('提交作业'), findsNothing);
    expect(files.submits, 0);
  });

  testWidgets('late submit result does not mark new owner accepted', (
    tester,
  ) async {
    final first = fixture.Files()
      ..delayedSubmit = Completer<MutationResponse>();
    final second = fixture.Files();
    await tester.pumpWidget(fixture.panel(first));
    await tester.pumpAndSettle();
    await upload(tester);
    await tester.ensureVisible(find.text('提交作业'));
    await tester.tap(find.text('提交作业'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认提交'));
    await tester.pump();
    await tester.pumpWidget(fixture.panel(second));
    await tester.pumpAndSettle();
    first.delayedSubmit!.complete(
      const MutationResponse(state: 'accepted', message: '旧账号成功'),
    );
    await tester.pumpAndSettle();
    expect(find.text('旧账号成功'), findsNothing);
    await upload(tester);
    expect(second.uploads, 1);
  });
}
