import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/infrastructure/native_campus_activities.dart';
import 'package:ginkgo_mirror/infrastructure/native_career.dart';
import 'package:ginkgo_mirror/infrastructure/library_holdings_decode.dart';
import 'package:ginkgo_mirror/infrastructure/notices_decode.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' as live;

void main() {
  const event = live.CareerEventDto(
    id: 'career-1',
    title: '合成宣讲',
    campus: '学院路',
    place: '合成楼',
    beginsAt: '10:00',
    endsAt: '11:00',
    fairType: '宣讲',
    status: '学校原文',
    url: 'https://career.buaa.edu.cn/synthetic',
  );
  const data = live.CareerEventsDto(
    month: '2026-10',
    events: [event],
    fetchedAt: '2026-10-28T10:00:00+08:00',
  );
  test('typed career DTO preserves fields and a stale failure', () {
    final result = decodeCareerEvents(
      const live.CareerEventsResponse(
        data: data,
        failure: FailureCode.serviceUnavailable,
      ),
    );
    expect(result.data?.month, '2026-10');
    expect(result.data?.fetchedAt, '2026-10-28T10:00:00+08:00');
    expect(result.data?.events.single.status, '学校原文');
    expect(result.data?.events.single.fairType, '宣讲');
    expect(result.failure, FailureCode.serviceUnavailable);
  });
  test('career empty success and failed reads remain distinct', () {
    final empty = decodeCareerEvents(
      const live.CareerEventsResponse(
        data: live.CareerEventsDto(
          month: '2026-10',
          events: [],
          fetchedAt: 'time',
        ),
      ),
    );
    expect(empty.data?.events, isEmpty);
    expect(empty.failure, isNull);
    final failure = decodeCareerEvents(
      const live.CareerEventsResponse(failure: FailureCode.sessionExpired),
    );
    expect(failure.data, isNull);
    expect(failure.failure, FailureCode.sessionExpired);
    expect(
      decodeCareerEvents(const live.CareerEventsResponse()).failure,
      FailureCode.changedResponse,
    );
  });
  const activity = live.CampusActivityDto(
    id: 'xswh:0',
    title: '合成讲座',
    category: '讲座',
    publishedAt: '2026年10月23日',
    activityTime: '10月28日',
    place: '合成报告厅',
    url: 'https://www.buaa.edu.cn/synthetic',
  );
  test('typed campus DTO keeps both dates and a stale failure', () {
    final result = decodeCampusActivities(
      const live.CampusActivitiesResponse(
        data: live.CampusActivitiesDto(
          page: 2,
          activities: [activity],
          fetchedAt: '2026-10-28T10:00:00+08:00',
        ),
        failure: FailureCode.serviceUnavailable,
      ),
    );
    expect(result.data?.page, 2);
    expect(result.data?.fetchedAt, '2026-10-28T10:00:00+08:00');
    // Publish date and event date stay separate fields; neither is a deadline.
    expect(result.data?.activities.single.publishedAt, '2026年10月23日');
    expect(result.data?.activities.single.activityTime, '10月28日');
    expect(result.failure, FailureCode.serviceUnavailable);
  });
  test('campus empty success and failed reads remain distinct', () {
    final empty = decodeCampusActivities(
      const live.CampusActivitiesResponse(
        data: live.CampusActivitiesDto(
          page: 1,
          activities: [],
          fetchedAt: 'time',
        ),
      ),
    );
    expect(empty.data?.activities, isEmpty);
    expect(empty.failure, isNull);
    final failure = decodeCampusActivities(
      const live.CampusActivitiesResponse(failure: FailureCode.sessionExpired),
    );
    expect(failure.data, isNull);
    expect(failure.failure, FailureCode.sessionExpired);
    expect(
      decodeCampusActivities(const live.CampusActivitiesResponse()).failure,
      FailureCode.changedResponse,
    );
  });

  test('typed notices keep every field, empty success and failure apart', () {
    final read = decodeNotices(
      const live.NoticesResponse(
        data: [
          live.NoticeDto(
            title: '关于选课的通知',
            summary: '请于本周完成',
            publishedAt: '2026-10-25',
            url: 'https://news.buaa.edu.cn/synthetic',
          ),
        ],
      ),
    );
    final notice = read.data!.single;
    expect(
      (notice.title, notice.summary, notice.publishedAt, notice.url),
      ('关于选课的通知', '请于本周完成', '2026-10-25', 'https://news.buaa.edu.cn/synthetic'),
    );
    expect(read.failure, isNull);

    // A confirmed empty list is data, not an error.
    final empty = decodeNotices(const live.NoticesResponse(data: []));
    expect(empty.data, isEmpty);
    expect(empty.failure, isNull);

    final failed = decodeNotices(
      const live.NoticesResponse(failure: FailureCode.networkUnreachable),
    );
    expect(failed.data, isNull);
    expect(failed.failure, FailureCode.networkUnreachable);
  });

  test('typed holdings keep the school wording of each copy', () {
    final read = decodeBookHoldings(
      const live.BookHoldingsResponse(
        data: [
          live.BookHoldingDto(
            callNo: 'I247.5/1',
            barCode: 'synthetic-barcode',
            library_: '学院路馆',
            location: '三层',
            status: '在架',
          ),
        ],
      ),
    );
    final holding = read.data!.single;
    expect(holding.callNo, 'I247.5/1');
    // The school's own status text is never turned into an available flag.
    expect(holding.status, '在架');
    expect(holding.place, '学院路馆 · 三层');
    expect(read.failure, isNull);

    final failed = decodeBookHoldings(
      const live.BookHoldingsResponse(failure: FailureCode.networkUnreachable),
    );
    expect(failed.data, isNull);
    expect(failed.failure, FailureCode.networkUnreachable);
  });
}
