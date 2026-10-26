import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/learning.dart';
import 'package:ginkgo_mirror/application/diagnostic_log.dart';
import 'package:ginkgo_mirror/ginkgo_app.dart';
import 'package:ginkgo_mirror/learning_page.dart';
import 'package:ginkgo_mirror/workspace_catalog.dart';

const course = LearningCourse(
  id: 'synthetic-course',
  name: '合成学习课程',
  teacher: '合成教师',
  sourceUrl: 'https://spoc.buaa.edu.cn/course/synthetic',
);

class ReadQueue<T> {
  final requests = <Completer<LearningRead<T>>>[];
  final forced = <bool>[];
  Future<LearningRead<T>> read(bool force) {
    forced.add(force);
    final request = Completer<LearningRead<T>>();
    requests.add(request);
    return request.future;
  }
}

class LearningFake
    implements
        LearningCourseGateway,
        CourseAnnouncementGateway,
        CourseResourceGateway,
        CourseAssessmentGateway {
  final courses = ReadQueue<List<LearningCourse>>();
  final announcements = ReadQueue<List<CourseAnnouncement>>();
  final resources = ReadQueue<CourseResourcePage>();
  final assessments = ReadQueue<List<CourseAssessment>>();
  final details = <String>[];
  final folders = <String?>[];
  final pages = <int>[];
  int downloads = 0;

  @override
  Future<LearningRead<List<LearningCourse>>> learningCourses({
    bool forceRefresh = false,
  }) => courses.read(forceRefresh);
  @override
  Future<LearningRead<List<CourseAnnouncement>>> courseAnnouncements(
    String course, {
    bool forceRefresh = false,
  }) => announcements.read(forceRefresh);
  @override
  Future<LearningRead<CourseResourcePage>> courseResources(
    String course, {
    String? folder,
    int page = 1,
    bool forceRefresh = false,
  }) {
    folders.add(folder);
    pages.add(page);
    return resources.read(forceRefresh);
  }

  @override
  Future<LearningRead<List<CourseAssessment>>> courseAssessments(
    String course, {
    bool forceRefresh = false,
  }) => assessments.read(forceRefresh);
  @override
  Future<CourseAnnouncementDetail> courseAnnouncementDetail(
    String course,
    String id,
  ) async {
    details.add('$course/$id');
    return CourseAnnouncementDetail(
      id: id,
      title: '合成公告',
      content: '<script>不会执行的公告正文</script>',
      attachments: [const LearningAttachment('file', '合成附件.pdf')],
    );
  }

  @override
  Future<LearningDownload> courseAnnouncementAttachment(
    String course,
    String id,
    String file,
  ) async {
    downloads++;
    throw StateError('本轮不应下载');
  }

  @override
  Future<LearningDownload> courseResourceDownload(
    String course,
    String id, {
    String? folder,
    int page = 1,
  }) async {
    downloads++;
    throw StateError('本轮不应下载');
  }
}

/// Only a single read trait, deliberately not a MirrorService or write gateway.
class CoursesOnly implements LearningCourseGateway {
  @override
  Future<LearningRead<List<LearningCourse>>> learningCourses({
    bool forceRefresh = false,
  }) async => const LearningRead([course]);
}

void screen(WidgetTester tester, [Size size = const Size(430, 1800)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> showCourse(
  WidgetTester tester,
  Object service, {
  String? accountId,
}) => tester.pumpWidget(
  ginkgoApp(
    home: LearningCoursePage(
      course: course,
      service: service,
      accountId: accountId,
    ),
  ),
);

void completeEmpty(LearningFake fake) {
  fake.announcements.requests.last.complete(const LearningRead([]));
  fake.resources.requests.last.complete(
    LearningRead(CourseResourcePage([], 1, false)),
  );
  fake.assessments.requests.last.complete(const LearningRead([]));
}

void main() {
  testWidgets('successful learning load and refresh do not emit diagnostics', (
    tester,
  ) async {
    DiagnosticLog.shared.entries.clear();
    DiagnosticLog.shared.current = null;
    addTearDown(() {
      DiagnosticLog.shared.entries.clear();
      DiagnosticLog.shared.current = null;
    });
    final service = LearningFake();
    await tester.pumpWidget(ginkgoApp(home: LearningPage(service: service)));
    expect(DiagnosticLog.shared.entries, isEmpty);
    service.courses.requests.single.complete(const LearningRead([course]));
    await tester.pumpAndSettle();
    expect(find.text('合成学习课程'), findsOneWidget);
    expect(DiagnosticLog.shared.entries, isEmpty);
    await tester.tap(find.byKey(const ValueKey('learning-refresh-课程')));
    await tester.pump();
    service.courses.requests.last.complete(const LearningRead([course]));
    await tester.pumpAndSettle();
    expect(DiagnosticLog.shared.entries, isEmpty);
  });

  test('learning is a low-frequency academics entry, not a new mobile tab', () {
    final entry = destinationById('learning')!;
    expect(entry.section, WorkspaceSection.academics);
    expect(entry.mobileTab, isNull);
    expect(sidebarDestinations(WorkspaceSection.academics), contains(entry));
    expect(
      mobileDestinations.map((item) => item.id),
      isNot(contains('learning')),
    );
  });

  testWidgets(
    'courses navigate to read-only course and plain-text announcement details',
    (tester) async {
      screen(tester);
      final fake = LearningFake();
      await tester.pumpWidget(ginkgoApp(home: LearningPage(service: fake)));
      fake.courses.requests.single.complete(const LearningRead([course]));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('learning-course-synthetic-course')),
      );
      await tester.pump();
      expect(fake.announcements.requests, hasLength(1));
      expect(fake.resources.requests, hasLength(1));
      expect(fake.assessments.requests, hasLength(1));
      fake.announcements.requests.single.complete(
        const LearningRead([CourseAnnouncement('notice', '合成公告', null)]),
      );
      fake.resources.requests.single.complete(
        LearningRead(
          CourseResourcePage(
            [
              const CourseResource(
                id: 'folder',
                name: '合成目录',
                folder: true,
                downloadable: false,
              ),
              const CourseResource(
                id: 'file',
                name: '合成资料.pdf',
                folder: false,
                downloadable: true,
              ),
            ],
            1,
            true,
          ),
        ),
      );
      fake.assessments.requests.single.complete(
        const LearningRead([
          CourseAssessment(id: 'quiz', title: '合成测验', sourceUrl: ''),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('前往课程官网'), findsOneWidget);
      expect(find.textContaining('成绩：未知'), findsOneWidget);
      expect(find.textContaining('成绩：0'), findsNothing);
      expect(find.byKey(const Key('learning-next-page')), findsOneWidget);
      // Directory navigation is now available, but never started automatically.
      expect(fake.folders, [null]);
      expect(fake.pages, [1]);
      await tester.tap(find.text('合成公告'));
      await tester.pumpAndSettle();
      expect(fake.details, ['synthetic-course/notice']);
      expect(find.text('<script>不会执行的公告正文</script>'), findsOneWidget);
      expect(find.text('合成附件.pdf'), findsOneWidget);
      expect(fake.downloads, 0);
      for (final forbidden in ['开始测验', '提交测验', '作答', '标为已读', '下载附件']) {
        expect(find.text(forbidden), findsNothing);
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('课程详情'), findsOneWidget);
      expect(fake.announcements.requests, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sections publish independently; stale failure and retry stay local',
    (tester) async {
      screen(tester);
      final fake = LearningFake();
      await showCourse(tester, fake);
      fake.announcements.requests.single.complete(
        const LearningRead(
          [CourseAnnouncement('notice', '缓存公告', null)],
          stale: true,
          failure: FailureCode.serviceUnavailable,
        ),
      );
      await tester.pump();
      expect(find.text('缓存公告'), findsOneWidget);
      expect(find.text('旧缓存 · 可能不是最新结果'), findsOneWidget);
      expect(find.text('保留上次结果'), findsOneWidget);
      expect(fake.resources.requests.single.isCompleted, isFalse);
      fake.resources.requests.single.complete(
        LearningRead(CourseResourcePage([], 1, false)),
      );
      fake.assessments.requests.single.complete(const LearningRead([]));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('learning-refresh-公告')));
      await tester.pump();
      expect(fake.announcements.forced, [false, true]);
      expect(fake.resources.forced, [false]);
      expect(fake.assessments.forced, [false]);
      expect(find.text('缓存公告'), findsOneWidget);
      fake.announcements.requests.last.completeError(
        StateError('synthetic failure'),
      );
      await tester.pumpAndSettle();
      expect(find.text('缓存公告'), findsOneWidget);
      expect(find.text('保留上次结果'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('learning-refresh-公告')));
      await tester.pump();
      fake.announcements.requests.last.complete(const LearningRead([]));
      await tester.pumpAndSettle();
      expect(find.text('暂无公告'), findsOneWidget);
      expect(find.text('缓存公告'), findsNothing);
      expect(find.text('旧缓存 · 可能不是最新结果'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resource and assessment failures retry separately, without zero placeholders',
    (tester) async {
      screen(tester);
      final fake = LearningFake();
      await showCourse(tester, fake);
      fake.announcements.requests.single.complete(const LearningRead([]));
      fake.resources.requests.single.completeError(
        StateError('synthetic resource failure'),
      );
      fake.assessments.requests.single.completeError(
        StateError('synthetic assessment failure'),
      );
      await tester.pumpAndSettle();
      expect(find.text('根目录暂无资料'), findsNothing);
      expect(find.text('暂无测验'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('learning-refresh-资料')));
      await tester.pump();
      fake.resources.requests.last.complete(
        LearningRead(CourseResourcePage([], 1, false)),
      );
      await tester.pumpAndSettle();
      expect(fake.resources.forced, [false, true]);
      expect(fake.assessments.forced, [false]);
      await tester.tap(find.byKey(const ValueKey('learning-refresh-测验')));
      await tester.pump();
      fake.assessments.requests.last.complete(const LearningRead([]));
      await tester.pumpAndSettle();
      expect(fake.announcements.forced, [false]);
      expect(fake.assessments.forced, [false, true]);
      expect(find.text('暂无测验'), findsOneWidget);
    },
  );

  testWidgets('provider or account changes discard delayed section responses', (
    tester,
  ) async {
    screen(tester);
    final old = LearningFake(), current = LearningFake();
    await showCourse(tester, old, accountId: 'old');
    await showCourse(tester, current, accountId: 'new');
    completeEmpty(current);
    await tester.pumpAndSettle();
    old.announcements.requests.single.complete(
      const LearningRead([CourseAnnouncement('old', '旧账号公告', null)]),
    );
    old.resources.requests.single.completeError(StateError('old failure'));
    old.assessments.requests.single.complete(
      const LearningRead([
        CourseAssessment(id: 'old', title: '旧测验', sourceUrl: ''),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('旧账号公告'), findsNothing);
    expect(find.text('旧测验'), findsNothing);
    expect(find.text('暂无公告'), findsOneWidget);
    // The same service instance can also be rebound to a different account.
    await showCourse(tester, current, accountId: 'another');
    expect(current.announcements.requests, hasLength(2));
    completeEmpty(current);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('course-list account replacement rejects late values', (
    tester,
  ) async {
    screen(tester);
    final fake = LearningFake();
    await tester.pumpWidget(
      ginkgoApp(
        home: LearningPage(service: fake, accountId: 'old'),
      ),
    );
    await tester.pumpWidget(
      ginkgoApp(
        home: LearningPage(service: fake, accountId: 'new'),
      ),
    );
    fake.courses.requests.last.complete(const LearningRead([]));
    fake.courses.requests.first.complete(const LearningRead([course]));
    await tester.pumpAndSettle();
    expect(find.text('暂无课程'), findsOneWidget);
    expect(find.text(course.name), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'capability detection leaves old fakes usable and partial gateways independent',
    (tester) async {
      screen(tester);
      await tester.pumpWidget(ginkgoApp(home: LearningPage(service: Object())));
      await tester.pumpAndSettle();
      expect(find.text('当前服务暂不支持课程'), findsOneWidget);
      await tester.pumpWidget(
        ginkgoApp(home: LearningPage(service: CoursesOnly())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(course.name));
      await tester.pumpAndSettle();
      for (final section in ['公告', '资料', '测验']) {
        expect(find.text('当前服务暂不支持$section'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'large-text data rows wrap and refresh targets remain at least 48dp',
    (tester) async {
      screen(tester, const Size(320, 900));
      final fake = LearningFake();
      await tester.pumpWidget(
        ginkgoApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 900),
              textScaler: TextScaler.linear(2),
            ),
            child: LearningCoursePage(course: course, service: fake),
          ),
        ),
      );
      fake.announcements.requests.single.complete(
        const LearningRead([
          CourseAnnouncement('long', '很长的合成公告标题用于验证大字号不发生横向溢出', null),
        ]),
      );
      fake.resources.requests.single.complete(
        LearningRead(
          CourseResourcePage(
            [
              const CourseResource(
                id: 'long',
                name: '很长的合成资料名称用于验证多行布局.pdf',
                folder: false,
                downloadable: true,
              ),
            ],
            1,
            false,
          ),
        ),
      );
      fake.assessments.requests.single.complete(
        const LearningRead([
          CourseAssessment(
            id: 'long',
            title: '很长的合成测验标题用于验证多行布局',
            sourceUrl: '',
          ),
        ]),
      );
      await tester.pumpAndSettle();
      for (final section in ['公告', '资料', '测验']) {
        final target = find.byKey(ValueKey('learning-refresh-$section'));
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      }
      expect(fake.downloads, 0);
    },
  );

  testWidgets(
    'narrow large text and invalid source URLs expose no unsupported actions',
    (tester) async {
      screen(tester, const Size(320, 900));
      for (final source in [
        '',
        'http://spoc.buaa.edu.cn',
        'https://',
        'javascript:alert(1)',
        'https://user:secret@spoc.buaa.edu.cn',
      ]) {
        await tester.pumpWidget(
          ginkgoApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 900),
                textScaler: TextScaler.linear(2),
              ),
              child: LearningCoursePage(
                course: LearningCourse(
                  id: source,
                  name: '很长的合成课程标题用于验证大字号自然换行',
                  sourceUrl: source,
                ),
                service: Object(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('在浏览器打开课程官网'), findsNothing);
        await tester.drag(find.byType(ListView), const Offset(0, -1000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
