import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/features/grades/grades_page.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'mirror_widget_test.dart' show ControlledService;

const terms = GradeTermsResponse(
  terms: [
    ScheduleTerm(id: 'term-a', name: '甲学期', selected: true),
    ScheduleTerm(id: 'term-b', name: '乙学期', selected: false),
  ],
);
GradeResponse result(String term, {FailureCode? failure}) => GradeResponse(
  termId: term,
  failure: failure,
  courses: const [],
  summary: const GradeSummary(courseCount: 0, creditTotal: 0),
);

class Reads extends ControlledService {
  final gradeRequests = <(String?, Completer<GradeResponse>)>[];
  @override
  Future<GradeTermsResponse> gradeTerms() async => terms;
  @override
  Future<GradeResponse> grades({String? termCode, bool forceRefresh = false}) {
    final request = Completer<GradeResponse>();
    gradeRequests.add((termCode, request));
    return request.future;
  }
}

Future<void> open(WidgetTester tester, Reads service) async {
  await tester.pumpWidget(CupertinoApp(home: GradesPage(service: service)));
  await tester.pump();
}

void main() {
  testWidgets(
    'term selection remains available after the first grade read fails',
    (tester) async {
      final service = Reads();
      await open(tester, service);
      service.gradeRequests.first.$2.complete(
        result('term-a', failure: FailureCode.networkUnreachable),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ApplePickerTile<String>), findsOneWidget);
      tester
          .widget<ApplePickerTile<String>>(find.byType(ApplePickerTile<String>))
          .onSelected('term-b');
      await tester.pump();
      expect(service.gradeRequests.last.$1, 'term-b');
      service.gradeRequests.last.$2.complete(result('term-b'));
      await tester.pumpAndSettle();
      expect(find.text('乙学期'), findsOneWidget);
    },
  );
  testWidgets(
    'switching terms labels the retained result while the new query waits',
    (tester) async {
      final service = Reads();
      await open(tester, service);
      service.gradeRequests.first.$2.complete(result('term-a'));
      await tester.pumpAndSettle();
      tester
          .widget<ApplePickerTile<String>>(find.byType(ApplePickerTile<String>))
          .onSelected('term-b');
      await tester.pump();
      expect(find.text('正在读取乙学期，当前显示甲学期的成绩。'), findsOneWidget);
      service.gradeRequests.last.$2.complete(result('term-b'));
      await tester.pumpAndSettle();
      expect(find.text('正在读取乙学期，当前显示甲学期的成绩。'), findsNothing);
    },
  );
}
