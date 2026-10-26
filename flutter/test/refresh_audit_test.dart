import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/features/grades/grades_page.dart';
import 'package:ginkgo_mirror/features/today/today_page.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

import 'mirror_widget_test.dart'
    show
        ControlledService,
        todayFixture,
        gradesFixture,
        mockLocalTaskSupportDirectory;

class RefreshService extends ControlledService {
  final todayCalls = <Completer<TodayResponse>>[];
  final gradeCalls = <Completer<GradeResponse>>[];
  @override
  Future<TodayResponse> today({bool forceRefresh = false}) {
    final pending = Completer<TodayResponse>();
    todayCalls.add(pending);
    return pending.future;
  }

  @override
  Future<GradeResponse> grades({String? termCode, bool forceRefresh = false}) {
    final pending = Completer<GradeResponse>();
    gradeCalls.add(pending);
    return pending.future;
  }
}

void main() {
  setUp(mockLocalTaskSupportDirectory);
  testWidgets(
    'today failure keeps actual courses and repeated refresh is coalesced',
    (tester) async {
      final service = RefreshService();
      await tester.pumpWidget(ginkgoApp(home: TodayPage(service: service)));
      service.todayCalls.single.complete(todayFixture);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('today-toggle-courses')));
      await tester.pumpAndSettle();
      final refresh = tester.widget<CupertinoSliverRefreshControl>(
        find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
      );
      final first = refresh.onRefresh!();
      final repeated = refresh.onRefresh!();
      // The repeated forced refresh is queued behind the in-flight read rather
      // than merged into it, so it issues no extra request yet.
      expect(service.todayCalls.length, 2);
      service.todayCalls.last.completeError(
        StateError('synthetic transport failure'),
      );
      await tester.pump();
      // Once the first read settles, the queued refresh runs on its own.
      expect(service.todayCalls.length, 3);
      service.todayCalls.last.completeError(
        StateError('synthetic transport failure'),
      );
      await Future.wait([first, repeated]);
      await tester.pumpAndSettle();
      expect(find.text('保留上次结果'), findsOneWidget);
      expect(find.text(todayFixture.courses.first.name), findsWidgets);
    },
  );

  testWidgets(
    'a forced grades refresh replaces the snapshot and failure retains it',
    (tester) async {
      final service = RefreshService();
      await tester.pumpWidget(ginkgoApp(home: GradesPage(service: service)));
      await tester.pump();
      service.gradeCalls.single.complete(gradesFixture);
      await tester.pumpAndSettle();
      final refresh = tester.widget<CupertinoSliverRefreshControl>(
        find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
      );
      // Grades may read terms before grades, so settle every pending read
      // rather than assuming one request per refresh.
      var handled = service.gradeCalls.length;
      Future<void> settlePending({StateError? failure}) async {
        for (var round = 0; round < 3; round++) {
          await tester.pump();
          while (handled < service.gradeCalls.length) {
            final pending = service.gradeCalls[handled++];
            failure == null
                ? pending.complete(gradesFixture)
                : pending.completeError(failure);
          }
        }
      }

      final refreshed = refresh.onRefresh!();
      await settlePending();
      await refreshed;
      await tester.pumpAndSettle();
      expect(find.textContaining('本地服务暂时不可用'), findsNothing);
      expect(find.text(gradesFixture.courses.first.name), findsWidgets);

      final failed = refresh.onRefresh!();
      await settlePending(failure: StateError('synthetic failure'));
      await failed;
      await tester.pumpAndSettle();
      expect(find.textContaining('正在保留'), findsOneWidget);
      expect(find.text(gradesFixture.courses.first.name), findsWidgets);
    },
  );

  testWidgets('grouped rows wrap long content at large type', (tester) async {
    const longTitle = '这是用于验证长课程标题可以完整换行显示而不被省略的合成课程名称';
    await tester.pumpWidget(
      ginkgoApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.8),
              disableAnimations: true,
            ),
            child: const CupertinoPageScaffold(
              child: Center(
                child: SizedBox(
                  width: 320,
                  child: AppleSection(
                    children: [
                      AppleListTile(
                        title: Text(longTitle),
                        subtitle: Text('第一行说明\n第二行说明'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.text(longTitle),
        matching: find.byType(RichText),
      ),
    );
    expect(paragraph.maxLines, isNull);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.size.height, greaterThan(60));
    expect(tester.takeException(), isNull);
  });
}
