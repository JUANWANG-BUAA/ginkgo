import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/campus_activities.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/features/campus/campus_activities_page.dart';

class SyntheticService extends Fake
    implements MirrorService, CampusActivitiesGateway {
  final requests = <({int page, bool forceRefresh})>[];
  final completers = <Completer<CampusActivitiesRead>>[];

  @override
  bool get isDemo => true;

  @override
  Future<CampusActivitiesRead> campusActivities({
    int page = 1,
    bool forceRefresh = false,
  }) {
    requests.add((page: page, forceRefresh: forceRefresh));
    final completer = Completer<CampusActivitiesRead>();
    completers.add(completer);
    return completer.future;
  }
}

const data = CampusActivities(
  page: 1,
  fetchedAt: '2026-10-28T10:00:00+08:00',
  activities: [
    CampusActivity(
      id: 'xswh:0',
      title: '合成学术活动',
      category: '讲座',
      publishedAt: '2026年10月23日',
      activityTime: '10月28日',
      place: '沙河校区合成报告厅',
      url: 'https://www.buaa.edu.cn/info/1076/8603.htm',
    ),
  ],
);

Widget host(Fake service) =>
    CupertinoApp(home: CampusActivitiesPage(service: service));

void main() {
  testWidgets('campus activities render source, event time and publish date', (
    tester,
  ) async {
    final fake = SyntheticService();
    await tester.pumpWidget(host(fake));
    expect(fake.requests.single, (page: 1, forceRefresh: false));
    fake.completers.single.complete(const CampusActivitiesRead(data: data));
    await tester.pumpAndSettle();

    expect(find.text('合成学术活动'), findsOneWidget);
    expect(find.textContaining('讲座 · 10月28日'), findsOneWidget);
    expect(find.textContaining('沙河校区合成报告厅'), findsOneWidget);
    expect(find.textContaining('发布 2026年10月23日'), findsOneWidget);
    expect(find.textContaining('来源：学校官网 · 同步 10月28日 10:00'), findsOneWidget);
  });

  testWidgets('failed refresh keeps old activities and original success time', (
    tester,
  ) async {
    final fake = SyntheticService();
    await tester.pumpWidget(host(fake));
    fake.completers.single.complete(const CampusActivitiesRead(data: data));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('刷新学术文化'));
    await tester.pump();
    fake.completers.last.complete(
      const CampusActivitiesRead(
        data: data,
        failure: FailureCode.serviceUnavailable,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('学校服务暂时不可用，请稍后重试'), findsOneWidget);
    expect(find.text('正在显示上次结果。'), findsOneWidget);
    expect(find.text('合成学术活动'), findsOneWidget);
    expect(find.textContaining('同步 10月28日 10:00'), findsOneWidget);
  });

  testWidgets('gateway replacement discards late activities from the old service', (
    tester,
  ) async {
    final first = SyntheticService();
    final second = SyntheticService();
    await tester.pumpWidget(host(first));
    await tester.pumpWidget(host(second));

    expect(second.requests, hasLength(1));
    first.completers.single.complete(const CampusActivitiesRead(data: data));
    await tester.pump();
    expect(find.text('合成学术活动'), findsNothing);

    second.completers.single.complete(
      const CampusActivitiesRead(
        data: CampusActivities(page: 1, activities: [], fetchedAt: ''),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 条公开安排'), findsOneWidget);
  });
}
