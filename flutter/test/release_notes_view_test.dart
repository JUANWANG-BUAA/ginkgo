import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/widgets/release_notes_view.dart';

/// The real Beta.2 body shape: heading, bullets, a notice paragraph and a
/// footer mixing relative docs links with one openable GitHub link.
const beta2Body = '''
# Ginkgo Android 0.1.0-beta.2

- 公开信息查询与账号登录态隔离，常用服务可在目录中本地搜索。
- 新增按需校园卡余额查询，**金额默认遮挡**，离开页面或切换账号后清除。

提醒：Beta 版本仍在完善。

[功能与接口协议总览](../FEATURES-AND-PROTOCOLS.md) · [脱敏反馈](https://github.com/JUANWANG-BUAA/ginkgo/issues/new?template=android-beta.md)
''';

Widget host(String source) => CupertinoApp(
  home: CupertinoPageScaffold(
    child: SingleChildScrollView(child: ReleaseNotesView(source: source)),
  ),
);

void main() {
  group('the house-style subset parses into blocks', () {
    test('headings, bullets and paragraphs keep their own kind and order', () {
      final blocks = parseReleaseNotes(beta2Body);
      expect(blocks, [
        isA<NotesHeading>(),
        isA<NotesBullet>(),
        isA<NotesBullet>(),
        isA<NotesParagraph>(),
        isA<NotesParagraph>(),
      ]);
      expect((blocks[0] as NotesHeading).level, 1);
    });

    test('markdown markers never survive into the rendered text', () {
      final blocks = parseReleaseNotes(beta2Body);
      final rendered = blocks
          .map(
            (block) => switch (block) {
              NotesHeading(:final spans) => spans,
              NotesBullet(:final spans) => spans,
              NotesParagraph(:final spans) => spans,
            },
          )
          .expand((spans) => spans)
          .map(
            (span) => switch (span) {
              NotesText(:final text) => text,
              NotesLink(:final text) => text,
            },
          )
          .join();
      expect(rendered, isNot(contains('- 公开信息')));
      expect(rendered, isNot(contains('**')));
      expect(rendered, isNot(contains('](../')));
      expect(rendered, contains('金额默认遮挡'));
    });

    test('bold is a span flag, not literal asterisks', () {
      final bullet = parseReleaseNotes(beta2Body)[2] as NotesBullet;
      final bold = bullet.spans.whereType<NotesText>().where((s) => s.bold);
      expect(bold.single.text, '金额默认遮挡');
    });

    test('consecutive plain lines join into one paragraph', () {
      final blocks = parseReleaseNotes('第一行\n第二行\n\n第三行');
      expect(blocks, hasLength(2));
      expect((blocks[0] as NotesParagraph).spans, hasLength(2));
    });
  });

  group('remote copy cannot smuggle in a destination or a payload', () {
    test('only the project GitHub pages are openable', () {
      expect(
        openableReleaseLink(
          'https://github.com/JUANWANG-BUAA/ginkgo/releases/tag/android-v0.1.0-beta.2',
        ),
        isTrue,
      );
      // A different repository, a look-alike host, plain http, embedded
      // credentials and a relative docs link are all refused.
      expect(
        openableReleaseLink('https://github.com/someone-else/project'),
        isFalse,
      );
      expect(openableReleaseLink('https://github.com.evil.example/x'), isFalse);
      expect(
        openableReleaseLink('http://github.com/JUANWANG-BUAA/ginkgo'),
        isFalse,
      );
      expect(
        openableReleaseLink(
          'https://user:pass@github.com/JUANWANG-BUAA/ginkgo',
        ),
        isFalse,
      );
      expect(openableReleaseLink('../FEATURES-AND-PROTOCOLS.md'), isFalse);
      // School destinations are upstream policy, not widget policy: release
      // notes carry no school link, and one must not become tappable here.
      expect(
        openableReleaseLink('https://www.buaa.edu.cn/info/1065/1762.htm'),
        isFalse,
      );
      expect(openableReleaseLink('https://career.buaa.edu.cn/x'), isFalse);
    });

    test('a refused link keeps its label but loses the tap target', () {
      final blocks = parseReleaseNotes('[相对文档](../API.md)');
      final link = (blocks.single as NotesParagraph).spans.single as NotesLink;
      expect(link.text, '相对文档');
      expect(link.url, isNull);
    });

    test('an image is reduced to its alternative text and never fetched', () {
      final blocks = parseReleaseNotes(
        '![分享卡](https://evil.example/track.png)',
      );
      final spans = (blocks.single as NotesParagraph).spans;
      expect(spans, hasLength(1));
      expect((spans.single as NotesText).text, '分享卡');
    });

    test('an over-long body is bounded before it becomes a widget tree', () {
      final huge = List.filled(releaseNotesSourceLimit + 5000, '字').join();
      final blocks = parseReleaseNotes(huge);
      final characters = blocks
          .map(
            (block) => switch (block) {
              NotesHeading(:final spans) => spans,
              NotesBullet(:final spans) => spans,
              NotesParagraph(:final spans) => spans,
            },
          )
          .expand((spans) => spans)
          .map((span) => (span as NotesText).text.length)
          .fold(0, (total, length) => total + length);
      expect(characters, releaseNotesSourceLimit);
    });

    test('blank source renders nothing at all', () {
      expect(parseReleaseNotes('   \n\n  '), isEmpty);
    });
  });

  group('the rendered page', () {
    testWidgets('shows bullets as a list and the openable link as a link', (
      tester,
    ) async {
      await tester.pumpWidget(host(beta2Body));
      expect(find.text('Ginkgo Android 0.1.0-beta.2'), findsOneWidget);
      expect(find.text('公开信息查询与账号登录态隔离，常用服务可在目录中本地搜索。'), findsOneWidget);
      expect(find.text('•'), findsNWidgets(2));
      expect(find.text('提醒：Beta 版本仍在完善。'), findsOneWidget);

      // Exactly one tap target: the openable GitHub link. The relative docs
      // link keeps its label as plain text, so there is nothing to misfire on.
      expect(
        find.descendant(
          of: find.byType(ReleaseNotesView),
          matching: find.byType(GestureDetector),
        ),
        findsOneWidget,
      );
      expect(find.text('脱敏反馈'), findsOneWidget);
      expect(find.textContaining('功能与接口协议总览'), findsOneWidget);
      expect(find.textContaining('../FEATURES-AND-PROTOCOLS.md'), findsNothing);
    });

    testWidgets('an empty body takes no vertical space', (tester) async {
      await tester.pumpWidget(host('   '));
      expect(find.byType(ReleaseNotesView), findsOneWidget);
      expect(find.text('•'), findsNothing);
    });
  });
}
