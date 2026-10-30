import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/career.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/features/career/career_events_page.dart';

class SyntheticService extends Fake
    implements MirrorService, CareerEventsGateway {
  final requests = <({String month, bool forceRefresh})>[];
  final completers = <Completer<CareerEventsRead>>[];
  bool throwOnRead = false;

  @override
  bool get isDemo => true;

  @override
  Future<CareerEventsRead> careerEvents({
    required String month,
    bool forceRefresh = false,
  }) {
    requests.add((month: month, forceRefresh: forceRefresh));
    if (throwOnRead) throw StateError('synthetic');
    final c = Completer<CareerEventsRead>();
    completers.add(c);
    return c.future;
  }
}

const data = CareerEvents(
  month: '2026-10',
  fetchedAt: '2026-10-28T10:00:00+08:00',
  events: [
    CareerEvent(
      id: 'one',
      title: '合成宣讲',
      campus: '学院路校区',
      place: '主楼101',
      beginsAt: '2026-10-28 14:00:00',
      endsAt: '2026-10-28 15:30:00',
      fairType: '线下宣讲会',
      status: '1',
      url: 'https://career.buaa.edu.cn/show',
    ),
  ],
);

Widget host(CareerEventsGateway service) =>
    CupertinoApp(home: CareerEventsPage(service: service));

void main() {
  testWidgets('career events render school month, source and activity fields', (
    tester,
  ) async {
    final fake = SyntheticService();
    await tester.pumpWidget(host(fake));
    final request = fake.requests.single;
    expect(request.forceRefresh, isFalse);
    expect(request.month, matches(RegExp(r'^\d{4}-\d{2}$')));
    fake.completers.last.complete(const CareerEventsRead(data: data));
    await tester.pumpAndSettle();
    expect(find.text('合成宣讲'), findsOneWidget);
    expect(find.textContaining('学院路校区 · 主楼101'), findsOneWidget);
    expect(find.textContaining('线下宣讲会'), findsOneWidget);
    expect(find.textContaining('同步 10月28日 10:00'), findsOneWidget);
  });

  testWidgets('failed refresh keeps old events and explains staleness', (
    tester,
  ) async {
    final fake = SyntheticService();
    await tester.pumpWidget(host(fake));
    fake.completers.last.complete(const CareerEventsRead(data: data));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('刷新就业活动'));
    await tester.pump();
    fake.completers.last.complete(
      const CareerEventsRead(
        data: data,
        failure: FailureCode.serviceUnavailable,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('学校服务暂时不可用，请稍后重试'), findsOneWidget);
    expect(find.text('正在显示上次结果。'), findsOneWidget);
    expect(find.text('合成宣讲'), findsOneWidget);
  });

  testWidgets('successful empty is not an error', (tester) async {
    final fake = SyntheticService();
    await tester.pumpWidget(host(fake));
    fake.completers.last.complete(
      const CareerEventsRead(
        data: CareerEvents(
          month: '2026-10',
          events: [],
          fetchedAt: '2026-10-28T10:00:00+08:00',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('本月没有活动'), findsOneWidget);
    expect(find.text('学校服务暂时不可用，请稍后重试'), findsNothing);
  });

  testWidgets('an offline first read blames the connection, not the school', (
    tester,
  ) async {
    final fake = SyntheticService();
    await tester.pumpWidget(host(fake));
    fake.completers.last.complete(
      const CareerEventsRead(failure: FailureCode.networkUnreachable),
    );
    await tester.pumpAndSettle();
    expect(find.text('无法连接网络，请检查手机网络或校园网后重试'), findsOneWidget);
    expect(find.text('手机当前连不上网络，恢复网络后重试。'), findsOneWidget);
    // Nothing is cached, so the stale branch must stay hidden, and an offline
    // reader must not be pointed at a website it cannot reach either.
    expect(find.text('正在显示上次结果。'), findsNothing);
    expect(find.text('请稍后重试，或在服务目录中打开官网。'), findsNothing);
    expect(find.text('学校服务暂时不可用，请稍后重试'), findsNothing);
  });

  testWidgets('retrying an offline read keeps the queried month', (
    tester,
  ) async {
    final fake = SyntheticService();
    await tester.pumpWidget(host(fake));
    final month = fake.requests.single.month;
    fake.completers.last.complete(
      const CareerEventsRead(failure: FailureCode.networkUnreachable),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(fake.requests, hasLength(2));
    expect(fake.requests.last.month, month);
    expect(fake.requests.last.forceRefresh, isTrue);

    fake.completers.last.complete(const CareerEventsRead(data: data));
    await tester.pumpAndSettle();
    expect(find.text('合成宣讲'), findsOneWidget);
    expect(find.text('手机当前连不上网络，恢复网络后重试。'), findsNothing);
  });

  testWidgets('gateway replacement discards late events from the old service', (
    tester,
  ) async {
    final first = SyntheticService();
    final second = SyntheticService();
    await tester.pumpWidget(host(first));
    await tester.pumpWidget(host(second));

    expect(second.requests, hasLength(1));
    first.completers.single.complete(const CareerEventsRead(data: data));
    await tester.pump();
    expect(find.text('合成宣讲'), findsNothing);

    second.completers.single.complete(
      const CareerEventsRead(
        data: CareerEvents(month: '2026-10', events: [], fetchedAt: ''),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('本月没有活动'), findsOneWidget);
  });
}
