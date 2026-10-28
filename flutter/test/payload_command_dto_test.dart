import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/bykc/bykc_models.dart';
import 'package:ginkgo_mirror/features/checkin/checkin_models.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_models.dart';
import 'package:ginkgo_mirror/features/graduate/graduate_models.dart';
import 'package:ginkgo_mirror/features/library/library_books_models.dart';
import 'package:ginkgo_mirror/features/library/library_stats_models.dart';
import 'package:ginkgo_mirror/features/notices/notices_models.dart';
import 'package:ginkgo_mirror/features/shuttle/shuttle_models.dart';

/// Every payload family that crosses the bridge as a `ReadOnlyResponse` has a
/// decoder on the Dart side. These regressions pin each decoder to the payload
/// shape the bridge emits, so a projection change cannot silently turn into an
/// empty list, a missing field or a fabricated zero.
void main() {
  group('notices payload', () {
    test('a full row keeps every field the school sent', () {
      final notices = noticeList(
        jsonEncode([
          {
            'title': '关于选课的通知',
            'summary': '请于本周完成',
            'published_at': '2026-10-25',
            'url': 'https://news.buaa.edu.cn/1',
          },
        ]),
      );
      expect(notices.single.title, '关于选课的通知');
      expect(notices.single.summary, '请于本周完成');
      expect(notices.single.publishedAt, '2026-10-25');
      expect(notices.single.url, 'https://news.buaa.edu.cn/1');
    });

    test('an empty list is a success, a drifted row is not', () {
      expect(noticeList('[]'), isEmpty);
      expect(
        () => noticeList(jsonEncode([{'title': '只剩标题'}])),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('CGYY payloads', () {
    test('venues decode with their capacity fields', () {
      final sites = cgyySites(
        jsonEncode([
          {
            'id': 3,
            'name': '合成研讨室',
            'venue': '合成楼',
            'campus': '学院路',
            'seats': 8,
          },
        ]),
      );
      expect(sites.single.id, 3);
      expect(sites.single.name, '合成研讨室');
      expect(sites.single.venue, '合成楼');
      expect(sites.single.campus, '学院路');
      expect(sites.single.seats, 8);
    });

    test('a day keeps its spaces and slot statuses', () {
      final day = cgyyDay(
        jsonEncode({
          'date': '2026-10-20',
          'dates': ['2026-10-20'],
          'spaces': [
            {
              'name': '合成研讨室',
              'slots': [
                {'time': '08:00–09:00', 'status': '空闲'},
              ],
            },
          ],
        }),
      );
      expect(day.date, '2026-10-20');
      expect(day.spaces.single.slots.single.status, '空闲');
    });

    test('orders keep their school status fields', () {
      final orders = cgyyOrders(
        jsonEncode([
          {
            'id': 42,
            'place': '合成楼 · A101',
            'date': '2030-12-31',
            'time': '14:00',
            'status': '订单状态 1',
            'order_status': 1,
            'check_status': 2,
            'can_cancel': true,
          },
        ]),
      );
      expect(orders.single.id, 42);
      expect(orders.single.place, '合成楼 · A101');
      expect(orders.single.orderStatus, 1);
      expect(orders.single.checkStatus, 2);
      expect(orders.single.canCancel, isTrue);
    });

    test('a single order decodes the same way as the list', () {
      final order = cgyyOrder(
        jsonEncode({
          'id': 42,
          'place': '合成楼 · A101',
          'date': '2030-12-31',
          'time': '14:00',
          'status': '订单状态 1',
          'order_status': 1,
          'check_status': 2,
          'can_cancel': true,
        }),
      );
      expect(order.id, 42);
      expect(order.canCancel, isTrue);
    });

    test('the lock code keeps its own fields and stays unknown when absent', () {
      final code = cgyyLockCodeData(
        jsonEncode({
          'qrCode': '246810',
          'dueDate': '2026-10-27 10:00:00',
          'tradeNo': 'synthetic-trade',
          'venueName': '合成楼',
          'spaceName': 'A101',
          'reservationDate': '2026-10-27',
        }),
      );
      expect(code.hasPassword, isTrue);
      expect(code.hasUpcomingReservation, isTrue);
      expect(code.location, '合成楼 · A101');

      final empty = cgyyLockCodeData(jsonEncode({'qrCode': 'null'}));
      expect(empty.hasPassword, isFalse);
      expect(empty.hasUpcomingReservation, isFalse);
    });

    test('the write state distinguishes ready, uncertain and unknown', () {
      expect(cgyyWriteStatus(jsonEncode({'state': 'ready'})).known, isTrue);
      expect(
        cgyyWriteStatus(jsonEncode({'state': 'uncertain'})).reviewRequired,
        isTrue,
      );
      expect(cgyyWriteStatus(jsonEncode({'state': 'reviewRequired'})).known, isFalse);
    });

    test('a write action result keeps its state and message', () {
      final result = cgyyActionResult(
        jsonEncode({'state': 'uncertain', 'message': '取消结果待核实'}),
      );
      expect(result.state, 'uncertain');
      expect(result.message, '取消结果待核实');
    });
  });

  group('BYKC payloads', () {
    test('the catalog keeps its current term and courses', () {
      final catalog = bykcCatalog(
        jsonEncode({
          'currentTerm': {
            'year': 2026,
            'semester': 1,
            'startDate': '2026-09-01',
            'endDate': '2027-01-15',
          },
          'courses': [
            {
              'id': 1,
              'name': '合成课程',
              'credits': 2,
              'capacity': 30,
              'enrolled': 12,
            },
          ],
        }),
      );
      expect(catalog.currentTerm, isNotNull);
      expect(catalog.courses.single.name, '合成课程');
    });

    test('chosen courses keep undisclosed values as null, not zero', () {
      final chosen = bykcChosenCourses(
        jsonEncode({
          'term': {
            'year': 2026,
            'semester': 1,
            'startDate': '2026-09-01',
            'endDate': '2027-01-15',
          },
          'courses': [
            {
              'id': 7,
              'course': {
                'id': 1,
                'name': '合成课程',
                'credits': 2,
                'capacity': 30,
                'enrolled': 12,
              },
              'selectedAt': '2026-09-01T08:00:00+08:00',
              'checkin': null,
              'passed': null,
              'score': null,
            },
          ],
        }),
      );
      expect(chosen.courses, isNotNull);
      expect(chosen.courses!.single.checkin, isNull);
      expect(chosen.courses!.single.attendanceLabel, '签到待确认');
      expect(chosen.courses!.single.resultLabel, '通过待确认');
    });

    test('statistics keep required and completed counts', () {
      final statistics = bykcStatistics(
        jsonEncode({
          'validCourseCount': 3,
          'entries': [
            {
              'category': '通识',
              'subcategory': '数学',
              'required': 2,
              'completed': 1,
            },
          ],
        }),
      );
      expect(statistics.validCourseCount, 3);
      expect(statistics.entries.single.requiredCount, 2);
      expect(statistics.entries.single.complete, isFalse);
    });
  });

  group('graduate payloads', () {
    test('the report keeps its sections and notice', () {
      final report = graduateReport(
        jsonEncode({
          'sections': [
            {
              'title': '通识教育',
              'rows': [
                {'title': '高等数学', 'detail': '3 学分', 'isCourse': true},
              ],
            },
          ],
          'notice': '以学校执行报告为准',
        }),
      );
      expect(report, isNotNull);
      expect(report!.sections.single.title, '通识教育');
      expect(report.notice, '以学校执行报告为准');
      expect(graduatePayloadRowCount(jsonEncode({
        'sections': [
          {
            'title': '通识教育',
            'rows': [
              {'title': '高等数学', 'detail': '3 学分', 'isCourse': true},
            ],
          },
        ],
      })), 1);
    });

    test('a missing payload stays unknown instead of an empty report', () {
      expect(graduateReport(null), isNull);
      expect(graduatePayloadRowCount(null), 0);
    });
  });

  group('library payloads', () {
    test('a book page keeps its items and paging flags', () {
      final page = bookPage(
        jsonEncode({
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
        }),
      );
      expect(page.page, 1);
      expect(page.items.single.title, '合成书目');
      expect(page.items.single.itemsAvailable, 1);
      expect(page.hasMore, isFalse);
    });

    test('holdings keep the school wording of each copy', () {
      final holdings = bookHoldings(
        jsonEncode([
          {
            'callNo': 'I247.5/1',
            'barCode': 'synthetic-barcode',
            'library': '学院路馆',
            'location': '三层',
            'status': '在架',
          },
        ]),
      );
      expect(holdings.single.callNo, 'I247.5/1');
      expect(holdings.single.status, '在架');
    });

    test('campus stats keep counts and reading rooms', () {
      final stats = libraryStats(
        jsonEncode({
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
        }),
      );
      expect(stats.campuses.single.name, '学院路馆');
      expect(stats.campuses.single.seats!.available, 4);
      expect(stats.campuses.single.studyRooms, isNull);
      expect(stats.fromCache, isFalse);
    });
  });

  group('shuttle payload', () {
    test('the timetable keeps both directions and their source', () {
      final timetable = shuttleTimetable(
        jsonEncode({
          'source': 'https://shuttle.buaa.edu.cn/synthetic',
          'liveSource': 'https://shuttle.buaa.edu.cn/live',
          'tables': [
            {
              'left': '去往沙河',
              'right': '去往学院路',
              'sections': [
                {
                  'label': '每天',
                  'left': [
                    {'time': '07:30', 'capacity': '充足'},
                  ],
                  'right': [
                    {'time': '18:00', 'capacity': '紧张'},
                  ],
                },
              ],
            },
          ],
        }),
      );
      expect(timetable.source, contains('synthetic'));
      expect(timetable.tables.single.left, '去往沙河');
      expect(timetable.tables.single.sections.single.left.single.time, '07:30');
      expect(
        timetable.tables.single.sections.single.right.single.capacity,
        '紧张',
      );
    });
  });

  group('check-in progress payload', () {
    test('the telemetry keeps its phase and elapsed seconds', () {
      final telemetry = checkinProgress(
        jsonEncode({'phase': 'courses', 'elapsedMs': 2500}),
      );
      expect(telemetry, isNotNull);
      expect(telemetry!.phase, 'courses');
      expect(telemetry.elapsedSeconds, 2);
    });

    test('an unreadable progress payload stays unknown', () {
      expect(checkinProgress('not json'), isNull);
    });
  });
}
