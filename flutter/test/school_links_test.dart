import 'package:ginkgo_mirror/widgets/school_links.dart' as presentation;
import 'package:ginkgo_mirror/app/ginkgo_app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/shared/school_links.dart';
import 'package:ginkgo_mirror/widgets/school_links.dart' hide openSchoolLink;

void main() {
  test('school links reject missing and non-HTTPS URLs', () async {
    for (final url in ['', 'not a url', 'http://www.buaa.edu.cn']) {
      expect(await openSchoolLink(url, launcher: (_) async => true), isFalse);
    }
  });

  test('school links reject embedded credentials before launching', () async {
    var launches = 0;
    final opened = await openSchoolLink(
      'https://user:secret@www.buaa.edu.cn/path',
      launcher: (uri) async {
        launches++;
        return true;
      },
    );
    expect(opened, isFalse);
    expect(launches, 0);
  });

  test(
    'validated links preserve URI and normalize platform failures',
    () async {
      Uri? received;
      expect(
        await openSchoolLink(
          'https://www.buaa.edu.cn/path?q=1',
          launcher: (url) async {
            received = url;
            return true;
          },
        ),
        isTrue,
      );
      expect(received.toString(), 'https://www.buaa.edu.cn/path?q=1');
      expect(
        await openSchoolLink(
          'https://www.buaa.edu.cn',
          launcher: (_) async => false,
        ),
        isFalse,
      );
      expect(
        await openSchoolLink(
          'https://www.buaa.edu.cn',
          launcher: (_) async => throw StateError('platform unavailable'),
        ),
        isFalse,
      );
    },
  );

  testWidgets('root injects external links into pushed routes', (tester) async {
    final launched = <Uri>[];
    await tester.pumpWidget(
      ginkgoApp(
        externalLinkLauncher: (url) async {
          launched.add(url);
          return true;
        },
        home: Builder(
          builder: (context) => CupertinoButton(
            child: const Text('详情'),
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (context) => CupertinoButton(
                  child: const Text('官网'),
                  onPressed: () async {
                    await presentation.openSchoolLink(
                      context,
                      'https://www.buaa.edu.cn/path',
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('详情'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('官网'));
    await tester.pumpAndSettle();
    expect(launched, [Uri.parse('https://www.buaa.edu.cn/path')]);
  });

  testWidgets('missing capability returns failure without platform fallback', (
    tester,
  ) async {
    bool? opened;
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            child: const Text('官网'),
            onPressed: () async {
              opened = await presentation.openSchoolLink(
                context,
                'https://www.buaa.edu.cn',
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('官网'));
    await tester.pumpAndSettle();
    expect(opened, isFalse);
  });

  testWidgets('school link failures use one explanation', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () => showSchoolLinkError(context),
            child: const Text('打开'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('无法打开官网'), findsOneWidget);
    expect(find.text('请稍后重试。'), findsOneWidget);
  });
}
