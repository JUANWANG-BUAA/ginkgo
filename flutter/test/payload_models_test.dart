import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/library/library_books_models.dart';
import 'package:ginkgo_mirror/features/library/library_stats_models.dart';
import 'package:ginkgo_mirror/features/notices/notices_models.dart';
import 'package:ginkgo_mirror/features/shuttle/shuttle_models.dart';

void main() {
  group('notices payload', () {
    test('a normal payload maps every field', () {
      final notices = noticeList(
        jsonEncode([
          {
            'title': '关于选课的通知',
            'summary': '请于本周完成',
            'published_at': '2026-10-25',
            'url': 'synthetic:notice-1',
          },
        ]),
      );
      expect(notices, hasLength(1));
      expect(notices.single.title, '关于选课的通知');
      expect(notices.single.summary, '请于本周完成');
      expect(notices.single.publishedAt, '2026-10-25');
      expect(notices.single.url, 'synthetic:notice-1');
    });

    test('an empty list is a valid successful read', () {
      expect(noticeList('[]'), isEmpty);
    });

    // Contract today: this projection hard-casts. A drifted payload throws a
    // TypeError, which the page turns into a generic failure rather than a
    // silent placeholder record. This test pins that behaviour so a future
    // switch to typed-failure decoding is a deliberate, visible change.
    test('a drifted payload fails loudly instead of inventing a notice', () {
      expect(
        () => noticeList(jsonEncode([
          {'title': '只剩标题'},
        ])),
        throwsA(isA<TypeError>()),
      );
    });

    test('a non-list payload fails instead of yielding an empty success', () {
      expect(
        () => noticeList(jsonEncode({'title': '不是数组'})),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('library book hits', () {
    test('missing text fields become empty instead of null literals', () {
      final hit = BookHit.fromJson({'bibId': 'syn-1'});
      expect(hit.bibId, 'syn-1');
      expect(hit.title, isEmpty);
      expect(hit.author, isEmpty);
      expect(hit.publisher, isEmpty);
      expect(hit.callno, isEmpty);
      expect(hit.displayTitle, '未命名书目');
    });

    test('absent counts stay null rather than pretending to be zero', () {
      final hit = BookHit.fromJson({'bibId': 'syn-1', 'title': '操作系统'});
      expect(hit.itemsAvailable, isNull);
      expect(hit.itemCount, isNull);
    });

    test('present counts survive decoding', () {
      final hit = BookHit.fromJson({
        'bibId': 'syn-1',
        'title': '操作系统',
        'itemsAvailable': 3,
        'itemCount': 5,
      });
      expect(hit.itemsAvailable, 3);
      expect(hit.itemCount, 5);
    });

    test('blank text is trimmed away so factLine never shows stray separators',
        () {
      final hit = BookHit.fromJson({
        'bibId': 'syn-1',
        'author': '  ',
        'publisher': '高等教育出版社',
        'year': '2024',
      });
      expect(hit.factLine, '高等教育出版社 · 2024');
    });
  });

  group('library campus stats', () {
    Map<String, dynamic> campus({Object? readingRooms, Object? seats}) => {
      'id': 'campus-1',
      'name': '学院路校区',
      'people': 812,
      'readingRooms': ?readingRooms,
      'seats': ?seats,
    };

    test('a full payload keeps counts and nested reading rooms', () {
      final stats = LibraryCampusStats.fromJson(
        campus(
          readingRooms: [
            {'name': '一层阅览室', 'people': 120},
            {'name': '二层阅览室', 'people': 96},
          ],
          seats: {'available': 40, 'total': 200},
        ),
      );
      expect(stats.id, 'campus-1');
      expect(stats.name, '学院路校区');
      expect(stats.people, 812);
      expect(stats.readingRooms.map((room) => room.name),
          ['一层阅览室', '二层阅览室']);
      expect(stats.readingRooms.map((room) => room.people), [120, 96]);
      expect(stats.seats?.available, 40);
      expect(stats.seats?.total, 200);
    });

    test('an absent reading-room list is empty, not an error', () {
      final stats = LibraryCampusStats.fromJson(campus());
      expect(stats.readingRooms, isEmpty);
    });

    test('an absent seat pair is null so the UI can say "not published"', () {
      final stats = LibraryCampusStats.fromJson(campus());
      expect(stats.seats, isNull);
      expect(stats.studyRooms, isNull);
      expect(stats.lockers, isNull);
    });
  });

  group('shuttle applicability labels', () {
    ShuttleSection table(String label) =>
        ShuttleSection.fromJson({'label': label, 'left': [], 'right': []});

    test('an empty or everyday label always applies', () {
      for (final label in ['', '每天', '每日', '全年']) {
        for (var weekday = DateTime.monday;
            weekday <= DateTime.sunday;
            weekday++) {
          expect(table(label).appliesToday(weekday), isTrue,
              reason: '"$label" must apply on weekday $weekday');
        }
      }
    });

    test('weekend-only labels exclude weekdays', () {
      final weekend = table('双休日');
      expect(weekend.appliesToday(DateTime.monday), isFalse);
      expect(weekend.appliesToday(DateTime.saturday), isTrue);
      expect(weekend.appliesToday(DateTime.sunday), isTrue);
    });

    test('workday labels exclude the weekend', () {
      final workday = table('工作日');
      expect(workday.appliesToday(DateTime.friday), isTrue);
      expect(workday.appliesToday(DateTime.saturday), isFalse);
      expect(workday.appliesToday(DateTime.sunday), isFalse);
    });

    test('an explicit range covers both endpoints', () {
      final range = table('星期一至星期五');
      for (var weekday = DateTime.monday;
          weekday <= DateTime.friday;
          weekday++) {
        expect(range.appliesToday(weekday), isTrue);
      }
      expect(range.appliesToday(DateTime.saturday), isFalse);
      expect(range.appliesToday(DateTime.sunday), isFalse);
    });

    test('a wrapping range stays inclusive across the weekend', () {
      final range = table('星期五至星期一');
      expect(range.appliesToday(DateTime.friday), isTrue);
      expect(range.appliesToday(DateTime.saturday), isTrue);
      expect(range.appliesToday(DateTime.sunday), isTrue);
      expect(range.appliesToday(DateTime.monday), isTrue);
      expect(range.appliesToday(DateTime.wednesday), isFalse);
    });

    test('an unfamiliar label keeps its runs visible rather than hiding them',
        () {
      final odd = table('另行通知');
      for (var weekday = DateTime.monday;
          weekday <= DateTime.sunday;
          weekday++) {
        expect(odd.appliesToday(weekday), isTrue,
            reason: 'an unreadable label must not claim a day does not apply');
      }
    });
  });

  group('shuttle runs and sections', () {
    test('a run keeps the printed departure time and capacity', () {
      final run = ShuttleRun.fromJson({'time': '07:00', 'capacity': '45 座'});
      expect(run.time, '07:00');
      expect(run.capacity, '45 座');
      expect(run.minuteOfDay, 7 * 60);
    });

    test('an unparseable printed time yields no minute-of-day', () {
      expect(ShuttleRun.fromJson({'time': '待定'}).minuteOfDay, isNull);
      expect(ShuttleRun.fromJson({'time': '25:00'}).minuteOfDay, isNull);
      expect(ShuttleRun.fromJson({'time': '07:70'}).minuteOfDay, isNull);
    });

    test('an absent direction list decodes as empty', () {
      final section = ShuttleSection.fromJson({'label': '工作日'});
      expect(section.left, isEmpty);
      expect(section.right, isEmpty);
    });
  });
}
