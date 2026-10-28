import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/infrastructure/native_campus_activities.dart';
import 'package:ginkgo_mirror/infrastructure/native_career.dart';
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
  final campus = jsonEncode({
    'page': 1,
    'activities': [],
    'fetchedAt': '2026-10-28T10:00:00+08:00',
  });
  test('campus old success retains its failure and original time', () {
    final result = decodeCampusActivities(
      ReadOnlyResponse(
        payload: campus,
        stale: true,
        failure: FailureCode.serviceUnavailable,
      ),
    );
    expect(result.data?.fetchedAt, '2026-10-28T10:00:00+08:00');
    expect(result.data?.page, 1);
    expect(result.failure, FailureCode.serviceUnavailable);
  });
  test('campus missing fields and invalid page are protocol errors', () {
    for (final body in [
      '{}',
      '{"page":0,"activities":[],"fetchedAt":"x"}',
      '{"page":1,"activities":[{}],"fetchedAt":"x"}',
    ]) {
      final result = decodeCampusActivities(
        ReadOnlyResponse(payload: body, stale: false),
      );
      expect(result.data, isNull);
      expect(result.failure, FailureCode.changedResponse);
    }
  });
  test('campus non-stale failure never publishes its payload', () {
    final result = decodeCampusActivities(
      ReadOnlyResponse(
        payload: campus,
        stale: false,
        failure: FailureCode.sessionExpired,
      ),
    );
    expect(result.data, isNull);
    expect(result.failure, FailureCode.sessionExpired);
  });
}
