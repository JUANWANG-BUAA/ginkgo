import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/update_gate.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _FakeService implements MirrorService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 120 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsOneWidget);
}

void main() {
  test('reads minBuild and the optional hint', () {
    final gate = UpdateGate.parse(
      '{"schema":1,"minBuild":7,"message":" 学校接口已更新 ","releasesUrl":"https://github.com/JUANWANG-BUAA/ginkgo/releases"}',
    );
    expect(gate, isNotNull);
    expect(gate!.minBuild, 7);
    expect(gate.message, '学校接口已更新');
    expect(gate.releasesUrl, 'https://github.com/JUANWANG-BUAA/ginkgo/releases');
    expect(gate.blocks(6), isTrue);
    expect(gate.blocks(7), isFalse);
    expect(gate.blocks(8), isFalse);
  });

  test('rejects malformed manifests without blocking startup', () {
    expect(UpdateGate.parse('not json'), isNull);
    expect(UpdateGate.parse('[]'), isNull);
    expect(UpdateGate.parse('{"minBuild":"7"}'), isNull);
    expect(UpdateGate.parse('{"minBuild":-1}'), isNull);
    expect(UpdateGate.parse('{"schema":1}'), isNull);
  });

  test('only official release surfaces may override the release link', () {
    for (final releasesUrl in [
      'javascript:alert(1)',
      'http://github.com/JUANWANG-BUAA/ginkgo/releases',
      'https://github.com.evil.example/r',
      'https://user@github.com/JUANWANG-BUAA/ginkgo/releases',
      'https://github.com:8443/JUANWANG-BUAA/ginkgo/releases',
    ]) {
      final gate = UpdateGate.parse(
        '{"minBuild":5,"releasesUrl":"$releasesUrl"}',
      );
      expect(gate!.releasesUri.toString(), UpdateGate.defaultReleasesUrl);
    }
    final official = UpdateGate.parse(
      '{"minBuild":5,"releasesUrl":"https://juanwang-buaa.github.io/ginkgo/releases/"}',
    );
    expect(
      official!.releasesUri.toString(),
      'https://juanwang-buaa.github.io/ginkgo/releases/',
    );
  });

  testWidgets('blocked page explains the reason, version and retry', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: UpdateRequiredPage(
          gate: const UpdateGate(minBuild: 9, message: '学校接口已更新，请安装新版本。'),
          installedVersion: '0.1.0-alpha.4 (5)',
          onRetry: () async => retries++,
        ),
      ),
    );
    expect(find.text('需要更新'), findsOneWidget);
    expect(find.text('学校接口已更新，请安装新版本。'), findsOneWidget);
    expect(find.text('当前版本 0.1.0-alpha.4 (5)'), findsOneWidget);
    await tester.tap(find.text('重新检查'));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('root blocks the workspace when the installed build is below', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'Ginkgo',
      packageName: 'cn.edu.buaa.ginkgo.ginkgo_mirror',
      version: '0.1.0-alpha.4',
      buildNumber: '5',
      buildSignature: '',
    );
    await tester.pumpWidget(
      GinkgoRoot(
        liveService: _FakeService(),
        loadUpdateGate: () async => const UpdateGate(minBuild: 6),
      ),
    );
    await _pumpUntil(tester, find.text('需要更新'));
    expect(find.text('当前版本 0.1.0-alpha.4 (5)'), findsOneWidget);
  });
}
