import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/library_books.dart';
import 'package:ginkgo_mirror/application/library_stats.dart';
import 'package:ginkgo_mirror/application/shuttle.dart';

void main() {
  group('library book hits', () {
    BookHit hit({
      String title = '',
      String author = '',
      String publisher = '',
      String year = '',
      int? itemsAvailable,
      int? itemCount,
    }) => BookHit(
      bibId: 'syn-1',
      title: title,
      author: author,
      publisher: publisher,
      year: year,
      callno: '',
      isbn: '',
      itemsAvailable: itemsAvailable,
      itemCount: itemCount,
    );

    test('an untitled hit says so instead of showing a blank row', () {
      final row = hit();
      expect(row.bibId, 'syn-1');
      expect(row.title, isEmpty);
      expect(row.displayTitle, '未命名书目');
    });

    test('absent counts stay null rather than pretending to be zero', () {
      final row = hit(title: '操作系统');
      expect(row.itemsAvailable, isNull);
      expect(row.itemCount, isNull);
    });

    test('present counts survive the crossing', () {
      final row = hit(title: '操作系统', itemsAvailable: 3, itemCount: 5);
      expect(row.itemsAvailable, 3);
      expect(row.itemCount, 5);
    });

    test('factLine never shows stray separators', () {
      final row = hit(publisher: '高等教育出版社', year: '2024');
      expect(row.factLine, '高等教育出版社 · 2024');
    });
  });

  group('library campus stats', () {
    test('a full value keeps counts and nested reading rooms', () {
      const stats = LibraryCampusStats(
        id: 'campus-1',
        name: '学院路校区',
        people: 812,
        readingRooms: [
          ReadingRoom(name: '一层阅览室', people: 120),
          ReadingRoom(name: '二层阅览室', people: 96),
        ],
        seats: CountPair(available: 40, total: 200),
      );
      expect(stats.id, 'campus-1');
      expect(stats.name, '学院路校区');
      expect(stats.people, 812);
      expect(stats.readingRooms.map((room) => room.name), ['一层阅览室', '二层阅览室']);
      expect(stats.readingRooms.map((room) => room.people), [120, 96]);
      expect(stats.seats?.available, 40);
      expect(stats.seats?.total, 200);
    });

    test('an absent seat pair is null so the UI can say "not published"', () {
      const stats = LibraryCampusStats(
        id: 'campus-1',
        name: '学院路校区',
        people: 812,
        readingRooms: [],
      );
      // Absent resources are null, never a fabricated zero.
      expect(stats.seats, isNull);
      expect(stats.studyRooms, isNull);
      expect(stats.lockers, isNull);
    });
  });

  group('shuttle applicability labels', () {
    ShuttleSection table(String label) =>
        ShuttleSection(label: label, left: const [], right: const []);

    test('an empty or everyday label always applies', () {
      for (final label in ['', '每天', '每日', '全年']) {
        for (
          var weekday = DateTime.monday;
          weekday <= DateTime.sunday;
          weekday++
        ) {
          expect(
            table(label).appliesToday(weekday),
            isTrue,
            reason: '"$label" must apply on weekday $weekday',
          );
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
      for (
        var weekday = DateTime.monday;
        weekday <= DateTime.friday;
        weekday++
      ) {
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

    test(
      'an unfamiliar label keeps its runs visible rather than hiding them',
      () {
        final odd = table('另行通知');
        for (
          var weekday = DateTime.monday;
          weekday <= DateTime.sunday;
          weekday++
        ) {
          expect(
            odd.appliesToday(weekday),
            isTrue,
            reason: 'an unreadable label must not claim a day does not apply',
          );
        }
      },
    );
  });

  group('shuttle runs and sections', () {
    test('a run keeps the printed departure time and capacity', () {
      const run = ShuttleRun(index: '1', time: '07:00', capacity: '45 座');
      expect(run.time, '07:00');
      expect(run.capacity, '45 座');
      expect(run.minuteOfDay, 7 * 60);
    });

    test('an unparseable printed time yields no minute-of-day', () {
      for (final printed in ['待定', '25:00', '07:70']) {
        expect(
          ShuttleRun(index: '1', time: printed, capacity: '').minuteOfDay,
          isNull,
          reason: '"$printed" is not a usable departure time',
        );
      }
    });
  });
}
