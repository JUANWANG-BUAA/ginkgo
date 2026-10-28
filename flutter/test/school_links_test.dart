import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/shared/school_links.dart';

void main() {
  test('school links reject missing and non-HTTPS URLs', () async {
    for (final url in ['', 'not a url', 'http://www.buaa.edu.cn']) {
      expect(await openSchoolLink(url), isFalse);
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
