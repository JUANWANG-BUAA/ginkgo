import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/features/homework/homework_detail_page.dart';
import 'package:ginkgo_mirror/main.dart';

const assignment = HomeworkItem(
  id: 'spoc:123',
  title: '合成作业',
  courseName: '合成课程',
  dueAt: '2026-10-22T10:30:00Z',
  status: HomeworkStatus.pending,
);

Map<String, dynamic> record(
  String id, {
  String title = '个人修改标题',
  String due = '',
  bool completed = false,
  String? source,
}) => {
  'id': id,
  'title': title,
  'due': due,
  'completed': completed,
  if (source != null) 'source': {'kind': 'homework', 'assignment_id': source},
};

class TaskFake implements LocalTaskGateway, AcademicGateway {
  final rows = <Map<String, dynamic>>[];
  final calls = <String>[];
  final roots = <String>[];
  final detailIds = <String>[];
  bool corrupt = false;
  bool failSave = false;
  List<HomeworkItem> assignments = [assignment];
  Completer<ReadOnlyResponse>? pendingLoad;
  Completer<ReadOnlyResponse>? pendingSave;
  Completer<HomeworkDetailResponse>? pendingDetail;
  @override
  bool get isDemo => true;
  @override
  Future<ReadOnlyResponse> editTasks({
    required String root,
    required String action,
    String? id,
    String? title,
    String? due,
    bool? completed,
  }) async {
    calls.add(action);
    roots.add(root);
    if (action == 'load' && pendingLoad != null) return pendingLoad!.future;
    if (action != 'load' && pendingSave != null) return pendingSave!.future;
    if (action != 'load' && failSave) {
      return const ReadOnlyResponse(stale: false);
    }
    if (action == 'add_homework') {
      if (!rows.any((t) => (t['source'] as Map?)?['assignment_id'] == id)) {
        rows.add(record('local:linked', title: title!, due: due!, source: id));
      }
    } else if (action == 'add') {
      rows.add(record('local:new', title: title!, due: due!));
    } else if (action == 'update') {
      final row = rows.singleWhere((t) => t['id'] == id);
      row['title'] = title;
      row['due'] = due;
    } else if (action == 'toggle') {
      rows.singleWhere((t) => t['id'] == id)['completed'] = completed;
    } else if (action == 'delete') {
      rows.removeWhere((t) => t['id'] == id);
    }
    return ReadOnlyResponse(
      payload: corrupt ? '{}' : jsonEncode(rows),
      stale: false,
    );
  }

  @override
  Future<HomeworkResponse> homework({bool forceRefresh = false}) async =>
      HomeworkResponse(
        termName: '合成学期',
        termCode: 'synthetic',
        items: assignments,
      );
  @override
  Future<HomeworkDetailResponse> homeworkDetail(
    String assignmentId, {
    bool forceRefresh = false,
  }) async {
    detailIds.add(assignmentId);
    return pendingDetail?.future ??
        const HomeworkDetailResponse(
          status: '待完成',
          content: '合成正文',
          stale: false,
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected non-local action: ${invocation.memberName}');
}

class AcademicOnly implements AcademicGateway {
  @override
  bool get isDemo => true;
  @override
  Future<HomeworkDetailResponse> homeworkDetail(
    String assignmentId, {
    bool forceRefresh = false,
  }) async => const HomeworkDetailResponse(status: '待完成', stale: false);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> press(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  // Behaviour change (2026-10-23): assignments are no longer pushed into
  // personal to-dos, so the detail page must not offer that action at all.
  testWidgets('homework detail offers no add-to-my-tasks action', (
    tester,
  ) async {
    phone(tester);
    final fake = TaskFake();
    await tester.pumpWidget(
      ginkgoApp(
        home: HomeworkDetailPage(
          item: assignment,
          service: fake,
          storageRoot: '/synthetic/tasks',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('homework-add-task')), findsNothing);
    expect(find.textContaining('仅在本机记录'), findsNothing);
    // Reading the detail must not write anything locally.
    expect(fake.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
