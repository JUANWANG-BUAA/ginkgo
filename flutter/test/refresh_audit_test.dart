import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/apple_widgets.dart';
import 'package:ginkgo_mirror/grades_page.dart';
import 'package:ginkgo_mirror/today_page.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

import 'mirror_widget_test.dart'
    show ControlledService, todayFixture, gradesFixture;

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
  testWidgets(
    'today failure keeps actual courses and repeated refresh is coalesced',
    (tester) async {
      final service = RefreshService();
      await tester.pumpWidget(ginkgoApp(home: TodayPage(service: service)));
      service.todayCalls.single.complete(todayFixture);
      await tester.pumpAndSettle();
      final refresh = tester.widget<CupertinoSliverRefreshControl>(
        find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
      );
      final first = refresh.onRefresh!();
      final repeated = refresh.onRefresh!();
      expect(service.todayCalls.length, 2);
      service.todayCalls.last.completeError(
        StateError('synthetic transport failure'),
      );
      // Both callers wait for the same in-flight section reads to finish.
      await Future.wait([first, repeated]);
      await tester.pumpAndSettle();
      expect(find.text('保留上次结果'), findsOneWidget);
      expect(find.text(todayFixture.courses.first.name), findsWidgets);
    },
  );

  testWidgets(
    'grades ignore out-of-order refresh and retain results on failure',
    (tester) async {
      final service = RefreshService();
      await tester.pumpWidget(ginkgoApp(home: GradesPage(service: service)));
      await tester.pump();
      service.gradeCalls.single.complete(gradesFixture);
      await tester.pumpAndSettle();
      final refresh = tester.widget<CupertinoSliverRefreshControl>(
        find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
      );
      final older = refresh.onRefresh!();
      final newer = refresh.onRefresh!();
      service.gradeCalls.last.complete(gradesFixture);
      await newer;
      service.gradeCalls[1].completeError(StateError('obsolete failure'));
      await older;
      await tester.pumpAndSettle();
      expect(find.textContaining('本地服务暂时不可用'), findsNothing);
      final failed = refresh.onRefresh!();
      service.gradeCalls.last.completeError(StateError('synthetic failure'));
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
