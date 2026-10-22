import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/service_directory.dart';

import 'mirror_widget_test.dart' show ControlledService;

class InjectedNotices extends ControlledService {
  int reads = 0;

  @override
  Future<ReadOnlyResponse> notices({bool forceRefresh = false}) async {
    reads++;
    return ReadOnlyResponse(
      payload: jsonEncode([
        {
          'title': '来自注入服务的通知',
          'summary': '合成摘要',
          'published_at': '2026-10-22',
          'url': 'https://example.invalid/synthetic',
        },
      ]),
      stale: false,
    );
  }
}

void main() {
  testWidgets('feature navigation preserves the injected provider', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = InjectedNotices();
    await tester.pumpWidget(
      ginkgoApp(
        home: CupertinoPageScaffold(
          child: ServiceDirectory(service: service, onSignOut: () async {}),
        ),
      ),
    );
    await tester.tap(find.text('校园通知'));
    await tester.pumpAndSettle();
    expect(service.reads, 1);
    expect(find.text('来自注入服务的通知'), findsOneWidget);
  });
}
