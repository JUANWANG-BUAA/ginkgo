import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/bykc.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart' show BykcPart;
import 'package:ginkgo_mirror/features/bykc/bykc_page.dart';
import 'package:ginkgo_mirror/app/ginkgo_app.dart';

void main() {
  testWidgets('replacing owner discards pending and cached Bykc data', (
    tester,
  ) async {
    final old = Completer<BykcPartRead>();
    var newReads = 0;
    Future<BykcPartRead> oldLoader({
      required BykcPart part,
      required bool forceRefresh,
    }) => old.future;
    Future<BykcPartRead> newLoader({
      required BykcPart part,
      required bool forceRefresh,
    }) async {
      newReads++;
      return const BykcCatalogRead(
        data: BykcCatalog(courses: [BykcCourse(id: 2, name: '新账号课程')]),
      );
    }

    Widget app(BykcLoader loader) => ginkgoApp(
      home: BykcPage(key: const ValueKey('same-page'), loader: loader),
    );
    await tester.pumpWidget(app(oldLoader));
    await tester.pumpWidget(app(newLoader));
    await tester.pump(const Duration(milliseconds: 100));
    expect(newReads, 1);
    expect(find.text('新账号课程'), findsOneWidget);
    old.complete(
      const BykcCatalogRead(
        data: BykcCatalog(courses: [BykcCourse(id: 1, name: '旧账号课程')]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('旧账号课程'), findsNothing);
    expect(find.text('新账号课程'), findsOneWidget);
    await tester.pumpWidget(app(oldLoader));
    await tester.pumpAndSettle();
    expect(find.text('新账号课程'), findsNothing);
    expect(find.text('旧账号课程'), findsOneWidget);
  });
}
