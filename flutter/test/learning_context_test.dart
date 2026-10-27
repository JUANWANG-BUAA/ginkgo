import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/learning.dart';
import 'package:ginkgo_mirror/application/learning_context.dart';
import 'package:ginkgo_mirror/application/learning_file_actions.dart';
import 'package:ginkgo_mirror/features/learning/learning_course_page.dart';
import 'package:ginkgo_mirror/infrastructure/learning_payload.dart';

const course = LearningCourse(id: 'course', name: '合成课程', sourceUrl: '');
const folder = CourseResource(
  id: 'folder',
  name: '第一章',
  folder: true,
  downloadable: false,
);
const file = CourseResource(
  id: 'file',
  name: '说明.txt',
  folder: false,
  downloadable: true,
);

class ContextFake
    implements CourseLearningContextGateway, LearningCourseGateway {
  final requestedColumns = <String>[];
  final requestedPaths = <String>[];
  final requestedPages = <int>[];
  final downloads = <Completer<LearningDownload>>[];
  final resourceReads = <Completer<LearningRead<CourseResourcePage>>>[];
  bool deferredResources = false;
  List<LearningColumn> columnRows = const [
    LearningColumn(id: 'a', name: '公告甲', kind: 'announcement'),
    LearningColumn(id: 'b', name: '公告乙', kind: 'announcement'),
    LearningColumn(id: 't', name: '测验栏', kind: 'assessment'),
  ];
  @override
  Future<LearningRead<List<LearningCourse>>> learningCourses({
    bool forceRefresh = false,
  }) async => const LearningRead([course]);
  @override
  Future<LearningRead<List<LearningColumn>>> learningColumns(
    String course, {
    bool forceRefresh = false,
  }) async => LearningRead(columnRows);
  @override
  Future<LearningCapabilities> learningCapabilities(String course) async =>
      const LearningCapabilities();
  @override
  Future<LearningRead<List<CourseAnnouncement>>> courseAnnouncementsIn(
    String course,
    String column, {
    bool forceRefresh = false,
  }) async {
    requestedColumns.add(column);
    return LearningRead([CourseAnnouncement(column, '公告正文$column', null)]);
  }

  @override
  Future<CourseAnnouncementDetail> courseAnnouncementDetailIn(
    String course,
    String column,
    String id,
  ) async => CourseAnnouncementDetail(
    id: id,
    title: '公告详情',
    content: '纯文本',
    attachments: const [LearningAttachment('attachment', '附件.txt')],
  );
  @override
  Future<LearningDownload> courseAnnouncementAttachmentIn(
    String course,
    String column,
    String id,
    String file,
  ) => courseResourceDownloadAt(course, file);
  @override
  Future<LearningRead<List<CourseAssessment>>> courseAssessmentsIn(
    String course,
    String column, {
    bool forceRefresh = false,
  }) async => const LearningRead([
    CourseAssessment(id: 'test', title: '只读测验', sourceUrl: ''),
  ]);
  @override
  Future<LearningRead<CourseResourcePage>> courseResourcesAt(
    String course, {
    List<String> path = const [],
    int page = 1,
    bool forceRefresh = false,
  }) async {
    requestedPaths.add(path.join('/'));
    requestedPages.add(page);
    if (deferredResources) {
      final c = Completer<LearningRead<CourseResourcePage>>();
      resourceReads.add(c);
      return c.future;
    }
    return LearningRead(
      CourseResourcePage(
        path.isEmpty && page == 1
            ? [folder, file]
            : path.isEmpty
            ? []
            : [file],
        page,
        path.isEmpty && page == 1,
      ),
    );
  }

  @override
  Future<LearningDownload> courseResourceDownloadAt(
    String course,
    String id, {
    List<String> path = const [],
    int page = 1,
  }) {
    final c = Completer<LearningDownload>();
    downloads.add(c);
    return c.future;
  }
}

Future<void> show(
  WidgetTester t,
  ContextFake fake, {
  LearningFileSaver? saver,
  String account = 'a',
}) async {
  t.view.physicalSize = const Size(600, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    CupertinoApp(
      home: LearningCoursePage(
        course: course,
        service: fake,
        accountId: account,
        saveFile: saver,
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, Finder f, {bool settle = true}) async {
  await t.ensureVisible(f);
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump(const Duration(milliseconds: 300));
  }
  await t.tap(f);
  if (settle) {
    await t.pumpAndSettle();
  } else {
    // An intentionally pending request keeps the loading ticker alive.
    await t.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  test('columns reject duplicate IDs and unknown states', () {
    expect(
      () => decodeLearningColumns([
        {'id': 'a', 'name': '甲', 'kind': 'announcement'},
        {'id': 'a', 'name': '乙', 'kind': 'assessment'},
      ]),
      throwsFormatException,
    );
    expect(
      () => decodeLearningCapabilities({'columns': 'fake'}),
      throwsFormatException,
    );
  });
  testWidgets(
    'multiple columns require explicit selection while assessment loads independently',
    (t) async {
      final f = ContextFake();
      await show(t, f);
      expect(f.requestedColumns, isEmpty);
      expect(find.text('请选择公告栏目（不自动使用第一项）'), findsOneWidget);
      expect(find.text('只读测验'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('learning-column-b')));
      expect(f.requestedColumns, ['b']);
      expect(find.text('公告正文b'), findsOneWidget);
      expect(find.text('公告正文a'), findsNothing);
    },
  );
  testWidgets(
    'directory and pagination carry explicit contexts and search stays local',
    (t) async {
      final f = ContextFake();
      await show(t, f);
      await tap(t, find.byKey(const Key('learning-next-page')));
      expect(f.requestedPages, [1, 2]);
      expect(find.text('暂无资料'), findsOneWidget);
      await tap(t, find.byKey(const Key('learning-previous-page')));
      await tap(t, find.byKey(const ValueKey('learning-resource-folder')));
      expect(f.requestedPaths.last, 'folder');
      await tap(t, find.byKey(const Key('learning-parent')));
      expect(f.requestedPaths.last, '');
      final before = f.requestedPaths.length;
      await t.enterText(find.byType(CupertinoSearchTextField), '不存在');
      await t.pumpAndSettle();
      expect(find.text('当前页没有匹配资料'), findsOneWidget);
      expect(f.requestedPaths.length, before);
    },
  );
  testWidgets(
    'late download after account replacement never opens local saver',
    (t) async {
      final f = ContextFake();
      var saves = 0;
      Future<LearningSavedFile?> saver(
        LearningDownload file,
        bool Function() current,
      ) async {
        saves++;
        return null;
      }

      await show(t, f, saver: saver);
      await tap(t, find.byKey(const ValueKey('learning-save-file')));
      expect(f.downloads.length, 1);
      await show(t, f, saver: saver, account: 'b');
      f.downloads.single.complete(
        LearningDownload('说明.txt', Uint8List.fromList([1])),
      );
      await t.pumpAndSettle();
      expect(saves, 0);
    },
  );
  testWidgets(
    'save cancellation, failure and opening remain explicit user actions',
    (t) async {
      final f = ContextFake();
      var opens = 0, saves = 0;
      Future<LearningSavedFile?> saver(
        LearningDownload file,
        bool Function() current,
      ) async {
        expect(current(), isTrue);
        saves++;
        return LearningSavedFile(
          open: () async {
            opens++;
          },
        );
      }

      await show(t, f, saver: saver);
      expect(f.downloads, isEmpty);
      await tap(t, find.byKey(const ValueKey('learning-save-file')));
      f.downloads.single.complete(
        LearningDownload('说明.txt', Uint8List.fromList([1])),
      );
      await t.pumpAndSettle();
      expect(saves, 1);
      expect(opens, 0);
      await tap(t, find.text('打开已保存文件'));
      expect(opens, 1);
    },
  );
  testWidgets('interface health is an explicit passive disclosure', (t) async {
    final f = ContextFake();
    await show(t, f);
    final before = f.requestedPaths.length;
    await t.tap(find.byIcon(CupertinoIcons.info_circle));
    await t.pumpAndSettle();
    expect(find.text('学习接口状态'), findsOneWidget);
    expect(find.textContaining('不主动批量探测'), findsOneWidget);
    expect(f.requestedPaths.length, before);
  });
  testWidgets('directory late result cannot replace newer root request', (
    t,
  ) async {
    final f = ContextFake();
    await show(t, f);
    f.deferredResources = true;
    await tap(
      t,
      find.byKey(const ValueKey('learning-resource-folder')),
      settle: false,
    );
    expect(f.resourceReads, hasLength(1));
    await tap(t, find.byKey(const Key('learning-root')), settle: false);
    expect(f.resourceReads, hasLength(2));
    f.resourceReads.last.complete(
      LearningRead(CourseResourcePage([], 1, false)),
    );
    await t.pumpAndSettle();
    f.resourceReads.first.complete(
      LearningRead(CourseResourcePage([file], 1, false)),
    );
    await t.pumpAndSettle();
    expect(find.text('暂无资料'), findsOneWidget);
    expect(find.text('说明.txt'), findsNothing);
  });
}
