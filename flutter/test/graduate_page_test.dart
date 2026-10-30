import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/graduate_credit_map.dart';
import 'package:ginkgo_mirror/features/graduate/graduate_credit_map_widgets.dart';
import 'package:ginkgo_mirror/features/graduate/graduate_page.dart';
import 'package:ginkgo_mirror/infrastructure/demo_mirror_service.dart';
import 'package:ginkgo_mirror/main.dart';

class CreditMapReads implements GraduateCreditMapGateway {
  final reads = <Completer<GraduateCreditMapRead>>[];

  @override
  Future<GraduateCreditMapRead> graduateCreditMap({bool forceRefresh = false}) {
    final read = Completer<GraduateCreditMapRead>();
    reads.add(read);
    return read.future;
  }
}

GraduateCreditMapRead creditMap(String title) => GraduateCreditMapRead(
  data: GraduateCreditMap(
    nodes: [GraduateCreditNode(sourceIndex: 0, title: title)],
  ),
);

void main() {
  testWidgets('graduate academics embeds the strict credit map', (
    tester,
  ) async {
    await tester.pumpWidget(
      ginkgoApp(
        home: GraduatePage(
          service: const DemoMirrorService(),
          creditMapGateway: const DemoMirrorService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GraduateCreditMapNodeCard), findsWidgets);
  });

  testWidgets('credit map replacement discards the old gateway response', (
    tester,
  ) async {
    final first = CreditMapReads();
    final second = CreditMapReads();
    Widget page(CreditMapReads gateway) => ginkgoApp(
      home: GraduatePage(
        service: const DemoMirrorService(),
        creditMapGateway: gateway,
      ),
    );
    await tester.pumpWidget(page(first));
    await tester.pumpWidget(page(second));

    first.reads.single.complete(creditMap('旧服务学分地图'));
    await tester.pump();
    expect(find.text('旧服务学分地图'), findsNothing);
    expect(second.reads, hasLength(1));

    second.reads.single.complete(creditMap('新服务学分地图'));
    await tester.pumpAndSettle();
    expect(find.text('新服务学分地图'), findsOneWidget);
  });
}
