import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/learning.dart';
import 'package:ginkgo_mirror/infrastructure/demo_mirror_service.dart';
import 'package:ginkgo_mirror/infrastructure/learning_payload.dart';
import 'package:ginkgo_mirror/infrastructure/native_mirror_service.dart';

void main() {
  ReadOnlyResponse response(
    Object? value, {
    bool stale = false,
    FailureCode? failure,
  }) => ReadOnlyResponse(
    payload: jsonEncode(value),
    stale: stale,
    failure: failure,
  );

  test('business course fields and unknown teacher remain unchanged', () {
    final result = decodeLearningRead(
      response([
        {
          'id': 'course-1',
          'name': '合成课程',
          'teacher': null,
          'term': null,
          'sourceUrl': 'https://example.test/course',
        },
      ]),
      decodeCourses,
    );
    expect(result.data.single.id, 'course-1');
    expect(result.data.single.teacher, isNull);
    expect(result.data.single.term, isNull);
    expect(result.stale, isFalse);
    expect(result.failure, isNull);
    expect(() => result.data.clear(), throwsUnsupportedError);
  });

  test('confirmed empty and stale successful empty are distinguishable', () {
    final fresh = decodeLearningRead(response([]), decodeCourses);
    final stale = decodeLearningRead(
      response([], stale: true, failure: FailureCode.serviceUnavailable),
      decodeCourses,
    );
    expect(fresh.data, isEmpty);
    expect(fresh.stale, isFalse);
    expect(stale.data, isEmpty);
    expect(stale.stale, isTrue);
    expect(stale.failure, FailureCode.serviceUnavailable);
  });

  test('missing payload, failed nonstale, null and malformed payload fail', () {
    expect(
      () => decodeLearningRead(
        const ReadOnlyResponse(stale: false),
        decodeCourses,
      ),
      throwsStateError,
    );
    expect(
      () => decodeLearningRead(
        response([], failure: FailureCode.serviceUnavailable),
        decodeCourses,
      ),
      throwsStateError,
    );
    expect(
      () => decodeLearningRead(response(null), decodeCourses),
      throwsFormatException,
    );
    expect(
      () => decodeLearningRead(
        const ReadOnlyResponse(payload: '{', stale: false),
        decodeCourses,
      ),
      throwsFormatException,
    );
    expect(() => decodeCourses({'list': []}), throwsA(isA<TypeError>()));
    expect(
      () => decodeCourses([
        {'id': 'course-1'},
      ]),
      throwsA(isA<TypeError>()),
    );
  });

  test(
    'announcement detail retains identity, optional content and attachments',
    () {
      final detail = decodeAnnouncement({
        'id': 'notice-1',
        'title': '合成公告',
        'content': null,
        'attachments': [
          {'id': 'file-1', 'name': '说明.txt'},
        ],
      });
      expect(detail.id, 'notice-1');
      expect(detail.content, isNull);
      expect(detail.attachments.single.name, '说明.txt');
      expect(() => detail.attachments.clear(), throwsUnsupportedError);
      expect(
        decodeAnnouncements([
          {'id': 'notice-1', 'title': '公告', 'publishedAt': null},
        ]).single.publishedAt,
        isNull,
      );
      expect(
        () => decodeAnnouncement({
          'id': 'notice-1',
          'title': '公告',
          'attachments': null,
        }),
        throwsA(isA<TypeError>()),
      );
    },
  );

  test('resource paging is explicit and folder is never downloadable', () {
    final page = decodeResources({
      'items': [
        {
          'id': 'folder-1',
          'name': '资料',
          'folder': true,
          'downloadable': false,
          'updatedAt': null,
          'extension': null,
        },
      ],
      'page': 2,
      'hasNext': true,
    });
    expect(page.page, 2);
    expect(page.hasNext, isTrue);
    expect(page.items.single.updatedAt, isNull);
    expect(() => page.items.clear(), throwsUnsupportedError);
    expect(
      () => decodeResources({'items': [], 'page': 0, 'hasNext': false}),
      throwsFormatException,
    );
    expect(
      () => decodeResources({
        'items': [
          {'id': 'bad', 'name': '目录', 'folder': true, 'downloadable': true},
        ],
        'page': 1,
        'hasNext': false,
      }),
      throwsFormatException,
    );
  });

  test('assessment unknown time and score are not fabricated', () {
    final item = decodeAssessments([
      {
        'id': 'assessment-1',
        'title': '合成测验',
        'startsAt': null,
        'dueAt': null,
        'score': null,
        'sourceUrl': '',
      },
    ]).single;
    expect(item.startsAt, isNull);
    expect(item.dueAt, isNull);
    expect(item.score, isNull);
    expect(() => decodeAssessments({'list': []}), throwsA(isA<TypeError>()));
  });

  test('download owns immutable bytes', () {
    final bytes = Uint8List.fromList([1, 2]);
    final result = LearningDownload('演示.txt', bytes);
    bytes[0] = 9;
    expect(result.bytes, [1, 2]);
    expect(() => result.bytes[0] = 9, throwsUnsupportedError);
  });

  test(
    'demo capability works without bridge and rejects mismatched identities',
    () async {
      const demo = DemoMirrorService();
      expect(demo, isA<LearningCourseGateway>());
      final course = (await demo.learningCourses()).data.single;
      final notice = (await demo.courseAnnouncements(course.id)).data.single;
      final detail = await demo.courseAnnouncementDetail(course.id, notice.id);
      expect(detail.id, notice.id);
      final root = (await demo.courseResources(course.id)).data;
      final folder = root.items.single.id;
      final files = (await demo.courseResources(
        course.id,
        folder: folder,
      )).data;
      final file = await demo.courseResourceDownload(
        course.id,
        files.items.single.id,
        folder: folder,
      );
      expect(file.bytes, isNotEmpty);
      expect(
        (await demo.courseResources(course.id, page: 2)).data.items,
        isEmpty,
      );
      expect(
        (await demo.courseAssessments(course.id)).data.single.score,
        isNull,
      );
      await expectLater(demo.courseResources('other-course'), throwsStateError);
      await expectLater(
        demo.courseResourceDownload(course.id, folder),
        throwsStateError,
      );
      await expectLater(
        demo.courseAnnouncementAttachment(course.id, notice.id, 'other-file'),
        throwsStateError,
      );
    },
  );

  test(
    'native learning refuses unbound account before touching native runtime',
    () async {
      const service = NativeMirrorService();
      await expectLater(service.learningCourses(), throwsStateError);
      await expectLater(
        service.courseAnnouncements('course'),
        throwsStateError,
      );
      await expectLater(
        service.courseAnnouncementDetail('course', 'notice'),
        throwsStateError,
      );
      await expectLater(service.courseResources('course'), throwsStateError);
      await expectLater(service.courseAssessments('course'), throwsStateError);
      await expectLater(
        service.courseResourceDownload('course', 'file'),
        throwsStateError,
      );
      await expectLater(
        service.courseAnnouncementAttachment('course', 'notice', 'file'),
        throwsStateError,
      );
    },
  );
}
