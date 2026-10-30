import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_models.dart';
import 'package:ginkgo_mirror/infrastructure/cgyy_decode.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' as live;

import 'bykc_fixture.dart';
import 'graduate_fixture.dart';
import 'library_books_fixture.dart';
import 'library_stats_fixture.dart';

/// Every payload family that crosses the bridge now arrives as a typed DTO.
/// These regressions pin each decoder to the DTO shape the bridge emits, so a
/// projection change cannot silently turn into an empty list, a missing field
/// or a fabricated zero.
void main() {
  group('CGYY typed decode', () {
    test('venues decode with their capacity fields', () {
      final sites = decodeCgyyLoad(
        const live.CgyyLoadResponse(
          venues: [
            live.CgyySiteDto(
              id: 3,
              name: '合成研讨室',
              venue: '合成楼',
              campus: '学院路',
              seats: 8,
              openStart: '',
              openEnd: '',
            ),
          ],
        ),
      ).sites!;
      expect(sites.single.id, 3);
      expect(sites.single.name, '合成研讨室');
      expect(sites.single.venue, '合成楼');
      expect(sites.single.campus, '学院路');
      expect(sites.single.seats, 8);
    });

    test('a day keeps its spaces and slot statuses', () {
      final day = decodeCgyyLoad(
        const live.CgyyLoadResponse(
          day: live.CgyyDayDto(
            siteId: 1,
            date: '2026-10-20',
            dates: ['2026-10-20'],
            spaces: [
              live.CgyySpaceDto(
                name: '合成研讨室',
                slots: [live.CgyySlotDto(time: '08:00–09:00', status: '空闲')],
              ),
            ],
          ),
        ),
      ).day!;
      expect(day.date, '2026-10-20');
      expect(day.spaces.single.slots.single.status, '空闲');
    });

    test('orders keep their school status fields', () {
      final orders = decodeCgyyLoad(
        const live.CgyyLoadResponse(
          orders: [
            live.CgyyOrderDto(
              id: 42,
              place: '合成楼 · A101',
              date: '2030-12-31',
              time: '14:00',
              status: '订单状态 1',
              orderStatus: 1,
              checkStatus: 2,
              canCancel: true,
            ),
          ],
        ),
      ).orders!;
      expect(orders.single.id, 42);
      expect(orders.single.place, '合成楼 · A101');
      expect(orders.single.orderStatus, 1);
      expect(orders.single.checkStatus, 2);
      expect(orders.single.canCancel, isTrue);
    });

    test('a single order decodes the same way as the list', () {
      final order = decodeCgyyLoad(
        const live.CgyyLoadResponse(
          order: live.CgyyOrderDto(
            id: 42,
            place: '合成楼 · A101',
            date: '2030-12-31',
            time: '14:00',
            status: '订单状态 1',
            orderStatus: 1,
            checkStatus: 2,
            canCancel: true,
          ),
        ),
      ).order!;
      expect(order.id, 42);
      expect(order.canCancel, isTrue);
    });

    test(
      'the lock code keeps its own fields and stays unknown when absent',
      () {
        final code = decodeCgyyLoad(
          const live.CgyyLoadResponse(
            lockCode: live.CgyyLockCodeDto(
              qrCode: '246810',
              dueDate: '2026-10-27 10:00:00',
              tradeNo: 'synthetic-trade',
              venueName: '合成楼',
              spaceName: 'A101',
              reservationDate: '2026-10-27',
            ),
          ),
        ).lockCode!;
        expect(code.hasPassword, isTrue);
        expect(code.hasUpcomingReservation, isTrue);
        expect(code.location, '合成楼 · A101');

        final empty = decodeCgyyLoad(
          const live.CgyyLoadResponse(
            lockCode: live.CgyyLockCodeDto(qrCode: 'null'),
          ),
        ).lockCode!;
        expect(empty.hasPassword, isFalse);
        expect(empty.hasUpcomingReservation, isFalse);
      },
    );

    test('the write state distinguishes ready, uncertain and unknown', () {
      expect(CgyyWriteStatus.fromState('ready').known, isTrue);
      expect(CgyyWriteStatus.fromState('uncertain').reviewRequired, isTrue);
      expect(CgyyWriteStatus.fromState('reviewRequired').known, isFalse);
    });

    test('a write action result keeps its state and message', () {
      final result = decodeCgyyAction(
        const live.CgyyActionResultResponse(
          data: live.CgyyActionResultDto(
            state: 'uncertain',
            message: '取消结果待核实',
          ),
        ),
      );
      expect(result.state, 'uncertain');
      expect(result.message, '取消结果待核实');
    });
  });

  group('BYKC payloads', () {
    test('the catalog keeps its current term and courses', () {
      final catalog = bykcCatalogFrom({
        'currentTerm': {'id': '1', 'name': '2026 秋'},
        'terms': [
          {'id': '1', 'name': '2026 秋'},
        ],
        'courses': [
          {'id': 1, 'name': '合成博雅课程', 'category': '美育'},
        ],
      });
      expect(catalog.currentTerm?.name, '2026 秋');
      expect(catalog.courses.single.name, '合成博雅课程');
      expect(catalog.courses.single.categoryLabel, '美育');
    });

    test('chosen courses keep missing results as unknown, not failed', () {
      final chosen = bykcChosenFrom({
        'term': {'id': '1', 'name': '2026 秋'},
        'courses': [
          {
            'id': 7,
            'course': {'id': 1, 'name': '合成已选课程'},
            'selectedAt': '2026-09-01',
          },
        ],
      });
      final record = chosen.courses!.single;
      expect(record.id, 7);
      expect(record.course.name, '合成已选课程');
      expect(record.checkin, isNull);
      expect(record.attendanceLabel, '签到待确认');
      expect(record.passed, isNull);
      expect(record.resultLabel, '通过待确认');
    });

    test('statistics keep requirement gaps typed', () {
      final statistics = bykcStatisticsFrom({
        'validCourseCount': 3,
        'entries': [
          {
            'category': '博雅课程',
            'subcategory': '艺术欣赏',
            'required': 2,
            'completed': 1,
          },
        ],
      });
      expect(statistics.validCourseCount, 3);
      expect(statistics.entries.single.requiredCount, 2);
      expect(statistics.entries.single.complete, isFalse);
    });
  });

  group('graduate payloads', () {
    test('the report keeps its sections and notice', () {
      final report = graduateRead({
        'sections': [
          {
            'title': '通识教育',
            'rows': [
              {'title': '高等数学', 'detail': '3 学分', 'isCourse': true},
            ],
          },
        ],
        'notice': '以学校执行报告为准',
      }).data;
      expect(report, isNotNull);
      expect(report!.sections.single.title, '通识教育');
      expect(report.notice, '以学校执行报告为准');
      expect(report.sections.fold<int>(0, (sum, s) => sum + s.rows.length), 1);
    });

    test('an absent report stays unknown instead of an empty one', () {
      expect(graduateRead(null).data, isNull);
    });
  });

  group('library payloads', () {
    test('a book page keeps its items and paging flags', () {
      final page = bookPageRead({
        'page': 1,
        'pageSize': 20,
        'total': 1,
        'items': [
          {
            'bibId': 'syn-1',
            'title': '合成书目',
            'author': '合成作者',
            'publisher': '合成出版社',
            'year': '2026',
            'callno': 'I247.5',
            'isbn': 'synthetic-isbn',
            'itemsAvailable': 1,
            'itemCount': 2,
          },
        ],
        'hasMore': false,
      }).data!;
      expect(page.page, 1);
      expect(page.items.single.title, '合成书目');
      expect(page.items.single.itemsAvailable, 1);
      expect(page.hasMore, isFalse);
    });

    test('campus stats keep counts and reading rooms', () {
      final stats = statsRead({
        'campuses': [
          {
            'id': 'a1',
            'name': '学院路馆',
            'people': 12,
            'readingRooms': [
              {'name': '自习室 1', 'people': 3},
            ],
            'seats': {'available': 4, 'total': 20},
            'studyRooms': null,
            'lockers': {'available': 0, 'total': 10},
          },
        ],
        'fetchedAt': '2026-10-20T15:30:00+08:00',
        'fromCache': false,
      });
      final campus = stats.data!.campuses.single;
      expect(campus.name, '学院路馆');
      expect(campus.seats!.available, 4);
      expect(campus.studyRooms, isNull);
      expect(stats.data!.fromCache, isFalse);
    });
  });
}
